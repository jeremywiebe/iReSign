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

    var window: NSWindow

    var defaults: NSUserDefaults!

    var unzipTask: NSTask!
    var copyTask: NSTask!
    var provisioningTask: NSTask!
    var codesignTask: NSTask!
    var generateEntitlementsTask: NSTask!
    var verifyTask: NSTask!
    var zipTask: NSTask!
    var sourcePath: String!
    var appPath: String!
    var workingPath: String!
    var appName: String!
    var fileName: String!

    var entitlementsResult: String!
    var codesigningResult: String!
    var verificationResult: String!

    @IBOutlet var pathField: IRTextFieldDrag!
    @IBOutlet var provisioningPathField: IRTextFieldDrag!
    @IBOutlet var entitlementField: IRTextFieldDrag!
    @IBOutlet var bundleIDField: IRTextFieldDrag!
    @IBOutlet var browseButton: NSButton!
    @IBOutlet var provisioningBrowseButton: NSButton!
    @IBOutlet var entitlementBrowseButton: NSButton!
    @IBOutlet var resignButton: NSButton!
    @IBOutlet var statusLabel: NSTextField!
    @IBOutlet var flurry: NSProgressIndicator!
    @IBOutlet var changeBundleIDCheckbox: NSButton!

    @IBOutlet var certComboBox: NSComboBox!
    var certComboBoxItems: NSMutableArray!
    var certTask: NSTask!
    var getCertsResult: NSArray!




    // If the application dock icon is clicked, reopen the window
    func applicationShouldHandleReopen(sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Make sure the window is visible
        if window.visible {
            // Window isn't shown, show it
            window.makeKeyAndOrderFront(self)
        }

        return true
    }

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