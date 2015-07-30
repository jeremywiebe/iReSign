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
    var certComboBoxItems = [String]()
    var certTask: NSTask!
    var getCertsResult: NSArray!

    func numberOfItemsInComboBox(comboBox: NSComboBox) -> Int {
        var count = 0
        if comboBox == certComboBox {
            count = certComboBoxItems.count
        }

        return count
    }

    func comboBox(comboBox: NSComboBox, objectValueForItemAtIndex index: Int) -> String? {
        var item: String?
        if (comboBox == certComboBox) {
            item = certComboBoxItems[index]
        }

        return item
    }

    func getCerts() {
        getCertsResult = nil

        NSLog("Getting Certificate IDs")
        statusLabel.stringValue = "Getting Signing Certificate IDs"

        certTask = NSTask()
        certTask.launchPath = "/usr/bin/security"
        certTask.arguments = ["find-identity", "-v", "-p", "codesigning"]

        NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "checkCerts:", userInfo: nil, repeats: true)

        var pipe = NSPipe()
        certTask.standardOutput = pipe
        certTask.standardError = pipe

        var handle = pipe.fileHandleForReading

        certTask.launch()

        NSThread.detachNewThreadSelector("watchGetCerts:", toTarget: self, withObject: handle)
    }

    func watchGetCerts(streamHandle: NSFileHandle) {
        var securityResult = NSString(data: streamHandle.readDataToEndOfFile(), encoding: NSASCIIStringEncoding)

        // Verify the security result
        if (securityResult == nil || securityResult!.length < 1) {
            // Nothing in the result, return
            return
        }

        var rawResult = securityResult?.componentsSeparatedByString("\"") as! [String]
        var tempGetCertsResult = [String]()

        for (var i = 0; i <= rawResult.count - 2; i += 2) {
            NSLog("i:\(i+1)")

            if (rawResult.count - 1 < i + 1) {
                // Invalid array, don't add an object to that position
            } else {
                // Valid object
                tempGetCertsResult.append(rawResult[i+1])
            }
        }
        
        certComboBoxItems = tempGetCertsResult
        certComboBox.reloadData()
    }

    func checkCerts(timer: NSTimer) {
        if !certTask.running {
            timer.invalidate()
            certTask = nil

            if  certComboBoxItems.count > 0 {
                NSLog("Get Certs done")
                statusLabel.stringValue = "Signing Certificate IDs extracted"

                if let certIndex = defaults.stringForKey("CERT_INDEX")?.toInt() {
                    if (certIndex != -1) {
                        var selectedItem = self.comboBox(certComboBox, objectValueForItemAtIndex:certIndex)
                        certComboBox.objectValue = selectedItem
                        certComboBox.selectItemAtIndex(certIndex)
                    }

                    enableControls()
                }
            } else {
                showAlertOfKind(NSAlertStyle.CriticalAlertStyle, title: "Error", message: "Getting Certificate ID's failed")
                enableControls()
                statusLabel.stringValue = "Ready"
            }
        }
    }

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