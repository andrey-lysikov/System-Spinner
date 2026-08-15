//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Foundation

final class UpdateChecker {
    static let shared = UpdateChecker()

    static let repositoryURL = URL(string: "https://github.com/andrey-lysikov/System-Spinner")!
    static let latestReleaseURL = URL(string: "https://github.com/andrey-lysikov/System-Spinner/releases/latest")!

    private static let apiURL = URL(string: "https://api.github.com/repos/andrey-lysikov/System-Spinner/releases/latest")!
    private static let backgroundDelay: TimeInterval = 600

    private struct Release: Decodable {
        var tagName: String
    }

    private let preferences = Preferences.shared
    private let notifications = NotificationService.shared
    private var isChecking = false

    private init() {}

    var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    func check(force: Bool = false) {
        guard !isChecking, !installedVersion.isEmpty else { return }
        guard force || !Calendar.current.isDateInToday(preferences.lastVersionCheck) else { return }

        isChecking = true
        let installed = installedVersion
        let delay: DispatchTime = force ? .now() : .now() + Self.backgroundDelay

        DispatchQueue.main.asyncAfter(deadline: delay) { [self] in
            URLSession.shared.dataTask(with: Self.apiURL) { [self] data, _, _ in
                defer { isChecking = false }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                guard let data, let release = try? decoder.decode(Release.self, from: data) else { return }

                let latest = Self.versionNumber(release.tagName)
                let current = Self.versionNumber(installed)

                if latest > 0, current > 0, latest > current {
                    notifications.send(title: localizedString("System Spinner update"),
                                       body: localizedString("New version \(release.tagName) is available. Would you like download to update?"),
                                       action: .download)
                } else if force {
                    notifications.send(title: localizedString("System Spinner update"),
                                       body: localizedString("You version \(installed) is actual version."))
                }

                preferences.lastVersionCheck = Date()
            }.resume()
        }
    }

    private static func versionNumber(_ value: String) -> Int {
        Int(value.filter("0123456789".contains)) ?? 0
    }
}
