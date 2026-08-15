//  Copyright © AndreyLysikov
//  SPDX-License-Identifier: Apache-2.0

import ServiceManagement

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
