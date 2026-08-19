//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Cocoa
import ServiceManagement

@MainActor
protocol AppMenuControllerDelegate: AnyObject {
    func appMenuDidChangeSpinnerAppearance(_ controller: AppMenuController)
    func appMenuDidChangeUpdateInterval(_ controller: AppMenuController)
    func appMenuDidRequestDisplayRefresh(_ controller: AppMenuController)
    func appMenuDidRequestQuit(_ controller: AppMenuController)
}

enum LoginItemService {
    static var isEnabled: Bool {
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
                print("Can't use SMAppService: \(error)")
            }
        }
    }
}

@MainActor
final class AppMenuController: NSObject {
    weak var delegate: AppMenuControllerDelegate?

    private(set) var menu = NSMenu()
    private let preferences = Preferences.shared

    private var displaysItem: NSMenuItem?
    private var effectsItem: NSMenuItem?

    private let updateIntervals: [Double] = [0.5, 1.0, 1.5, 2.0]
    private let adjustmentSteps: [Int] = [8, 16, 24, 32]

    func rebuild() {
        let menu = NSMenu()

        menu.addItem(item(localizedString("Activity Monitor"),
                          symbol: "ellipsis.curlybraces",
                          action: #selector(openActivityMonitor)))

        menu.addItem(item(localizedString("Show CPU usage in menu"),
                          symbol: "cpu",
                          action: #selector(toggleStatusText),
                          state: preferences.showsCPUInMenuBar))

        menu.addItem(item(localizedString("Enable Autostart"),
                          symbol: "character",
                          action: #selector(toggleLaunchAtLogin),
                          state: LoginItemService.isEnabled))

        menu.addItem(.separator())

        let displays = item(localizedString("HDMI/DVI DDC enabled"),
                            symbol: "display.2",
                            action: #selector(refreshDisplays))
        displays.submenu = NSMenu()
        menu.addItem(displays)
        displaysItem = displays

        let steps = item(localizedString("Adjustment steps"), symbol: "display.and.screwdriver", action: nil)
        steps.submenu = submenu(adjustmentSteps.map { (String($0), $0 == preferences.adjustmentSteps) },
                                action: #selector(changeAdjustmentSteps(sender:)))
        menu.addItem(steps)

        menu.addItem(item(localizedString("Always use custom OSD"),
                          symbol: "dot.scope.display",
                          action: #selector(toggleCustomOSD),
                          state: preferences.alwaysUsesCustomOSD))

        menu.addItem(item(localizedString("Keyboard backlight on F5/F6"),
                          symbol: "keyboard",
                          action: KeyboardBacklight.shared.isAvailable ? #selector(toggleKeyboardBacklightKeys) : nil,
                          state: preferences.usesKeyboardBacklightKeys))

        menu.addItem(item(localizedString("Use system language"),
                          symbol: "translate",
                          action: #selector(toggleLocalization),
                          state: preferences.usesSystemLanguage))

        menu.addItem(item(localizedString("Use popup animation"),
                          symbol: "lasso.badge.sparkles",
                          action: #selector(togglePopUpAnimation),
                          state: preferences.usesPopUpAnimation))

        menu.addItem(item(localizedString("Show external ip address"),
                          symbol: "globe",
                          action: #selector(toggleExternalAddress),
                          state: preferences.showsExternalAddress))

        menu.addItem(.separator())

        let spinners = item(localizedString("Spinners"), symbol: "checklist.unchecked", action: nil)
        spinners.submenu = spinnersSubmenu()
        menu.addItem(spinners)

        let intervals = item(localizedString("Data update every"), symbol: "progress.indicator", action: nil)
        intervals.submenu = submenu(updateIntervals.map {
            (String($0) + " " + localizedString("Second"), $0 == preferences.updateInterval)
        }, action: #selector(changeUpdateInterval(sender:)))
        menu.addItem(intervals)

        let effects = item(localizedString("Spinners Effects"), symbol: "wand.and.sparkles.inverse", action: nil)
        effects.submenu = submenu(SpinnerEffect.allCases.map {
            ($0.title, $0.rawValue == preferences.spinnerEffect)
        }, action: #selector(changeEffect(sender:)))
        menu.addItem(effects)
        effectsItem = effects

        menu.addItem(item(localizedString("Invert rotation"),
                          symbol: "circle.righthalf.filled.inverse",
                          action: #selector(toggleRotation),
                          state: preferences.invertsRotation))

        menu.addItem(.separator())

        menu.addItem(item(localizedString("About"), symbol: "info", action: #selector(showAbout)))
        menu.addItem(item(localizedString("Check new version"),
                          symbol: "arrow.trianglehead.clockwise.rotate.90",
                          action: #selector(checkNewVersion)))
        menu.addItem(item(localizedString("Quit"), symbol: "xmark", action: #selector(quit)))

        self.menu = menu
        refreshSpinnerState()
    }

    func updateDisplays(_ displays: [Display]) {
        let submenu = NSMenu()

        for display in displays {
            let entry = NSMenuItem(title: display.name,
                                   action: display.isBuiltIn() ? nil : #selector(refreshDisplays),
                                   keyEquivalent: "")
            entry.target = self
            entry.image = NSImage(systemSymbolName: "display", accessibilityDescription: display.name)
            submenu.addItem(entry)
        }

        displaysItem?.submenu = submenu
    }

    func refreshSpinnerState() {
        let style = SpinnerCatalog.style(validating: preferences.spinnerName)
        effectsItem?.action = style.supportsEffect ? #selector(changeEffect(sender:)) : nil
        effectsItem?.isEnabled = style.supportsEffect
    }

    private func item(_ title: String, symbol: String, action: Selector?, state: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        item.state = state ? .on : .off
        return item
    }

    private func submenu(_ entries: [(title: String, selected: Bool)], action: Selector) -> NSMenu {
        let submenu = NSMenu()
        for entry in entries {
            let item = NSMenuItem(title: entry.title, action: action, keyEquivalent: "")
            item.target = self
            item.state = entry.selected ? .on : .off
            submenu.addItem(item)
        }
        return submenu
    }

    private func spinnersSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for style in SpinnerCatalog.all {
            let item = NSMenuItem(title: style.name, action: #selector(changeSpinner(sender:)), keyEquivalent: "")
            item.target = self
            item.state = style.name == preferences.spinnerName ? .on : .off
            if let image = NSImage(named: style.name + " 1") {
                image.size = NSSize(width: 19 / image.size.height * image.size.width, height: 19)
                item.image = image
            }
            submenu.addItem(item)
        }
        return submenu
    }

    private func selectExclusively(_ sender: NSMenuItem) {
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
    }

    @objc private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app", isDirectory: true)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func toggleStatusText(sender: NSMenuItem) {
        preferences.showsCPUInMenuBar.toggle()
        sender.state = preferences.showsCPUInMenuBar ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(sender: NSMenuItem) {
        LoginItemService.isEnabled.toggle()
        sender.state = LoginItemService.isEnabled ? .on : .off
    }

    @objc private func toggleCustomOSD(sender: NSMenuItem) {
        preferences.alwaysUsesCustomOSD.toggle()
        sender.state = preferences.alwaysUsesCustomOSD ? .on : .off
        delegate?.appMenuDidRequestDisplayRefresh(self)
    }

    @objc private func toggleKeyboardBacklightKeys(sender: NSMenuItem) {
        preferences.usesKeyboardBacklightKeys.toggle()
        sender.state = preferences.usesKeyboardBacklightKeys ? .on : .off
    }

    @objc private func toggleLocalization(sender: NSMenuItem) {
        preferences.usesSystemLanguage.toggle()
        rebuild()
        delegate?.appMenuDidRequestDisplayRefresh(self)
    }

    @objc private func togglePopUpAnimation(sender: NSMenuItem) {
        preferences.usesPopUpAnimation.toggle()
        sender.state = preferences.usesPopUpAnimation ? .on : .off
    }

    @objc private func toggleExternalAddress(sender: NSMenuItem) {
        preferences.showsExternalAddress.toggle()
        sender.state = preferences.showsExternalAddress ? .on : .off
    }

    @objc private func toggleRotation(sender: NSMenuItem) {
        preferences.invertsRotation.toggle()
        sender.state = preferences.invertsRotation ? .on : .off
    }

    @objc private func changeAdjustmentSteps(sender: NSMenuItem) {
        selectExclusively(sender)
        preferences.adjustmentSteps = Int(sender.title) ?? preferences.adjustmentSteps
    }

    @objc private func changeUpdateInterval(sender: NSMenuItem) {
        selectExclusively(sender)

        let value = sender.title
            .replacingOccurrences(of: localizedString("Second"), with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        preferences.updateInterval = Double(value) ?? preferences.updateInterval

        delegate?.appMenuDidChangeUpdateInterval(self)
    }

    @objc private func changeSpinner(sender: NSMenuItem) {
        selectExclusively(sender)
        preferences.spinnerName = SpinnerCatalog.style(validating: sender.title).name
        refreshSpinnerState()
        delegate?.appMenuDidChangeSpinnerAppearance(self)
    }

    @objc private func changeEffect(sender: NSMenuItem) {
        selectExclusively(sender)
        if let effect = SpinnerEffect.allCases.first(where: { $0.title == sender.title }) {
            preferences.spinnerEffect = effect.rawValue
        }
        delegate?.appMenuDidChangeSpinnerAppearance(self)
    }

    @objc private func refreshDisplays() {
        delegate?.appMenuDidRequestDisplayRefresh(self)
    }

    @objc private func checkNewVersion() {
        UpdateChecker.shared.check(force: true)
    }

    @objc private func quit() {
        delegate?.appMenuDidRequestQuit(self)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "System Spinner"
        alert.informativeText = localizedString("""
                                                System Spinner provides macOS system information in status bar.
                                                Minimal, small and light.

                                                Author: @Andrey.Lysikov
                                                Version: \(UpdateChecker.shared.installedVersion)
                                                """)
        alert.alertStyle = .informational
        alert.addButton(withTitle: localizedString("Goto site"))
        alert.addButton(withTitle: localizedString("Close"))

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(UpdateChecker.repositoryURL)
        } else {
            alert.window.close()
        }
    }
}
