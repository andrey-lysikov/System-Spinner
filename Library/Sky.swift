//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import AppKit
import CoreLocation

enum Sun {
    private static let j2000 = Date(timeIntervalSince1970: 946_728_000) // 2000-01-01 12:00 UTC

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let n = date.timeIntervalSince(j2000) / 86_400

        let meanLongitude = 280.460 + 0.9856474 * n
        let meanAnomaly = radians(357.528 + 0.9856003 * n)

        let eclipticLongitude = radians(meanLongitude
                                        + 1.915 * sin(meanAnomaly)
                                        + 0.020 * sin(2 * meanAnomaly))
        let obliquity = radians(23.439 - 0.0000004 * n)

        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude)) * 180 / .pi

        var gmst = (18.697374558 + 24.06570982441908 * n).truncatingRemainder(dividingBy: 24)
        if gmst < 0 { gmst += 24 }

        let hourAngle = radians(gmst * 15 + longitude - rightAscension)
        let lat = radians(latitude)
        let sinAltitude = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)

        return asin(min(1, max(-1, sinAltitude))) * 180 / .pi
    }

    static func smoothStep(_ x: Double) -> Double {
        let x = min(1, max(0, x))
        return x * x * (3 - 2 * x)
    }
}

enum Moon {
    private static let knownNewMoon = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UTC
    private static let synodicMonth = 29.530588853
    
    static func phase(at date: Date) -> Double {
        var days = (date.timeIntervalSince(knownNewMoon) / 86_400).truncatingRemainder(dividingBy: synodicMonth)
        if days < 0 { days += synodicMonth }
        return days / synodicMonth
    }

    static func illumination(phase: Double) -> Double {
        (1 - cos(2 * .pi * phase)) / 2
    }
}

enum SkyLocation {
    struct Coordinate: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
    }

    private static let fallbackLatitude = 55.76
    private static let zoneTablePath = "/usr/share/zoneinfo/zone.tab"

    private static let zoneTable: [String: Coordinate] = {
        guard let text = try? String(contentsOfFile: zoneTablePath, encoding: .utf8) else { return [:] }
        return parseZoneTable(text)
    }()

    static var current: Coordinate {
        coordinate(for: .current)
    }

    static func coordinate(for zone: TimeZone, at date: Date = Date()) -> Coordinate {
        if let known = zoneTable[zone.identifier] { return known }

        let hours = Double(zone.secondsFromGMT(for: date)) / 3600
        return Coordinate(latitude: fallbackLatitude, longitude: min(180, max(-180, hours * 15)))
    }

    static func parseZoneTable(_ text: String) -> [String: Coordinate] {
        var table: [String: Coordinate] = [:]

        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t")
            guard fields.count >= 3, let coordinate = parseCoordinate(fields[1]) else { continue }
            table[String(fields[2])] = coordinate
        }
        return table
    }

    static func parseCoordinate(_ text: Substring) -> Coordinate? {
        guard let split = text.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }),
              let latitude = angle(text[..<split], degreeDigits: 2),
              let longitude = angle(text[split...], degreeDigits: 3)
        else { return nil }

        return Coordinate(latitude: latitude, longitude: longitude)
    }

    private static func angle(_ text: Substring, degreeDigits: Int) -> Double? {
        guard let sign = text.first, sign == "+" || sign == "-" else { return nil }

        let digits = text.dropFirst()
        guard digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber),
              digits.count == degreeDigits + 2 || digits.count == degreeDigits + 4
        else { return nil }

        let parts = [digits.prefix(degreeDigits),
                     digits.dropFirst(degreeDigits).prefix(2),
                     digits.dropFirst(degreeDigits + 2)]
        let values = parts.map { Double($0) ?? 0 }
        let value = values[0] + values[1] / 60 + values[2] / 3600

        return sign == "-" ? -value : value
    }
}

enum SkyWeather: Equatable, Sendable {
    case clear
    case cloudy
    case rainy
    
    init(weatherCode: Int) {
        switch weatherCode {
        case 2, 3, 45, 48: self = .cloudy
        case 51...: self = .rainy
        default: self = .clear
        }
    }

    init(weatherCode: Int, cloudCover: Double) {
        let weather = SkyWeather(weatherCode: weatherCode)
        self = weather == .clear && cloudCover >= 50 ? .cloudy : weather
    }

    init(cloudCover: Double, rainPerHour: Double) {
        self = rainPerHour >= 0.1 ? .rainy : cloudCover >= 50 ? .cloudy : .clear
    }
}

@MainActor
final class SkyLocator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: ((SkyLocation.Coordinate?) -> Void)?
    private(set) var coordinate: SkyLocation.Coordinate?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func locate(_ completion: @escaping (SkyLocation.Coordinate?) -> Void) {
        pending = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(nil)
        default:
            manager.requestLocation()
        }
    }

    func cancel() {
        pending = nil
        manager.stopUpdatingLocation()
    }

    private func finish(_ located: SkyLocation.Coordinate?) {
        if let located {
            coordinate = located
        }
        let completion = pending
        pending = nil
        completion?(coordinate)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard pending != nil else { return }
            switch status {
            case .notDetermined:
                return
            case .denied, .restricted:
                finish(nil)
            default:
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let located = SkyLocation.Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        MainActor.assumeIsolated { finish(located) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MainActor.assumeIsolated { finish(nil) }
    }
}

@MainActor
final class SkyWeatherService {
    static let shared = SkyWeatherService()

    var onChange: (() -> Void)?

    private static let refreshInterval: TimeInterval = 30 * 60
    private static let staleAfter: TimeInterval = 3 * 60 * 60
    nonisolated private static let requestTimeout: TimeInterval = 15
    nonisolated private static let projectEolURL = URL(string: "https://weatherapi.projecteol.ru/mcp/")!

    private struct Response: Decodable {
        struct Current: Decodable {
            var weatherCode: Int
            var cloudCover: Double
        }
        var current: Current
    }

    private struct EolResponse: Decodable {
        struct Result: Decodable {
            var isError: Bool?
            var structuredContent: Content?
        }
        struct Content: Decodable {
            var forecast: [Point]
        }
        struct Point: Decodable {
            var values: [String: Value]
        }
        struct Value: Decodable {
            var value: Double
        }
        var result: Result?
    }

    private let locator = SkyLocator()
    private var weather = SkyWeather.clear
    private var updated = Date.distantPast
    private var lastAttempt = Date.distantPast
    private var isRefreshing = false
    private var runningTask: URLSessionDataTask?

    private init() {}

    var current: SkyWeather {
        Date().timeIntervalSince(updated) < Self.staleAfter ? weather : .clear
    }

    var location: SkyLocation.Coordinate {
        locator.coordinate ?? SkyLocation.current
    }

    var sky: SkyIcon.State {
        SkyIcon.now(location: location, weather: current)
    }

    func refreshIfNeeded() {
        guard !isRefreshing, Date().timeIntervalSince(lastAttempt) >= Self.refreshInterval else { return }
        lastAttempt = Date()
        isRefreshing = true

        locator.locate { [weak self] located in
            self?.fetch(at: located ?? SkyLocation.current)
        }
    }

    func cancel() {
        locator.cancel()
        runningTask?.cancel()
        runningTask = nil
        isRefreshing = false
    }

    private func fetch(at location: SkyLocation.Coordinate) {
        start(URLRequest(url: Self.url(for: location), timeoutInterval: Self.requestTimeout), parse: Self.parse) { weather in
            guard weather == nil else { return Self.shared.finish(weather) }
            Self.shared.start(Self.projectEolRequest(for: location, at: Date()), parse: Self.parseProjectEol) { weather in
                Self.shared.finish(weather)
            }
        }
    }

    private func start(_ request: URLRequest, parse: @escaping @Sendable (Data) -> SkyWeather?,
                       then: @escaping @MainActor @Sendable (SkyWeather?) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            let weather = data.flatMap(parse)
            Task { @MainActor in
                // Cancelled meanwhile: the spinner is no longer this one.
                guard Self.shared.isRefreshing else { return }
                then(weather)
            }
        }
        runningTask = task
        task.resume()
    }

    private func finish(_ weather: SkyWeather?) {
        runningTask = nil
        isRefreshing = false
        if let weather {
            self.weather = weather
            updated = Date()
        }
        onChange?()
    }

    nonisolated static func url(for location: SkyLocation.Coordinate) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", location.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", location.longitude)),
            URLQueryItem(name: "current", value: "cloud_cover,weather_code"),
        ]
        return components.url!
    }

    nonisolated static func projectEolRequest(for location: SkyLocation.Coordinate, at date: Date) -> URLRequest {
        var hour = Calendar(identifier: .gregorian)
        hour.timeZone = TimeZone(identifier: "UTC")!
        let start = hour.dateInterval(of: .hour, for: date)?.start ?? date

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": [
                "name": "get_weather_forecast",
                "arguments": [
                    // Decimals, or 55.76 goes out as 55.759999999999998.
                    "latitude": NSDecimalNumber(string: String(format: "%.2f", location.latitude)),
                    "longitude": NSDecimalNumber(string: String(format: "%.2f", location.longitude)),
                    "start": ISO8601DateFormatter().string(from: start),
                    "hours": 1,
                    "parameters": ["surface.cloud_area_fraction", "surface.precipitation_flux"],
                ] as [String: Any],
            ] as [String: Any],
        ]

        var request = URLRequest(url: projectEolURL, timeoutInterval: requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return request
    }

    nonisolated static func parseProjectEol(_ data: Data) -> SkyWeather? {
        guard let response = try? JSONDecoder().decode(EolResponse.self, from: data),
              let result = response.result, result.isError != true,
              let values = result.structuredContent?.forecast.first?.values,
              let cover = values["surface.cloud_area_fraction"]?.value,
              let flux = values["surface.precipitation_flux"]?.value
        else { return nil }

        return SkyWeather(cloudCover: cover * 100, rainPerHour: max(0, flux) * 3600)
    }

    nonisolated static func parse(_ data: Data) -> SkyWeather? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(Response.self, from: data) else { return nil }
        return SkyWeather(weatherCode: response.current.weatherCode, cloudCover: response.current.cloudCover)
    }
}

enum SkyIcon {
    struct State: Equatable, Sendable {
        let sunUp: Bool
        let dusk: Int
        let phase: Int
        let weather: SkyWeather
    }

    static let duskSteps = 8
    static let phaseSteps = 16
    private static let clearDayAbove = 10.0
    static let sunFrameCount = 24
    static let frameCount = sunFrameCount

    static func sunFrameName(at index: Int) -> String {
        "Sun \(index)"
    }

    static func now(at date: Date = Date(),
                    location: SkyLocation.Coordinate = SkyLocation.current,
                    weather: SkyWeather = .clear) -> State {
        let elevation = Sun.elevation(at: date, latitude: location.latitude, longitude: location.longitude)
        let dusk = elevation > 0 ? 1 - Sun.smoothStep(elevation / clearDayAbove) : 0

        return State(
            sunUp: elevation > 0,
            dusk: Int((dusk * Double(duskSteps)).rounded()),
            phase: Int((Moon.phase(at: date) * Double(phaseSteps)).rounded()) % phaseSteps,
            weather: weather
        )
    }

    static func frames(_ state: State, height: CGFloat, effect: SpinnerEffect) -> [NSImage] {
        let tint: NSColor? = switch effect {
        case .original: nil
        case .automatic: .black
        case .whiteShaded: NSColor(red: 1, green: 1, blue: 1, alpha: 0.8)
        case .blackShaded: NSColor(red: 0, green: 0, blue: 0, alpha: 0.8)
        }

        let moves = state.sunUp || state.weather != .clear || tint == nil
        return (0 ..< (moves ? frameCount : 1)).map { index in
            let sun = state.sunUp ? NSImage(named: sunFrameName(at: index)) : nil
            let progress = CGFloat(index) / CGFloat(frameCount)
            let image = rasterize(side: height) { rect in
                draw(state, sun: sun, progress: progress, in: rect, tint: tint)
            }
            image.isTemplate = effect == .automatic
            return image
        }
    }

    private static func rasterize(side: CGFloat, draw: (NSRect) -> Void) -> NSImage {
        let scale: CGFloat = 2
        let pixels = Int((side * scale).rounded(.up))
        let size = NSSize(width: side, height: side)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return NSImage(size: size) }

        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    private static func draw(_ state: State, sun: NSImage?, progress: CGFloat, in rect: NSRect, tint: NSColor?) {
        let size = rect.width
        let rainy = state.weather == .rainy
        let body = state.weather == .clear
            ? rect
            : NSRect(x: rect.minX, y: rect.minY + size * (rainy ? 0.28 : 0.22), width: size * 0.78, height: size * 0.78)

        if state.sunUp {
            sun?.draw(in: body)
            if let tint {
                tint.set()
                body.fill(using: .sourceAtop)
            } else if state.dusk > 0 {
                // Low in the sky the sun reddens: a red-orange haze over it alone, before any cloud.
                rgb(0.95, 0.30, 0.15, 0.55 * CGFloat(state.dusk) / CGFloat(duskSteps)).set()
                body.fill(using: .sourceAtop)
            }
        } else if let tint {
            tint.set()
            drawMoonGlyph(in: body, phase: Double(state.phase) / Double(phaseSteps))
        } else {
            drawMoon(in: body, phase: Double(state.phase) / Double(phaseSteps), turn: progress)
        }

        guard state.weather != .clear else { return }
        let width = size * 0.78
        let sway = sin(2 * .pi * progress) * size * 0.02
        let cloud = NSRect(x: rect.maxX - width - size * 0.02 + sway, y: rect.minY + size * (rainy ? 0.24 : 0.08),
                           width: width, height: width * 0.52)

        if let tint {
            drawCloudGlyph(in: cloud, rainy: rainy, color: tint)
            if rainy {
                drops(under: cloud, progress: progress).fill()
            }
        } else {
            if rainy {
                rgb(0.45, 0.70, 0.95).setFill()
                drops(under: cloud, progress: progress).fill()
            }
            drawCloud(in: cloud, rainy: rainy)
        }
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    private static func litPath(disc: NSRect, phase: Double) -> NSBezierPath? {
        guard Moon.illumination(phase: phase) >= 0.005 else { return nil }

        let radius = disc.width / 2
        let centre = NSPoint(x: disc.midX, y: disc.midY)
        let terminator = abs(cos(2 * .pi * phase)) * radius
        let waxing = phase < 0.5
        let gibbous = Moon.illumination(phase: phase) > 0.5
        let direction: CGFloat = (waxing ? 1 : -1) * (gibbous ? -1 : 1)
        let kappa: CGFloat = 0.5523 // Bézier handle length for a quarter ellipse

        let top = NSPoint(x: centre.x, y: disc.maxY)
        let bottom = NSPoint(x: centre.x, y: disc.minY)
        let middle = NSPoint(x: centre.x + direction * terminator, y: centre.y)

        let path = NSBezierPath()
        path.move(to: top)
        path.appendArc(withCenter: centre, radius: radius, startAngle: 90, endAngle: -90, clockwise: waxing)
        path.curve(to: middle,
                   controlPoint1: NSPoint(x: bottom.x + direction * terminator * kappa, y: bottom.y),
                   controlPoint2: NSPoint(x: middle.x, y: centre.y - radius * kappa))
        path.curve(to: top,
                   controlPoint1: NSPoint(x: middle.x, y: centre.y + radius * kappa),
                   controlPoint2: NSPoint(x: top.x + direction * terminator * kappa, y: top.y))
        path.close()
        return path
    }

    private static func drawMoon(in rect: NSRect, phase: Double, turn: CGFloat) {
        let radius = rect.width * 0.46
        let disc = NSRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2)

        rgb(0.30, 0.33, 0.40, 0.55).setFill()
        NSBezierPath(ovalIn: disc).fill()

        guard let lit = litPath(disc: disc, phase: phase) else { return }
        NSGraphicsContext.saveGraphicsState()
        lit.addClip()

        NSGradient(starting: rgb(0.97, 0.97, 0.95), ending: rgb(0.74, 0.75, 0.77))?
            .draw(in: NSBezierPath(ovalIn: disc), relativeCenterPosition: NSPoint(x: -0.25, y: 0.3))

        NSGraphicsContext.saveGraphicsState()
        let rotation = NSAffineTransform()
        rotation.translateX(by: disc.midX, yBy: disc.midY)
        rotation.rotate(byRadians: -2 * .pi * turn)
        rotation.translateX(by: -disc.midX, yBy: -disc.midY)
        rotation.concat()

        let maria: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
            (-0.28, 0.32, 0.26), (-0.12, 0.40, 0.14), (0.10, 0.34, 0.16), (0.24, 0.10, 0.20), (0.12, 0.02, 0.12),
            (0.58, 0.28, 0.13), (-0.52, 0.05, 0.22), (-0.45, -0.22, 0.18), (-0.30, 0.00, 0.14),
            (-0.12, -0.32, 0.13), (0.40, -0.18, 0.13), (0.05, 0.18, 0.10),
        ]
        let blur = NSShadow()
        blur.shadowBlurRadius = radius * 0.10
        blur.shadowOffset = .zero
        blur.shadowColor = rgb(0.42, 0.44, 0.48, 0.9)
        blur.set()
        rgb(0.55, 0.57, 0.60, 0.42).setFill()
        for mare in maria {
            NSBezierPath(ovalIn: NSRect(x: disc.midX + (mare.x - mare.r) * radius,
                                        y: disc.midY + (mare.y - mare.r * 0.85) * radius,
                                        width: 2 * mare.r * radius, height: 1.7 * mare.r * radius)).fill()
        }
        NSShadow().set()

        let tycho = radius * 0.06
        rgb(1, 1, 1, 0.55).setFill()
        NSBezierPath(ovalIn: NSRect(x: disc.midX - radius * 0.15 - tycho, y: disc.midY - radius * 0.62 - tycho,
                                    width: tycho * 2, height: tycho * 2)).fill()
        NSGraphicsContext.restoreGraphicsState()

        // Limb darkening: a soft rim.
        NSGradient(colors: [rgb(0, 0, 0, 0), rgb(0, 0, 0, 0), rgb(0.2, 0.22, 0.28, 0.35)],
                   atLocations: [0, 0.75, 1], colorSpace: .sRGB)?
            .draw(in: NSBezierPath(ovalIn: disc), relativeCenterPosition: .zero)

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawMoonGlyph(in rect: NSRect, phase: Double) {
        let size = rect.width
        let radius = size * 0.36
        let stroke = max(0.5, size / 14)
        let disc = NSRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2)
        let outline = NSBezierPath(ovalIn: disc)
        outline.lineWidth = stroke * 0.55
        outline.stroke()

        litPath(disc: disc, phase: phase)?.fill()
    }

    private static func cloudPath(in box: NSRect) -> NSBezierPath {
        let path = NSBezierPath(roundedRect: NSRect(x: box.minX + 0.04 * box.width, y: box.minY,
                                                    width: 0.92 * box.width, height: 0.5 * box.height),
                                xRadius: 0.25 * box.height, yRadius: 0.25 * box.height)
        for (x, y, r) in [(0.26, 0.50, 0.20), (0.52, 0.62, 0.27), (0.78, 0.46, 0.18)] as [(CGFloat, CGFloat, CGFloat)] {
            path.append(NSBezierPath(ovalIn: NSRect(x: box.minX + (x - r) * box.width, y: box.minY + y * box.height - r * box.width,
                                                    width: 2 * r * box.width, height: 2 * r * box.width)))
        }
        path.windingRule = .nonZero
        return path
    }

    private static func drops(under box: NSRect, progress: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let size = box.width * 0.09
        for (x, lag) in [(0.25, 0.0), (0.52, 1.0 / 3), (0.78, 2.0 / 3)] as [(CGFloat, CGFloat)] {
            let fall = (progress + lag).truncatingRemainder(dividingBy: 1)
            let centre = NSPoint(x: box.minX + x * box.width, y: box.minY + box.height * (0.05 - 0.55 * fall))
            path.append(NSBezierPath(ovalIn: NSRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)))
            path.move(to: NSPoint(x: centre.x - size / 2, y: centre.y + size * 0.1))
            path.line(to: NSPoint(x: centre.x, y: centre.y + size * 1.1))
            path.line(to: NSPoint(x: centre.x + size / 2, y: centre.y + size * 0.1))
            path.close()
        }
        return path
    }

    private static func drawCloud(in box: NSRect, rainy: Bool) {
        let shape = cloudPath(in: box)

        (rainy ? rgb(0.30, 0.32, 0.36) : rgb(0.45, 0.66, 0.86)).setStroke()
        shape.lineWidth = max(1, box.width * 0.12)
        shape.stroke()

        let gradient = rainy
            ? NSGradient(starting: rgb(0.66, 0.69, 0.73), ending: rgb(0.52, 0.55, 0.60))
            : NSGradient(starting: rgb(1, 1, 1), ending: rgb(0.80, 0.89, 0.97))
        gradient?.draw(in: shape, angle: -90)

        rgb(1, 1, 1, rainy ? 0.35 : 0.9).setFill()
        for (x, y, w, h) in [(0.40, 0.72, 0.18, 0.12), (0.14, 0.40, 0.14, 0.12)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            NSBezierPath(ovalIn: NSRect(x: box.minX + x * box.width, y: box.minY + y * box.height,
                                        width: w * box.width, height: h * box.height)).fill()
        }
    }

    private static func drawCloudGlyph(in box: NSRect, rainy: Bool, color: NSColor) {
        let shape = cloudPath(in: box)
        let stroke = max(0.75, box.width * 0.09)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        shape.lineWidth = stroke * 3
        shape.stroke()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        color.set()
        shape.lineWidth = stroke * 2
        shape.stroke()
        if rainy {
            shape.fill()
        } else {
            // The inner half of the stroke would trace the overlapping bumps: clear it away.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
