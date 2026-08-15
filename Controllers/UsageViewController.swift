//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Cocoa
import SwiftUI

class UsageViewController: NSViewController {
    private let metrics = MetricsService.shared
    private var metricsObserver: UUID?

    private let popupChart = NSPopover()
    private let dataModel = ChartDataModel()
    private var lastClickButton: NSButton? = nil
    private var powerHistory: String = ""
    private var fanHistory: String = ""
    private var lastPopupUpdate: Date = .distantPast
    private var forcesFullRefresh = false

    private static let popupUpdateInterval: TimeInterval = 2
    private static let chartPointLimit = 500

    @IBOutlet var fanStack: NSStackView!
    @IBOutlet var cpuTempStack: NSStackView!
    @IBOutlet var cpuLabel: NSTextField!
    @IBOutlet var gpuLabel: NSTextField!
    @IBOutlet var cpuTempLabel: NSTextField!
    @IBOutlet var fanLabel: NSTextField!
    @IBOutlet var memSwapLabel: NSTextField!

    @IBOutlet var memPercentage: NSTextField!
    @IBOutlet var memPressure: NSTextField!
    @IBOutlet var memApp: NSTextField!
    @IBOutlet var memInactive: NSTextField!
    @IBOutlet var memComp: NSTextField!
    @IBOutlet var powerComp: NSTextField!

    @IBOutlet var cpuLevel: SegmentedLevelView!
    @IBOutlet var gpuLevel: SegmentedLevelView!
    @IBOutlet var tempLevel: SegmentedLevelView!
    @IBOutlet var memLevel: SegmentedLevelView!
    @IBOutlet var pressureLevel: SegmentedLevelView!
    @IBOutlet var memSwapLevel: SegmentedLevelView!

    @IBOutlet var memAppBar: NSProgressIndicator!
    @IBOutlet var memInactiveBar: NSProgressIndicator!
    @IBOutlet var memCompBar: NSProgressIndicator!

    @IBOutlet var netLabel: NSTextField!

    @IBOutlet var cpuChartPopupButton: NSButton!
    @IBOutlet var memChartPopupButton: NSButton!

    @IBAction func cpuPopupButtonAction(_ sender: NSButton) {
        showChart(from: sender)
    }

    @IBAction func memPopupButtonAction(_ sender: NSButton) {
        showChart(from: sender)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = NSMakeSize(self.view.frame.width, 100)

        if !metrics.hasFans {
            fanStack.removeFromSuperview()
        }

        if !metrics.sensorsAvailable {
            cpuTempStack.removeFromSuperview()
        }

        let hostingController = NSHostingController(rootView: ChartContentView(chartItems: dataModel))
        hostingController.preferredContentSize = NSSize(width: 420, height: 400)
        popupChart.contentViewController = hostingController
        popupChart.behavior = .transient
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        metrics.setDetailedMetricsEnabled(true)
        metricsObserver = metrics.addObserver { [weak self] snapshot in
            self?.apply(snapshot)
        }
        forcesFullRefresh = true
        apply(metrics.snapshot)
        for level in [cpuLevel, gpuLevel, tempLevel, memLevel, pressureLevel, memSwapLevel] {
            level?.needsDisplay = true
        }

        popupChart.animates = Preferences.shared.usesPopUpAnimation
        view.window?.makeKey()
    }

    override func viewWillDisappear() {
        if let metricsObserver {
            metrics.removeObserver(metricsObserver)
        }
        metricsObserver = nil
        metrics.setDetailedMetricsEnabled(false)
        super.viewWillDisappear()
    }

    private func apply(_ snapshot: MetricsSnapshot) {
        if forcesFullRefresh || round(cpuLevel.value) != round(snapshot.cpuUsage) {
            cpuLabel.stringValue = localizedString("CPU Usage") + " " + Int(snapshot.cpuUsage).formatted(.percent)
            cpuLevel.value = snapshot.cpuUsage
        }

        if forcesFullRefresh || round(gpuLevel.value) != round(snapshot.gpuUsage) {
            gpuLabel.stringValue = localizedString("GPU Usage") + " " + Int(snapshot.gpuUsage).formatted(.percent)
            gpuLevel.value = snapshot.gpuUsage
        }

        applySensors(snapshot.sensors)
        applyMemory(snapshot.memory)

        let address = snapshot.network.address.isEmpty
            ? localizedString("no ip found")
            : snapshot.network.address

        let network = address
            + "\n↓ " + String(Int(snapshot.network.inbound.value)) + snapshot.network.inbound.unit.title
            + " | ↑ " + String(Int(snapshot.network.outbound.value)) + snapshot.network.outbound.unit.title

        if forcesFullRefresh || netLabel.stringValue != network {
            netLabel.stringValue = network
        }

        if popupChart.isShown, Date().timeIntervalSince(lastPopupUpdate) >= Self.popupUpdateInterval {
            updatePopupData()
        }

        forcesFullRefresh = false
    }

    private func applySensors(_ sensors: SensorsSnapshot) {
        let power: String
        if sensors.adapterPower > 0 && sensors.batteryPower > 0 {
            power = "PWR: \(sensors.systemPower)w, BAT: \(sensors.batteryPower)w, DC: \(sensors.adapterPower)w"
        } else if sensors.adapterPower > 0 {
            power = "PWR: \(sensors.systemPower)w, DC: \(sensors.adapterPower)w"
        } else {
            power = "PWR: \(sensors.systemPower)w, BAT: \(sensors.batteryPower)w"
        }

        if forcesFullRefresh || powerHistory != power {
            powerComp.stringValue = power
            powerHistory = power
        }

        if metrics.hasFans, !sensors.fanSpeeds.isEmpty {
            let fans = sensors.fanSpeeds.first == 0
                ? localizedString("fan is stopped")
                : "fan " + sensors.fanSpeeds.map(String.init).joined(separator: " | ") + " rpm"

            if forcesFullRefresh || fanHistory != fans {
                fanLabel.stringValue = fans
                fanHistory = fans
            }
        }

        if metrics.sensorsAvailable, forcesFullRefresh || round(tempLevel.value) != round(sensors.cpuTemperature) {
            cpuTempLabel.stringValue = localizedString("CPU Temp") + " " + String(Int(sensors.cpuTemperature)) + "°С"
            tempLevel.value = sensors.cpuTemperature
        }
    }

    private func applyMemory(_ memory: MemoryUsage) {
        if forcesFullRefresh || round(memLevel.value) != round(memory.used) {
            memPercentage.stringValue = localizedString("MEM Usage") + " " + Int(memory.used).formatted(.percent)
            memLevel.value = memory.used
        }

        if forcesFullRefresh || round(pressureLevel.value) != round(memory.pressure) {
            memPressure.stringValue = localizedString("Pressure") + " " + Int(memory.pressure).formatted(.percent)
            pressureLevel.value = memory.pressure

            memApp.stringValue = String(Int(memory.app.rounded())) + "% (App)"
            memAppBar.doubleValue = memory.app

            memInactive.stringValue = String(Int(memory.inactive.rounded())) + "% (NAct)"
            memInactiveBar.doubleValue = memory.inactive

            memComp.stringValue = String(Int(memory.compressed.rounded())) + "% (Comp)"
            memCompBar.doubleValue = memory.compressed
        }

        if forcesFullRefresh || round(memSwapLevel.value) != Double(memory.swap) {
            memSwapLabel.stringValue = localizedString("Swap") + " " + memory.swap.formatted(.percent)
            memSwapLevel.value = Double(memory.swap)
        }
    }

    private static func chartPoints(from history: [Double]) -> [ChartPoint] {
        guard history.count > chartPointLimit else {
            return history.enumerated().map { ChartPoint(time: $0.offset, usage: $0.element) }
        }

        let bucket = Int((Double(history.count) / Double(chartPointLimit)).rounded(.up))
        return stride(from: 0, to: history.count, by: bucket).enumerated().map { index, start in
            let end = min(start + bucket, history.count)
            return ChartPoint(time: index, usage: history[start ..< end].max() ?? 0)
        }
    }

    private func showChart(from sender: NSButton) {
        if popupChart.isShown {
            popupChart.performClose(sender)
        }
        lastClickButton = sender
        updatePopupData()
        popupChart.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    private func updatePopupData() {
        let snapshot = metrics.snapshot
        let showsCPU = lastClickButton == cpuChartPopupButton

        guard showsCPU || lastClickButton == memChartPopupButton else { return }

        lastPopupUpdate = Date()

        let history = showsCPU ? snapshot.cpuHistory : snapshot.memoryHistory
        dataModel.title = localizedString(showsCPU ? "CPU usage details:" : "Memory usage details:")
        dataModel.chartPoints = Self.chartPoints(from: history)

        metrics.topProcesses { [weak self] processes in
            guard let self else { return }

            let rows = showsCPU
                ? processes.filter { $0.cpu > 0 }
                    .sorted { $0.cpu > $1.cpu }
                    .map { ProcessRow(pid: $0.pid, icon: $0.icon, name: $0.name, usage: String($0.cpu) + "%") }
                : processes.filter { $0.memory > 0.1 }
                    .sorted { $0.memory > $1.memory }
                    .map { ProcessRow(pid: $0.pid, icon: $0.icon, name: $0.name, usage: $0.memoryText) }

            self.dataModel.tablePoints = rows
        }
    }
}

extension UsageViewController {
    static func freshController() -> UsageViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("UsageViewController")
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? UsageViewController else {
            fatalError("Why cant i find UsageViewController? - Check Main.storyboard")
        }
        return viewcontroller
    }
}
