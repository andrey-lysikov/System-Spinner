//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Cocoa

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let animator = SpinnerAnimator()
    private let menuController = AppMenuController()
    private let metrics = MetricsService.shared
    private let preferences = Preferences.shared

    private var metricsObserver: UUID?
    private var clickMonitor: Any?

    func start() {
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        }

        popover.contentViewController = UsageViewController.freshController()

        animator.onFrame = { [weak self] image in
            self?.statusItem.button?.image = image
        }

        menuController.delegate = self
        menuController.rebuild()

        DisplayCoordinator.shared.onDisplaysChanged = { [weak self] displays in
            self?.menuController.updateDisplays(displays)
        }
        DisplayCoordinator.shared.start()

        observeWorkspace()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }

        reloadSpinner()
        resume()
    }

    func stop() {
        pause()
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = nil
    }
    
    @objc private func resume() {
        if metricsObserver == nil {
            metricsObserver = metrics.addObserver { [weak self] snapshot in
                self?.apply(snapshot)
            }
        }
        metrics.start(interval: preferences.updateInterval)
        DisplayCoordinator.shared.setNeedsRefresh()
    }

    @objc private func pause() {
        closePopover()
        animator.stop()
        metrics.stop()
    }

    private func apply(_ snapshot: MetricsSnapshot) {
        if preferences.showsCPUInMenuBar {
            statusItem.button?.title = String(format: "%2d%%", Int(snapshot.cpuUsage))
        } else if statusItem.button?.title != "" {
            statusItem.button?.title = ""
        }

        animator.updateSpeed(cpuUsage: snapshot.cpuUsage)
    }

    private func reloadSpinner() {
        let style = SpinnerCatalog.style(validating: preferences.spinnerName)
        let effect = SpinnerEffect(rawValue: preferences.spinnerEffect) ?? .original
        animator.load(style: style, effect: effect)
        animator.updateSpeed(cpuUsage: metrics.snapshot.cpuUsage)
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .leftMouseUp {
            if popover.isShown {
                closePopover()
            } else {
                statusItem.menu = nil
                showPopover()
            }
        } else {
            statusItem.menu = menuController.menu
            statusItem.button?.performClick(nil)
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.animates = preferences.usesPopUpAnimation
        button.window?.layoutIfNeeded()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closePopover() {
        statusItem.menu = nil
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(resume), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(resume), name: NSWorkspace.screensDidWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(pause), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(pause), name: NSWorkspace.screensDidSleepNotification, object: nil)
    }
}

extension StatusItemController: AppMenuControllerDelegate {
    func appMenuDidChangeSpinnerAppearance(_ controller: AppMenuController) {
        reloadSpinner()
    }

    func appMenuDidChangeUpdateInterval(_ controller: AppMenuController) {
        metrics.start(interval: preferences.updateInterval)
    }

    func appMenuDidRequestDisplayRefresh(_ controller: AppMenuController) {
        DisplayCoordinator.shared.setNeedsRefresh()
    }

    func appMenuDidRequestQuit(_ controller: AppMenuController) {
        NSApp.terminate(nil)
    }
}
