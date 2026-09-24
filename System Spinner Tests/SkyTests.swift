//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import AppKit
import Testing
@testable import System_Spinner

@Suite("Sun & Moon")
struct SkyTests {
    private static let moscow = SkyLocation.Coordinate(latitude: 55.7558, longitude: 37.6176)

    private static func utc(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    @Test("Midsummer noon in Moscow puts the sun near its highest")
    func summerNoon() {
        let elevation = Sun.elevation(at: Self.utc("2026-06-21T09:30:00Z"), latitude: 55.7558, longitude: 37.6176)

        // 90 − 55.76 + 23.44
        #expect(abs(elevation - 57.7) < 1)
    }

    @Test("A winter evening in Moscow is well past sunset")
    func winterNight() {
        let elevation = Sun.elevation(at: Self.utc("2026-12-21T18:00:00Z"), latitude: 55.7558, longitude: 37.6176)

        #expect(elevation < -18)
    }

    @Test("Known full and new moons land on their phases")
    func moonPhases() {
        let full = Moon.phase(at: Self.utc("2026-03-03T11:38:00Z"))
        let new = Moon.phase(at: Self.utc("2026-01-18T19:52:00Z"))

        #expect(abs(full - 0.5) < 0.03)
        #expect(min(new, 1 - new) < 0.03)
        #expect(Moon.illumination(phase: full) > 0.98)
        #expect(Moon.illumination(phase: new) < 0.02)
    }

    @Test("Zone table coordinates are read with and without seconds")
    func zoneTableCoordinates() {
        let table = SkyLocation.parseZoneTable("""
            # comment
            RU\t+554521+0373704\tEurope/Moscow\tMSK+00 - Moscow area
            AD\t+4230+00131\tEurope/Andorra
            US\t+340308-1181434\tAmerica/Los_Angeles\tPacific
            XX\tbroken\tNowhere/Bad
            """)

        let moscow = try! #require(table["Europe/Moscow"])
        #expect(abs(moscow.latitude - 55.7558) < 0.001)
        #expect(abs(moscow.longitude - 37.6178) < 0.001)

        let andorra = try! #require(table["Europe/Andorra"])
        #expect(abs(andorra.latitude - 42.5) < 0.001)
        #expect(abs(andorra.longitude - 1.5167) < 0.001)

        let losAngeles = try! #require(table["America/Los_Angeles"])
        #expect(losAngeles.longitude < -118)

        #expect(table["Nowhere/Bad"] == nil)
        #expect(table.count == 3)
    }

    @Test("A zone the table does not know still gets its longitude from the offset")
    func unknownZoneFallsBack() {
        let zone = TimeZone(secondsFromGMT: 3 * 3600)!
        let coordinate = SkyLocation.coordinate(for: zone)

        #expect(coordinate.longitude == 45)
    }

    @Test("The icon shows the sun by day and the moon by night")
    func iconState() {
        let noon = SkyIcon.now(at: Self.utc("2026-06-21T09:30:00Z"), location: Self.moscow)
        #expect(noon.sunUp)
        #expect(noon.dusk == 0)
        #expect(noon.weather == .clear)

        let night = SkyIcon.now(at: Self.utc("2026-03-03T21:00:00Z"), location: Self.moscow, weather: .cloudy)
        #expect(!night.sunUp)
        #expect(night.phase == SkyIcon.phaseSteps / 2)
        #expect(night.weather == .cloudy)
    }

    @Test("The sun reddens toward the horizon and is plain from ten degrees up")
    func dusk() {
        // Moscow, 21 June: sunrise about 00:45 UTC, 10 degrees up about two hours later.
        let sunrise = SkyIcon.now(at: Self.utc("2026-06-21T01:00:00Z"), location: Self.moscow)
        #expect(sunrise.sunUp)
        #expect(sunrise.dusk > SkyIcon.duskSteps / 2)

        let morning = SkyIcon.now(at: Self.utc("2026-06-21T04:00:00Z"), location: Self.moscow)
        #expect(morning.dusk == 0)

        let night = SkyIcon.now(at: Self.utc("2026-12-21T18:00:00Z"), location: Self.moscow)
        #expect(!night.sunUp)
        #expect(night.dusk == 0)
    }

    @Test("Sun & Moon is in the catalog as a drawn style")
    func catalogEntry() {
        let style = try! #require(SpinnerCatalog.style(named: "Sun & Moon"))
        #expect(style.isDrawn)
        #expect(style.frameCount == SkyIcon.sunFrameCount)
        #expect(SpinnerCatalog.style(named: "Sun") == nil)
    }

    @Test("Day and night move over the same loop of frames")
    @MainActor
    func frames() {
        for index in 0 ..< SkyIcon.sunFrameCount {
            #expect(NSImage(named: SkyIcon.sunFrameName(at: index)) != nil)
        }

        for weather in [SkyWeather.clear, .cloudy, .rainy] {
            let day = SkyIcon.State(sunUp: true, dusk: 0, phase: 0, weather: weather)
            let sun = SkyIcon.frames(day, height: 22, effect: .original)
            #expect(sun.count == SkyIcon.frameCount)
            #expect(sun.allSatisfy { !$0.isTemplate && $0.size == NSSize(width: 22, height: 22) })

            // The moon's face turns in colour; a glyph moves only under a cloud.
            let night = SkyIcon.State(sunUp: false, dusk: 0, phase: 4, weather: weather)
            #expect(SkyIcon.frames(night, height: 22, effect: .original).count == SkyIcon.frameCount)
            let glyph = SkyIcon.frames(night, height: 22, effect: .automatic)
            #expect(glyph.count == (weather == .clear ? 1 : SkyIcon.frameCount))
            #expect(glyph.allSatisfy { $0.isTemplate })
        }
    }

    @Test("Weather codes sort into clear, cloudy and rainy")
    func weatherCodes() {
        #expect(SkyWeather(weatherCode: 0) == .clear)
        #expect(SkyWeather(weatherCode: 1) == .clear)
        #expect(SkyWeather(weatherCode: 2) == .cloudy)
        #expect(SkyWeather(weatherCode: 3) == .cloudy)
        #expect(SkyWeather(weatherCode: 45) == .cloudy)
        #expect(SkyWeather(weatherCode: 61) == .rainy)
        #expect(SkyWeather(weatherCode: 95) == .rainy)

        #expect(SkyWeather(weatherCode: 1, cloudCover: 30) == .clear)
        #expect(SkyWeather(weatherCode: 1, cloudCover: 60) == .cloudy)
        #expect(SkyWeather(weatherCode: 61, cloudCover: 20) == .rainy)
    }

    @Test("An Open-Meteo answer is read, a broken one is not")
    func weatherResponse() {
        let answer = #"{"latitude":55.75,"current_units":{"weather_code":"wmo code"},"current":{"time":"2026-09-24T09:00","interval":900,"cloud_cover":75,"weather_code":1}}"#
        #expect(SkyWeatherService.parse(Data(answer.utf8)) == .cloudy)
        #expect(SkyWeatherService.parse(Data(#"{"error":true,"reason":"bad"}"#.utf8)) == nil)

        let url = SkyWeatherService.url(for: Self.moscow).absoluteString
        #expect(url == "https://api.open-meteo.com/v1/forecast?latitude=55.76&longitude=37.62&current=cloud_cover,weather_code")
    }

    @Test("A ProjectEOL answer is read, an error is not")
    func projectEolResponse() {
        // The answer for Moscow as it came, trimmed to what is read.
        let answer = #"{"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"…"}],"structuredContent":{"provider":"noaa-gfs","forecast":[{"time":"2026-09-24T12:00:00Z","values":{"surface.cloud_area_fraction":{"value":0.694,"unit":"1"},"surface.precipitation_flux":{"value":8.000000000039226e-07,"unit":"kg m-2 s-1"}}}]}}}"#
        #expect(SkyWeatherService.parseProjectEol(Data(answer.utf8)) == .cloudy)
        #expect(SkyWeatherService.parseProjectEol(Data(#"{"jsonrpc":"2.0","id":1,"result":{"isError":true,"content":[]}}"#.utf8)) == nil)
        #expect(SkyWeatherService.parseProjectEol(Data(#"{"jsonrpc":"2.0","id":1,"error":{"code":-32602,"message":"bad"}}"#.utf8)) == nil)

        #expect(SkyWeather(cloudCover: 30, rainPerHour: 0) == .clear)
        #expect(SkyWeather(cloudCover: 69, rainPerHour: 0.003) == .cloudy)
        #expect(SkyWeather(cloudCover: 20, rainPerHour: 0.2) == .rainy)
    }

    @Test("ProjectEOL is asked for the current hour")
    func projectEolRequest() throws {
        let request = SkyWeatherService.projectEolRequest(for: Self.moscow, at: Self.utc("2026-09-24T12:41:05Z"))
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })

        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 15)
        #expect(body.contains(#""name":"get_weather_forecast""#))
        #expect(body.contains(#""start":"2026-09-24T12:00:00Z""#))
        #expect(body.contains(#""latitude":55.76"#))
    }
}
