//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Cocoa
import UserNotifications

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItemController = StatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()

        UNUserNotificationCenter.current().delegate = self
        statusItemController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MediaKeyMonitor.shared.stop()
        statusItemController.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func terminateOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where app.processIdentifier != NSRunningApplication.current.processIdentifier {
            app.terminate()
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        switch NotificationAction(rawValue: response.actionIdentifier) {
        case .allowPrivileges:
            AccessibilityPermission.request()
        case .quit:
            NSApp.terminate(nil)
        case .download:
            NSWorkspace.shared.open(UpdateChecker.latestReleaseURL)
        case nil:
            break
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
