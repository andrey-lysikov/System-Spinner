//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import UserNotifications
import ApplicationServices

enum AccessibilityPermission {
    static var isTrusted: Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Проверяет доступ и, если его нет, показывает уведомление с кнопкой запроса.
    @discardableResult
    static func check() -> Bool {
        guard isTrusted else {
            NotificationService.shared.send(
                title: localizedString("System Spinner need special privileges"),
                body: localizedString("For complite work you need to allow System Spinner to use special privileges for keydoard mapping."),
                action: .allowPrivileges
            )
            return false
        }
        return true
    }

    static func request() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        AXIsProcessTrustedWithOptions(options)
    }
}

enum NotificationAction: String {
    case allowPrivileges = "action.allow"
    case quit = "action.quit"
    case download = "action.download"

    var title: String {
        switch self {
        case .allowPrivileges: return localizedString("Allow")
        case .quit: return localizedString("Quit")
        case .download: return localizedString("Download")
        }
    }
}

final class NotificationService {
    static let shared = NotificationService()

    private static let categoryIdentifier = "ACTION"

    private init() {}

    func send(title: String, body: String = "", action: NotificationAction? = nil) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            if let action {
                let button = UNNotificationAction(identifier: action.rawValue, title: action.title, options: [])
                let category = UNNotificationCategory(identifier: Self.categoryIdentifier,
                                                      actions: [button],
                                                      intentIdentifiers: [],
                                                      hiddenPreviewsBodyPlaceholder: "",
                                                      options: .customDismissAction)
                content.categoryIdentifier = Self.categoryIdentifier
                center.setNotificationCategories([category])
            }

            center.removeAllPendingNotificationRequests()
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
