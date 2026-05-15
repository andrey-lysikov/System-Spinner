//  Copyright © AndreyLysikov
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
    
    public func sendSystemNotification(title: String, body: String = "", action: String = "" ) {
        let content = UNMutableNotificationContent()
        let notificationCenter = UNUserNotificationCenter.current()
        let downloadAction = UNNotificationAction(identifier: action, title: action, options: .init(rawValue: 0))
        let category = UNNotificationCategory(identifier: "ACTION", actions: [downloadAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, _) in
            if granted {
                content.title = title
                content.body = body
                content.sound = UNNotificationSound.default
                
                if !action.isEmpty {
                    content.categoryIdentifier = "ACTION"
                    notificationCenter.setNotificationCategories([category])
                }
                
                notificationCenter.removeAllPendingNotificationRequests()
                notificationCenter.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            }
        }
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
        
       let versionAppString: String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as Any as! String
        
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
                        let versionGitString = try decoder.decode(versionEntry.self, from: data).tagName
                        let versionGit: Int = Int(trimCharacter(val: versionGitString))
                        let versionApp: Int = Int(trimCharacter(val: versionAppString))
                        
                        if versionGit > 0 && versionApp > 0 && versionGit > versionApp {
                            self.sendSystemNotification(title: localizedString("System Spinner update"),
                                                        body: localizedString("New version \(versionGitString) is available. Would you like download to update?"),
                                                        action: localizedString("Download"))
                        } else if checkNow {
                            self.sendSystemNotification(title: localizedString("System Spinner update"),
                                                        body: localizedString("You version \(versionAppString) is actual version."))
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
