//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Cocoa
import UserNotifications

var spinnerActive: String!
var enableStatusText: Bool = false
var updateInterval: Double = 1.0
var isDeviceChanged: Bool = true // update display menu on application start
var useLocalization: Bool = true
var alwaysUseCustomOSD: Bool = false
var adjSteps: Int = 16
var spinnersEffectSelected : Int = 1
var spinnersRotationInvert: Bool = false
var usePopUpAnimation: Bool = true
let ActivityData = AKservice()

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemMenu: NSMenu!
    private var appearanceObservation: NSKeyValueObservation?
    private var currentSpinnerFrames: [NSImage] = []
    private var sHelper = Helper()
    var statusItem: NSStatusItem = {
        return NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    
    private var cpuTimer: Timer? = nil
    private var spinnerLayer: CALayer? = nil
    private var lastSpinnerSpeed: Float = -1
    private let popover = NSPopover()
    private var updateIntervalName:[Double] = [0.5, 1.0, 1.5, 2.0]
    private var adjStepsInterval:[Int] = [8, 16, 24, 32]
    private var spinnersEffect: [String:Int] = [:]
    private let spinners: [String: [Int]] =  [ // [name: [item count, can use effect?, speed coefficient]]
        "Blue Ball" : [19, 1, 1],
        "Cat" : [5, 1, 2],
        "Circles Two" : [9, 1, 1],
        "Cirrcles" : [8, 0, 1],
        "Color Balls" : [17, 1, 1],
        "Color Well" : [20, 0, 1],
        "Dots" : [12, 0, 1],
        "Delay" : [17, 1, 1],
        "Grey Loader" : [18, 0, 1],
        "Loader" : [8, 0, 1],
        "Pie" : [6, 0, 1],
        "Pikachu" : [4, 1, 2],
        "Rainbow Pie" : [15, 0, 1],
        "Recharges" : [ 8, 1, 1],
        "Rotation Color Well" : [24, 0, 2],
        "Sun" : [23, 1, 1],
        "Waves" : [17, 1, 1]
    ]
    
    @objc private func aboutWindow(sender: NSStatusItem) {
        let appCurrentVersion: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)!
        let anAbout = NSAlert()
        anAbout.messageText = "System Spinner"
        anAbout.informativeText = localizedString("""
                                                  System Spinner provides macOS system information in status bar.
                                                  Minimal, small and light.
                                                  
                                                  Author: @Andrey.Lysikov
                                                  Version: \(appCurrentVersion)
                                                  """)
        anAbout.alertStyle = .informational
        anAbout.addButton(withTitle: localizedString("Goto site"))
        anAbout.addButton(withTitle: localizedString("Close"))
        let response = anAbout.runModal()
        switch response {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(URL(string: sHelper.appAboutUrl)!)
        default:
            anAbout.window.close()
        }
    }
    
    @objc private func checkNewVersion(sender: NSStatusItem) {
        sHelper.hasNewVersion(checkNow: true)
    }
    
    private func showPopover(sender: Any?) {
        if let button = statusItem.button {
            popover.animates = usePopUpAnimation
            button.window?.layoutIfNeeded()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func closePopoverMenu(sender: Any?) {
        statusItem.menu = nil
        
        if popover.isShown {
            popover.performClose(sender)
        }
    }
    
    private func changeSpinner(spinnerName: String) {
        stopRunning()
        spinnerActive = spinnerName
        let layer = CALayer()
        let spinnerFrames: Int = spinners[spinnerName]![0]
        let animation = CAKeyframeAnimation(keyPath: "contents")
        var frames: [NSImage] =  []
        guard let button = statusItem.button else { return }
        // load spinner
        frames = {
            return (0 ..< spinnerFrames).map { n in
                var image = NSImage(named: spinnerName + " \(n)")!
                image = image.resizeImage(width: (NSStatusBar.system.thickness - 2) / image.size.height * image.size.width, height: NSStatusBar.system.thickness - 2)
                if spinners[spinnerName]![1] > 0 {
                    switch spinnersEffectSelected {
                    case 2:
                        image = image.imageWithTint(color: NSColor(red: 1, green: 1, blue: 1, alpha: 0.8))
                        break
                    case 3:
                        image = image.imageWithTint(color: NSColor(red: 0, green: 0, blue: 0, alpha: 0.8))
                        break
                    case 4:
                        let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
                        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        image = image.imageWithTint(color: isDark ? .white : .black)
                    default: break
                    }
                }
                return image
            }
        }()

        self.currentSpinnerFrames = frames

        spinnerLayer?.removeFromSuperlayer()
        button.wantsLayer = true
        button.image?.size = frames[0].size
        animation.values = spinnersRotationInvert ? frames.reversed() : frames
        animation.duration = 0.25 * Double(spinners[spinnerActive]?[2] ?? 1) * Double(frames.count)
        animation.calculationMode = .discrete
        animation.repeatCount = .infinity
        layer.contents = frames.first
        layer.frame = CGRect(x: 0, y: 0, width: frames[0].size.width, height: button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness)
        layer.add(animation, forKey: "spin")

        button.layer?.addSublayer(layer)
        spinnerLayer = layer
        lastSpinnerSpeed = -1

        // update effect menu
        for menuItem in statusItemMenu.items {
            if menuItem.title == localizedString("Spinners Effects") {
                if spinners[spinnerName]![1] > 0 {
                    menuItem.action = #selector(changeSpinnerEffectClick(sender:))
                } else {
                    menuItem.action = nil
                }
            }
        }
        
        // update spinners menu
        for menuItem in statusItemMenu.items {
            if menuItem.hasSubmenu && menuItem.title == localizedString("Spinners") {
                for subMenuItem in menuItem.submenu!.items {
                    if subMenuItem.title == spinnerName {
                        subMenuItem.state = .on
                    } else {
                        subMenuItem.state = .off
                    }
                }
            }
        }
    
        statusItem.length = (enableStatusText ? 32 : 4) + frames[0].size.width
        
        startRunning()
        saveParams()
    }
    
    @objc private func handleAppearanceChange() {
        guard spinnersEffectSelected == 4,
              spinners[spinnerActive]![1] > 0,
              let layer = spinnerLayer,
              let currentAnimation = layer.animation(forKey: "spin") as? CAKeyframeAnimation,
              !currentSpinnerFrames.isEmpty else { return }
        
        guard let animationCopy = currentAnimation.copy() as? CAKeyframeAnimation else { return }
        let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let tintColor = isDark ? NSColor.white : NSColor.black
        let tintedFrames = currentSpinnerFrames.map { $0.imageWithTint(color: tintColor) }
        animationCopy.values = spinnersRotationInvert ? tintedFrames.reversed() : tintedFrames
        layer.add(animationCopy, forKey: "spin")
        layer.contents = spinnersRotationInvert ? tintedFrames.last : tintedFrames.first
    }
    
    @objc private func WakeNotification() {
        isDeviceChanged = true // maybe devices changed?
        startRunning()
    }
    
    @objc private func startRunning() {
        cpuTimer?.invalidate()
        cpuTimer = Timer(timeInterval: updateInterval, repeats: true, block: { [weak self] _ in
            self?.updateUsage()
        })
        RunLoop.main.add(cpuTimer!, forMode: .common)
        cpuTimer?.fire()
    }

    @objc private func stopRunning() {
        closePopoverMenu(sender: self)
        cpuTimer?.invalidate()
        spinnerLayer?.removeAllAnimations()
    }

    private func applySpinnerSpeed() {
        guard let layer = spinnerLayer else { return }
        let factor = Float(max(1.0, min(100.0, ActivityData.cpuPercentage / Double(spinners[spinnerActive]![0] - 1))))
        if abs(factor - lastSpinnerSpeed) < 0.01 { return }
        let now = CACurrentMediaTime()
        let local = layer.convertTime(now, from: nil)
        layer.speed = factor
        layer.timeOffset = local
        layer.beginTime = now
        lastSpinnerSpeed = factor
    }

    private func updateUsage() {
        ActivityData.update()
        applySpinnerSpeed()
        
        statusItem.button?.title = enableStatusText ? "   \(Int(ActivityData.cpuPercentage))%" : ""

        // check if we need update display and menu
        if isDeviceChanged {
            isDeviceChanged = false
            displayDeviceChanged()
        }
    }
    
    @objc static func doChangeDevice() {
        isDeviceChanged = true
    }
    
    @objc private func togglePopover(sender: NSStatusItem) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.leftMouseUp {
            if popover.isShown {
                closePopoverMenu(sender: sender)
            } else {
                statusItem.menu = nil
                showPopover(sender: sender)
            }
        } else {
            statusItem.menu = statusItemMenu
            statusItem.button?.performClick(nil)
        }
    }
    
    @objc private func changeSpinnerClick(sender: NSMenuItem) {
        changeSpinner(spinnerName: sender.title)
    }
    
    @objc private func analitycstApp(sender: NSMenuItem) {
        sHelper.openAnalitycstApp()
    }
    
    @objc private func changeUpdateSpeedClick(sender: NSMenuItem) {
        stopRunning()
        
        for menuItem in statusItemMenu.items { // set all submenu state off
            if menuItem.hasSubmenu && menuItem.title == sender.parent?.title {
                for subMenuItem in menuItem.submenu!.items {
                    subMenuItem.state = .off
                }
            }
        }
        
        updateInterval = Double(sender.title.replacingOccurrences(of: localizedString("Second"), with: "").trimmingCharacters(in: .whitespacesAndNewlines))!
        sender.state = .on
        changeSpinner(spinnerName: spinnerActive)
    }
    
    @objc private func changeAdjustmentStepsClick(sender: NSMenuItem) {
        for menuItem in statusItemMenu.items { // set all submenu state off
            if menuItem.hasSubmenu && menuItem.title == sender.parent?.title {
                for subMenuItem in menuItem.submenu!.items {
                    subMenuItem.state = .off
                }
            }
        }
        adjSteps = Int(sender.title) ?? adjSteps
        sender.state = .on
        saveParams()
    }
    
    @objc private func changeSpinnerEffectClick(sender: NSMenuItem) {
        stopRunning()
        
        for menuItem in statusItemMenu.items { // set all submenu state off
            if menuItem.hasSubmenu && menuItem.title == sender.parent?.title {
                for subMenuItem in menuItem.submenu!.items {
                    subMenuItem.state = .off
                }
            }
        }
        
        for (_, value) in spinnersEffect.enumerated() {
            if value.key == sender.title {
                spinnersEffectSelected = value.value
            }
        }
            
        sender.state = .on
        changeSpinner(spinnerName: spinnerActive)
    }

    @objc private func changeLaunchAtLogin(sender: NSMenuItem) {
        if sHelper.isAutoLaunch {
            sender.state = .off
            sHelper.isAutoLaunch = false
        } else {
            sender.state = .on
            sHelper.isAutoLaunch = true
        }
        saveParams()
    }
    
    @objc private func changeSpinnersRotationInvert(sender: NSMenuItem) {
        if spinnersRotationInvert {
            sender.state = .off
            spinnersRotationInvert = false
        } else {
            sender.state = .on
            spinnersRotationInvert = true
        }
        changeSpinner(spinnerName: spinnerActive)
    }
    
    @objc private func changelocalizeClick(sender: NSMenuItem) {
        if useLocalization {
            sender.state = .off
            useLocalization = false
        } else {
            sender.state = .on
            useLocalization = true
        }
        saveParams()
        updateStatusMenu()
        changeSpinner(spinnerName: spinnerActive)
    }
    
    @objc private func changePopUpAnimationClick(sender: NSMenuItem) {
        if usePopUpAnimation {
            sender.state = .off
            usePopUpAnimation = false
        } else {
            sender.state = .on
            usePopUpAnimation = true
        }
        saveParams()
    }
    
    @objc private func changeAlwaysUseCustomOSDClick(sender: NSMenuItem) {
        if alwaysUseCustomOSD {
            sender.state = .off
            alwaysUseCustomOSD = false
        } else {
            sender.state = .on
            alwaysUseCustomOSD = true
        }
        saveParams()
        displayDeviceChanged()
    }
    
    @objc private func displayDeviceChanged() {
        var displayMenuItem: NSMenuItem = NSMenuItem()
        let displaySubMenu = NSMenu()
        
        DisplayManager.shared.configureDisplays()
        
        // let find menu intem
        for menuItem in statusItemMenu.items {
            if menuItem.title == localizedString("HDMI/DVI DDC enabled") {
                displayMenuItem = menuItem
            }
        }
        
        for displayItem in DisplayManager.shared.displays {
            let newItem = NSMenuItem(title: displayItem.name, action: #selector(WakeNotification), keyEquivalent: "")
            newItem.image = NSImage(systemSymbolName: "display", accessibilityDescription: displayItem.name)
            if displayItem.isBuiltIn() {
                newItem.action = nil
            }
            
            displaySubMenu.addItem(newItem)
        }
        
        displayMenuItem.submenu = displaySubMenu
        
        if sHelper.checkPrivileges() {
            MediaKeyMonitor.shared.start()
        }
        
        // Check new version?
        sHelper.hasNewVersion()
    }
    
    @objc private func changeStatusMenuClick(sender: NSMenuItem) {
        if enableStatusText {
            sender.state = .off
            enableStatusText = false
        } else {
            sender.state = .on
            enableStatusText = true
        }
        changeSpinner(spinnerName: spinnerActive)
    }
    
    @objc func applicationQuit() {
        MediaKeyMonitor.shared.stop()
        appearanceObservation?.invalidate()
        stopRunning()
        saveParams()
        exit(0)
    }
    
    private func saveParams() {
        UserDefaults.standard.set(spinnerActive, forKey: "spinnerActive")
        UserDefaults.standard.set(updateInterval, forKey: "spinnerUpdateInterval")
        UserDefaults.standard.set(enableStatusText, forKey: "enableStatusText")
        UserDefaults.standard.set(useLocalization, forKey: "useLocalization")
        UserDefaults.standard.set(spinnersEffectSelected, forKey: "spinnersEffectSelected")
        UserDefaults.standard.set(spinnersRotationInvert, forKey: "spinnersRotationInvert")
        UserDefaults.standard.set(alwaysUseCustomOSD, forKey: "alwaysUseCustomOSD")
        UserDefaults.standard.set(adjSteps, forKey: "adjSteps")
        UserDefaults.standard.set(usePopUpAnimation, forKey: "usePopUpAnimation")
    }
    
    private func updateStatusMenu() {
        // create pop up menu if in not menu
        statusItemMenu = NSMenu()
        
        // open Analytics
        let analyticsItem = NSMenuItem(title: localizedString("Activity Monitor"), action: #selector(analitycstApp(sender:)), keyEquivalent: "")
        analyticsItem.image = NSImage(systemSymbolName: "ellipsis.curlybraces", accessibilityDescription: localizedString("Activity Monitor"))
        statusItemMenu.addItem(analyticsItem)
        
        // Text status in Menu
        let statusItem = NSMenuItem(title: localizedString("Show CPU usage in menu"), action: #selector(changeStatusMenuClick(sender:)), keyEquivalent: "")
        statusItem.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: localizedString("Show CPU usage in menu"))
        if enableStatusText {
            statusItem.state = .on
        }
        statusItemMenu.addItem(statusItem)
        
        // launch At Login
        let launchAtLoginItem = NSMenuItem(title: localizedString("Enable Autostart"), action: #selector(changeLaunchAtLogin(sender:)), keyEquivalent: "")
        if sHelper.isAutoLaunch {
            launchAtLoginItem.state = .on
        }
        launchAtLoginItem.image = NSImage(systemSymbolName: "character", accessibilityDescription: localizedString("Enable Autostart"))
        statusItemMenu.addItem(launchAtLoginItem)
        statusItemMenu.addItem(NSMenuItem.separator())
        
        // ---------------------------- Display controll Section ----------------------------
        let displayItem = NSMenuItem(title: localizedString("HDMI/DVI DDC enabled"), action:  #selector(WakeNotification), keyEquivalent: "")
        displayItem.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: localizedString("HDMI/DVI DDC enabled"))
        statusItemMenu.addItem(displayItem)
        statusItemMenu.setSubmenu(NSMenu(), for: displayItem)
        
        // OSD number of adjustment steps
        let separatorSubMenu = NSMenu()
        let separatorMenu = NSMenuItem(title: localizedString("Adjustment steps"), action: nil, keyEquivalent: "")
        
        for updateItem in adjStepsInterval {
            let newItem = NSMenuItem(title: String(updateItem), action: #selector(changeAdjustmentStepsClick(sender:)), keyEquivalent: "")
            if updateItem == adjSteps {
                newItem.state = .on
            } else {
                newItem.state = .off
            }
            separatorSubMenu.addItem(newItem)
        }
        separatorMenu.image = NSImage(systemSymbolName: "display.and.screwdriver", accessibilityDescription: localizedString("Adjustment steps"))
        statusItemMenu.addItem(separatorMenu)
        statusItemMenu.setSubmenu(separatorSubMenu, for: separatorMenu)
        
        
        // Custom OSD use for all device
        let customOSDItem = NSMenuItem(title: localizedString("Always use custom OSD"), action: #selector(changeAlwaysUseCustomOSDClick(sender:)), keyEquivalent: "")
        if alwaysUseCustomOSD {
            customOSDItem.state = .on
        }
        customOSDItem.image = NSImage(systemSymbolName: "dot.scope.display", accessibilityDescription: localizedString("Always use custom OSD"))
        statusItemMenu.addItem(customOSDItem)
        
        // Localize Item
        let localizeItem = NSMenuItem(title: localizedString("Use system language"), action: #selector(changelocalizeClick(sender:)), keyEquivalent: "")
        if useLocalization {
            localizeItem.state = .on
        }
        localizeItem.image = NSImage(systemSymbolName: "translate", accessibilityDescription: localizedString("Use system language"))
        statusItemMenu.addItem(localizeItem)
        
        // animation menu Item
        let animationItem = NSMenuItem(title: localizedString("Use popup animation"), action: #selector(changePopUpAnimationClick(sender:)), keyEquivalent: "")
        if usePopUpAnimation {
            animationItem.state = .on
        }
        animationItem.image = NSImage(systemSymbolName: "lasso.badge.sparkles", accessibilityDescription: localizedString("Use popup animation"))
        statusItemMenu.addItem(animationItem)
        statusItemMenu.addItem(NSMenuItem.separator())
                
        // ---------------------------- Spinner Section ----------------------------
        let spinnersSubMenu = NSMenu()
        let spinnersMenu = NSMenuItem(title: localizedString("Spinners"), action: nil, keyEquivalent: "")
        
        for spinnersItem in spinners.keys {
            let newItem = NSMenuItem(title: spinnersItem, action: #selector(changeSpinnerClick(sender:)), keyEquivalent: "")
            let image = NSImage(named: spinnersItem + " 1")!
            image.size = NSSize(width: 19 / image.size.height * image.size.width, height: 19)
            newItem.image = image
            spinnersSubMenu.addItem(newItem)
        }
        spinnersMenu.image = NSImage(systemSymbolName: "checklist.unchecked", accessibilityDescription: localizedString("Spinners"))
        statusItemMenu.addItem(spinnersMenu)
        statusItemMenu.setSubmenu(spinnersSubMenu, for: spinnersMenu)
        
        let updateSubMenu = NSMenu()
        let updateMenu = NSMenuItem(title: localizedString("Data update every"), action: nil, keyEquivalent: "")
        
        for updateItem in updateIntervalName {
            let newItem = NSMenuItem(title: String(updateItem) + " " + localizedString("Second"), action: #selector(changeUpdateSpeedClick(sender:)), keyEquivalent: "")
            if updateItem == updateInterval {
                newItem.state = .on
            } else {
                newItem.state = .off
            }
            updateSubMenu.addItem(newItem)
        }
        updateMenu.image = NSImage(systemSymbolName: "progress.indicator", accessibilityDescription: localizedString("Data update every"))
        statusItemMenu.addItem(updateMenu)
        statusItemMenu.setSubmenu(updateSubMenu, for: updateMenu)
        
        let spinnersEffectSubMenu = NSMenu()
        let spinnersEffectMenu = NSMenuItem(title: localizedString("Spinners Effects"), action: nil, keyEquivalent: "")
        
        spinnersEffect = [
            localizedString("Original")  : 1,
            localizedString("White shaded") : 2,
            localizedString("Black shaded") : 3,
            localizedString("Automatic Dark/White mode") : 4
        ]
        
        for (_, value) in spinnersEffect.enumerated() {
            let newItem = NSMenuItem(title: value.key, action: #selector(changeSpinnerEffectClick(sender:)), keyEquivalent: "")
            if value.value == spinnersEffectSelected {
                newItem.state = .on
            }
            spinnersEffectSubMenu.addItem(newItem)
        }
        spinnersEffectMenu.image = NSImage(systemSymbolName: "wand.and.sparkles.inverse", accessibilityDescription: localizedString("Spinners Effects"))
        statusItemMenu.addItem(spinnersEffectMenu)
        statusItemMenu.setSubmenu(spinnersEffectSubMenu, for: spinnersEffectMenu)
        
        let invertedItem = NSMenuItem(title: localizedString("Invert rotation"), action: #selector(changeSpinnersRotationInvert(sender:)), keyEquivalent: "")
        if spinnersRotationInvert {
            invertedItem.state = .on
        }
        invertedItem.image = NSImage(systemSymbolName: "circle.righthalf.filled.inverse", accessibilityDescription: localizedString("Invert rotation"))
        statusItemMenu.addItem(invertedItem)
        
        statusItemMenu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: localizedString("About"), action: #selector(aboutWindow(sender:)), keyEquivalent: "")
        aboutItem.image = NSImage(systemSymbolName: "info", accessibilityDescription: localizedString("About"))
        statusItemMenu.addItem(aboutItem)
        
        let checkUpdateItem = NSMenuItem(title: localizedString("Check new version"), action: #selector(checkNewVersion(sender:)), keyEquivalent: "")
        checkUpdateItem.image = NSImage(systemSymbolName: "arrow.trianglehead.clockwise.rotate.90", accessibilityDescription: localizedString("Check new version"))
        statusItemMenu.addItem(checkUpdateItem)
        
        let quitItem = NSMenuItem(title: localizedString("Quit"), action: #selector(applicationQuit), keyEquivalent: "")
        quitItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: localizedString("Quit"))
        statusItemMenu.addItem(quitItem)
        
        isDeviceChanged = true
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // close app if it running
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        for app in runningApps {
            if app.processIdentifier != NSRunningApplication.current.processIdentifier {
                app.terminate()
            }
        }
        
        // load app preferences
        spinnerActive = UserDefaults.standard.string(forKey: "spinnerActive") ?? "Loader"
        updateInterval = Double(UserDefaults.standard.string(forKey: "spinnerUpdateInterval") ?? String(updateInterval))!
        enableStatusText = Bool(UserDefaults.standard.bool(forKey: "enableStatusText"))
        useLocalization = Bool(UserDefaults.standard.bool(forKey: "useLocalization"))
        spinnersEffectSelected = Int(UserDefaults.standard.string(forKey: "spinnersEffectSelected") ?? String(spinnersEffectSelected))!
        spinnersRotationInvert = Bool(UserDefaults.standard.bool(forKey: "spinnersRotationInvert"))
        alwaysUseCustomOSD = Bool(UserDefaults.standard.bool(forKey: "alwaysUseCustomOSD"))
        adjSteps = Int(UserDefaults.standard.string(forKey: "adjSteps") ?? String(adjSteps))!
        usePopUpAnimation = Bool(UserDefaults.standard.bool(forKey: "usePopUpAnimation"))
        
        if let button = statusItem.button {
            button.action = #selector(togglePopover(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        }
        
        popover.contentViewController = UsageViewController.freshController()
        
        // create menu
        updateStatusMenu()
        
        // start spinning!
        changeSpinner(spinnerName: spinnerActive)
        
        // if we wakup
        NotificationCenter.default.addObserver(self, selector: #selector(WakeNotification), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(WakeNotification), name: NSWorkspace.screensDidWakeNotification, object: nil)
        
        // if we go to sleep
        NotificationCenter.default.addObserver(self, selector: #selector(stopRunning), name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopRunning), name: NSWorkspace.screensDidSleepNotification, object: nil)
   
        // mouse click event
        NSEvent.addGlobalMonitorForEvents(matching: [NSEvent.EventTypeMask.leftMouseDown,NSEvent.EventTypeMask.rightMouseDown], handler: { [self](event: NSEvent) in
            closePopoverMenu(sender: self)
        })
        
        appearanceObservation = statusItem.button?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
               DispatchQueue.main.async {
                   self?.handleAppearanceChange()
               }
        }
        
        // change monitor device?
        CGDisplayRegisterReconfigurationCallback({ displayID, flags, userInfo in AppDelegate.doChangeDevice()}, nil)
        
        UNUserNotificationCenter.current().delegate = self
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        applicationQuit()
     }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

func localizedString(_ key: String.LocalizationValue) -> String {
    if useLocalization {
        return String(localized: key)
    } else {
        return String(localized: key, table: "English")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == localizedString("Allow")  {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            AXIsProcessTrustedWithOptions(options)
        } else if response.actionIdentifier == localizedString("Quit") {
            applicationQuit()
        } else if response.actionIdentifier == localizedString("Download") {
            NSWorkspace.shared.open(URL(string: sHelper.appLastestUrl)!)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

extension NSImage {
    func resizeImage(width: CGFloat, height: CGFloat) -> NSImage {
        let img = NSImage(size: CGSize(width:width, height:height))
        img.lockFocus()
        let ctx = NSGraphicsContext.current
        ctx?.imageInterpolation = .high
        self.draw(in: NSMakeRect(0, 0, width, height), from: NSMakeRect(0, 0, size.width, size.height), operation: .copy, fraction: 1)
        img.unlockFocus()

        return img
    }
    
    func imageWithTint(color: NSColor) -> NSImage {
           guard let tintedImage = self.copy() as? NSImage else { return self }
           tintedImage.lockFocus()
           
           color.set()
           let imageRect = NSRect(origin: .zero, size: tintedImage.size)
           imageRect.fill(using: .sourceAtop)
           
           tintedImage.unlockFocus()
           return tintedImage
    }
}
