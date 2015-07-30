//
//  AppDelegate.swift
//  iReSign
//
//  Created by Jeremy Wiebe on 2015-07-30.
//  Copyright (c) 2015 nil. All rights reserved.
//

import Foundation
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {




    // MARK: - Alert Methods

    /* NSRunAlerts are being deprecated in 10.9 */

    // Show a critical alert
    func showAlertOfKind(style: NSAlertStyle, title: String, message: String) {
        var alert = NSAlert()
        alert.addButtonWithTitle("OK")
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style

        alert.runModal()
    }
}