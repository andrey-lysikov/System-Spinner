//  Copyright © Andrey Lysikov
//  SPDX-License-Identifier: Apache-2.0

import AppKit
import ServiceManagement
import UserNotifications

class Helper: NSObject, UNUserNotificationCenterDelegate {
    private var checkNewVersionInProgress: Bool = false
    public let appApiUrl = "https://api.github.com/repos/andrey-lysikov/System-Spinner/releases/latest"
    public let appLastestUrl = "https://github.com/andrey-lysikov/System-Spinner/releases/latest"
    public let appAboutUrl = "https://github.com/andrey-lysikov/System-Spinner"
    
    public var isAutoLaunch: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }
                    
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Can't use SMAppService")
            }
        }
    }
    
    public func openAnalitycstApp() {
        let url = NSURL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app", isDirectory: true) as URL
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["/bin"]
        NSWorkspace.shared.openApplication(at: url,
                                           configuration: configuration,
                                           completionHandler: nil)
    }
    
    public func checkPrivileges() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
        if !AXIsProcessTrustedWithOptions(options) { sendSystemNotification(title: localizedString("System Spinner need special privileges"),
                                                                            body: localizedString("For complite work you need to allow System Spinner to use special privileges for keydoard mapping."),
                                                                            action: localizedString("Allow"))
            return false
        } else {
            return true
        }
        
    }
    
    public func sendSystemNotification(title: String, body: String = "", action: String) {
        let content = UNMutableNotificationContent()
        let notificationCenter = UNUserNotificationCenter.current()
        let downloadAction = UNNotificationAction(identifier: action, title: action, options: .init(rawValue: 0))
        let category = UNNotificationCategory(identifier: "ACTION", actions: [downloadAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        
        content.title = title
        content.body = body
        content.categoryIdentifier = "ACTION"
        notificationCenter.setNotificationCategories([category])
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.requestAuthorization(options: [.alert,.sound]) { (granted, error) in
            if !granted {
                print("Notifications is not allowed")
            }
        }
        notificationCenter.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if  response.actionIdentifier == localizedString("Download") {
            guard let url = URL(string: appLastestUrl) else {
                return
            }
            NSWorkspace.shared.open(url)
        } else if response.actionIdentifier == localizedString("Allow") {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            AXIsProcessTrustedWithOptions(options)
        } else if response.actionIdentifier == localizedString("Quit") {
            exit(0)
        }
        completionHandler()
    }
    
    public func hasNewVersion(checkNow: Bool = false) {
        struct versionEntry: Codable {
            let id: Int
            var tagName: String
            let name: String
        }
        
        func trimCharacter(val: Any) -> Int {
            let forFilter = val as? String ?? ""
            let filteredString = forFilter.filter("0123456789".contains)
            return Int(filteredString) ?? 0
        }
        
        let appCurrentVersion = trimCharacter(val: Bundle.main.infoDictionary!["CFBundleShortVersionString"] as Any)
        
        guard let url = URL(string: appApiUrl) else {
            return
        }
        
        if let lastCheckUpdate: Date = UserDefaults.standard.object(forKey: "group.lastCheckVersion") as? Date, (!Calendar.current.isDateInToday(lastCheckUpdate) || checkNow) && !checkNewVersionInProgress {
            checkNewVersionInProgress = true
            var startAfter: DispatchTime = .now() + 600
            if checkNow {startAfter = .now()}
            DispatchQueue.main.asyncAfter(deadline: startAfter) {
                URLSession.shared.dataTask(with: url) { (data, res, err) in
                    guard let data = data else {
                        return
                    }
                    
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let versionString = try decoder.decode(versionEntry.self, from: data).tagName
                        let versionGit = trimCharacter(val: versionString)
                        if versionGit > 0 && appCurrentVersion > 0 && versionGit > appCurrentVersion {
                            self.sendSystemNotification(title: localizedString("System Spinner has updated"),
                                                        body: localizedString("An new version \(versionString) is available. Would you like download to update?"),
                                                        action: localizedString("Download"))
                        }
                        UserDefaults.standard.set(Date(), forKey: "group.lastCheckVersion")
                        self.checkNewVersionInProgress = false
                    } catch {
                        return
                    }
                }.resume()
            }
        } else {
            UserDefaults.standard.set(Date(), forKey: "group.lastCheckVersion")
        }
    }

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
}

func localizedString(_ key: String.LocalizationValue) -> String {
    if useLocalization {
        return String(localized: key)
    } else {
        return String(localized: key, table: "English")
    }
}

extension NSImage {
    func image(with tintColor: NSColor) -> NSImage {
        if self.isTemplate == false {
            return self
        }
        
        let image = self.copy() as! NSImage
        image.lockFocus()
        
        tintColor.set()
        
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceIn)
        
        image.unlockFocus()
        image.isTemplate = false
        
        return image
    }
}
