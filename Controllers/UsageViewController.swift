//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import Cocoa
import SwiftUI
import Charts

struct chartData: Identifiable {
    let id = UUID()
    let time: Int
    let usage: Double
}

struct tableData: Identifiable {
    let id = UUID()
    let name: String
    let usage: String
}

@Observable class chartDataManager {
    var chartPoints: [chartData] = []
    var tablePoints: [tableData] = []
    var title: String = ""
}

struct ChartContentView: View {
    var chartItems: chartDataManager
    var body: some View {
            VStack(alignment: .leading) {
                Text(chartItems.title)
                    .font(.headline)
                    .fontWeight(.heavy)
                Chart(chartItems.chartPoints) { item in
                    AreaMark(
                        x: .value("Name", item.time),
                        y: .value("Usage", item.usage)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .blue.opacity(1),
                                .blue.opacity(0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 100)
                .chartYScale(domain: 0...100)
                .chartXScale(domain: 0...359)
                .chartXAxis { AxisMarks() { _ in
                    AxisGridLine()
                    AxisTick()
                }}
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 0) {
                    GridRow {
                        Text(localizedString("Name"))
                            .bold()
                        Spacer()
                        Text(localizedString("Usage"))
                            .bold()
                    }
                }
                ScrollView(.vertical, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: 5, verticalSpacing: 1) {
                        ForEach(chartItems.tablePoints) { item in
                            Divider()
                            GridRow {
                                Text(item.name).frame(width: 200, alignment: .leading)
                                Spacer()
                                Text(item.usage)
                            }
                            .font(.system(size: 11))
                            .padding(.vertical, 2)
                        }
                        Divider()
                    }
                }
                .frame(height: 230)
            }
            .padding()
        }
}

class UsageViewController: NSViewController, NSPopoverDelegate {
    private var dataTimer: Timer? = nil
    private var cpuProcessMenu: NSMenu!
    private var memProcessMenu: NSMenu!
    private let ioService = IOServiceData()
    private let popupChart = NSPopover()
    private let dataManager = chartDataManager()
    private var lastClickButton: NSButton? = nil
    private var chartDataItems = [chartData(time: 0, usage: 0)]
    private var tableDataItems = [tableData(name: "", usage: "")]
    
    @IBOutlet var fanStack: NSStackView!
    @IBOutlet var cpuTempStack: NSStackView!
    @IBOutlet var cpuLabel: NSTextField!
    @IBOutlet var cpuTempLabel: NSTextField!
    @IBOutlet var fanLabel: NSTextField!
    
    @IBOutlet var memPercentage: NSTextField!
    @IBOutlet var memPressure: NSTextField!
    @IBOutlet var memApp: NSTextField!
    @IBOutlet var memInactive: NSTextField!
    @IBOutlet var memComp: NSTextField!
    @IBOutlet var powerComp: NSTextField!
    
    @IBOutlet var cpuLevel: NSLevelIndicator!
    @IBOutlet var tempLevel: NSLevelIndicator!
    @IBOutlet var memLevel: NSLevelIndicator!
    @IBOutlet var pressureLevel: NSLevelIndicator!
    
    @IBOutlet var memAppBar: NSProgressIndicator!
    @IBOutlet var memInactiveBar: NSProgressIndicator!
    @IBOutlet var memCompBar: NSProgressIndicator!
    
    @IBOutlet var netLabel: NSTextField!
    
    @IBOutlet var cpuChartPopupButton: NSButton!
    @IBOutlet var memChartPopupButton: NSButton!
 
    @IBAction func cpuPopupButtonAction(_ sender: NSButton) {
        lastClickButton = sender
        updatePopupData()
        popupChart.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
    
    @IBAction func memPopupButtonAction(_ sender: NSButton) {
        lastClickButton = sender
        updatePopupData()
        popupChart.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }
    
    func popoverWillClose(_ notification: Notification) {
        guard let window = self.view.window else { return }
        window.makeKey()
        window.makeFirstResponder(self.view)
        lastClickButton = nil
    }
    
    override func viewDidLoad() {
        // Air is not present fan
        if ioService.isAir {
            fanStack.removeFromSuperview()
        }
        
        // if no SMC, remove CPU temp data
        if !ioService.presentSMC {
            cpuTempStack.removeFromSuperview()
        }
        
        // create chart data view
        let hostingController = NSHostingController(rootView: ChartContentView(chartItems: dataManager))
        let exactSize = NSSize(width: 350, height: 400)
        hostingController.preferredContentSize = exactSize
        popupChart.contentViewController = hostingController
        popupChart.behavior = .transient
        popupChart.animates = false
        popupChart.delegate = self
        
        super.viewDidLoad()
    }
    
    override func viewWillDisappear() {
        dataTimer?.invalidate()
        super.viewWillDisappear()
    }
    
    override func viewDidAppear() {
        dataTimer?.invalidate()
        dataTimer = Timer(timeInterval: updateInterval * 2, repeats: true, block: { [weak self] _ in
            self?.updateData()
        })
        RunLoop.main.add(dataTimer!, forMode: .common)
        dataTimer?.fire()
        
        super.viewDidAppear()
        view.window?.makeKey()
    }
    
    private func updateData() {
        ioService.update()
        ActivityData.update()
        
        // CPU data
        cpuLabel.stringValue = localizedString("CPU Usage") + " " + Int(ActivityData.cpuPercentage).formatted(.percent)
        cpuLevel.doubleValue = ActivityData.cpuPercentage / 5
        
        // power data
        if ioService.systemAdapter > 0 {
            powerComp.stringValue = "PWR: " + String(ioService.systemPower) + "w, DC: " + String(ioService.systemAdapter) + "w"
        } else if (ioService.systemBattery > 0 && ioService.systemAdapter > 0)  {
            powerComp.stringValue = "PWR: " + String(ioService.systemPower) + "w, BAT: " + String(ioService.systemBattery) + "w, DC: " + String(ioService.systemAdapter) + "w"
        } else {
            powerComp.stringValue = "PWR: " + String(ioService.systemPower) + "w, BAT: " + String(ioService.systemBattery) + "w"
        }
        
        // Air is not present fan
        if !ioService.isAir {
            var fanSpeed: Int = 0
            for (key, _) in ioService.fanSpeed.enumerated() {
                if key == 0 {
                    fanLabel.stringValue =  "fan " + String(ioService.fanSpeed[key])
                } else {
                    fanLabel.stringValue +=  " | " + String(ioService.fanSpeed[key])
                }
                fanSpeed += ioService.fanSpeed[key]
            }
            fanLabel.stringValue += " rpm"
            if fanSpeed == 0 {
                fanLabel.stringValue =  localizedString("fan is stoped")
            }
        }
        
        // if presentSMC
        if ioService.presentSMC {
            // temp data
            cpuTempLabel.stringValue = localizedString("CPU Temp") + " " + String(round(ioService.cpuTemp)) + "°С"
            tempLevel.doubleValue = ioService.cpuTemp / 5
        }
        
        // memory data
        memPercentage.stringValue =  localizedString("Memory Usage") + " " + Int(ActivityData.memPercentage).formatted(.percent)
        memLevel.doubleValue = ActivityData.memPercentage / 5
        
        memPressure.stringValue = localizedString("Pressure") + " " + Int(ActivityData.memPressure).formatted(.percent)
        pressureLevel.doubleValue = ActivityData.memPressure / 5
        
        memApp.stringValue = String(Int(round(ActivityData.memApp))) + "% (App)"
        memAppBar.doubleValue = ActivityData.memApp
        
        memInactive.stringValue = String(Int(round(ActivityData.memInactive))) + "% (NAct)"
        memInactiveBar.doubleValue = ActivityData.memInactive
        
        memComp.stringValue = String(Int(round(ActivityData.memCompressed))) + "% (Comp)"
        memCompBar.doubleValue = ActivityData.memCompressed
        
        netLabel.stringValue = ActivityData.netIp + "\n↓ " + String(Int(ActivityData.netIn.value)) + ActivityData.netIn.unit + " | ↑ " + String(Int(ActivityData.netOut.value)) + ActivityData.netOut.unit
        
        if popupChart.isShown {
            updatePopupData()
        }
    }
    
    private func updatePopupData() {
        chartDataItems.removeAll()
        tableDataItems.removeAll()
        
        if lastClickButton == cpuChartPopupButton {
            dataManager.title = localizedString("CPU usage details:")
            for (key, usage) in ActivityData.loadCpuPreviousHistDetails.enumerated() {
                chartDataItems.append(chartData(time: key, usage: usage))
            }
            dataManager.chartPoints = chartDataItems
            
            for item in ActivityData.getTopProcess().sorted(by: \.cpu) {
                if item.cpu > 0 {
                    tableDataItems.append(tableData(name: item.name, usage: String(item.cpu) + "%"))
                }
            }
            dataManager.tablePoints = tableDataItems
        } else if lastClickButton == memChartPopupButton{
            dataManager.title = localizedString("Memory usage details:")
            for (key, usage) in ActivityData.loadMemPreviousHistDetails.enumerated() {
                chartDataItems.append(chartData(time: key, usage: usage))
            }
            dataManager.chartPoints = chartDataItems
            
            for item in ActivityData.getTopProcess().sorted(by: \.mem) {
                if item.mem > 0.1 {
                    tableDataItems.append(tableData(name: item.name, usage: item.realmem))
                }
            }
            dataManager.tablePoints = tableDataItems
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
