//
//  AppDelegate.swift
//  iReSign
//
//  Created by Jeremy Wiebe on 2015-07-30.
//  Copyright (c) 2015 nil. All rights reserved.
//

import Foundation
import Cocoa

var kKeyPrefsBundleIDChange            = "keyBundleIDChange"

var kKeyBundleIDPlistApp               = "CFBundleIdentifier"
var kKeyBundleIDPlistiTunesArtwork     = "softwareVersionBundleId"
var kKeyInfoPlistApplicationProperties = "ApplicationProperties"
var kKeyInfoPlistApplicationPath       = "ApplicationPath"
var kPayloadDirName                    = "Payload"
var kProductsDirName                   = "Products"
var kInfoPlistFilename                 = "Info.plist"
var kiTunesMetadataFileName            = "iTunesMetadata"

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

    override init() {
    }

    func doProvisioning() {
        var dirContents = NSFileManager.defaultManager().contentsOfDirectoryAtPath(workingPath.stringByAppendingPathComponent(kPayloadDirName), error: nil) as! [String]

        for file in dirContents {
            if file.pathExtension.lowercaseString == "app" {
                appPath = workingPath.stringByAppendingPathComponent(kPayloadDirName).stringByAppendingPathComponent(file)
                if NSFileManager.defaultManager().fileExistsAtPath(appPath.stringByAppendingPathComponent("embedded.mobileprovision")) {
                    NSLog("Found embedded.mobileprovision, deleting.")
                    NSFileManager.defaultManager().removeItemAtPath(appPath.stringByAppendingPathComponent("embedded.mobileprovision"), error:nil)
                }
                break
            }
        }

        var targetPath = appPath.stringByAppendingPathComponent("embedded.mobileprovision")

        provisioningTask = NSTask()
        provisioningTask.launchPath = "/bin/cp"
        provisioningTask.arguments = [provisioningPathField.stringValue, targetPath]

        provisioningTask.launch()

        NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "checkProvisioning:", userInfo: nil, repeats: true)
    }

    func checkProvisioning(timer: NSTimer) {
        if !provisioningTask.running {
            timer.invalidate()
            provisioningTask = nil

            var dirContents = NSFileManager.defaultManager().contentsOfDirectoryAtPath(workingPath.stringByAppendingPathComponent(kPayloadDirName), error: nil) as! [String]

            for file in dirContents {
                if file.pathExtension.lowercaseString == "app" {
                    appPath = workingPath.stringByAppendingPathComponent(kPayloadDirName).stringByAppendingPathComponent(file)
                    if NSFileManager.defaultManager().fileExistsAtPath(appPath.stringByAppendingPathComponent("embedded.mobileprovision")) {
                        var identifierOK = false
                        var identifierInProvisioning = ""

                        var embeddedProvisioning = NSString(contentsOfFile: appPath.stringByAppendingPathComponent("embedded.mobileprovision"), encoding:NSASCIIStringEncoding, error:nil)!
                        var embeddedProvisioningLines = embeddedProvisioning.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())

                        for var i = 0; i <= embeddedProvisioningLines.count; i++ {
                            if embeddedProvisioningLines[i].rangeOfString("application-identifier").location != NSNotFound {

                                var fromPosition = embeddedProvisioningLines[i+1].rangeOfString("<string>").location + 8;
                                var toPosition = embeddedProvisioningLines[i+1].rangeOfString("</string>").location;

                                var range = NSRange()
                                range.location = fromPosition
                                range.length = toPosition - fromPosition

                                var fullIdentifier = embeddedProvisioningLines[i+1].substringWithRange(range)

                                var identifierComponents = fullIdentifier.componentsSeparatedByString(".")

                                if identifierComponents.last == "*" {
                                    identifierOK = true
                                }

                                for var i = 1; i < identifierComponents.count; i++ {
                                    identifierInProvisioning = identifierInProvisioning.stringByAppendingString(identifierComponents[i])
                                    if i < identifierComponents.count - 1 {
                                        identifierInProvisioning = identifierInProvisioning.stringByAppendingString(".")
                                    }
                                }
                                break
                            }
                        }
                        
                        NSLog("Mobileprovision identifier: \(identifierInProvisioning)")
                        
                        var infoPlist = NSString(contentsOfFile:appPath.stringByAppendingPathComponent("Info.plist"), encoding:NSASCIIStringEncoding, error:nil)!
                        if infoPlist.rangeOfString(identifierInProvisioning).location != NSNotFound {
                            NSLog("Identifiers match")
                            identifierOK = true
                        }

                        if identifierOK {
                            NSLog("Provisioning completed.")
                            statusLabel.stringValue = "Provisioning completed"
                            doEntitlementsFixing()
                        } else {
                            showAlertOfKind(NSAlertStyle.CriticalAlertStyle, title: "Error", message: "Product identifiers don't match")
                            enableControls()
                            statusLabel.stringValue = "Ready"
                        }
                    } else {
                        showAlertOfKind(NSAlertStyle.CriticalAlertStyle, title: "Error", message: "Provisioning failed")
                        enableControls()
                        statusLabel.stringValue = "Ready"
                    }
                    break
                }
            }
        }
    }

    func doEntitlementsFixing()
    {
        if entitlementField.stringValue == "" || provisioningPathField.stringValue == "" {
            doCodeSigning()
            return // Using a pre-made entitlements file or we're not re-provisioning.
        }

        statusLabel.stringValue = "Generating entitlements"

        if let appPath = appPath {
            generateEntitlementsTask = NSTask()
            generateEntitlementsTask.launchPath = "/usr/bin/security"
            generateEntitlementsTask.arguments = ["cms", "-D", "-i", provisioningPathField.stringValue]
            generateEntitlementsTask.currentDirectoryPath = workingPath

            NSTimer.scheduledTimerWithTimeInterval(1.0, target:self, selector:"checkEntitlementsFix:", userInfo:nil, repeats:true)

            var pipe = NSPipe()
            generateEntitlementsTask.standardOutput = pipe
            generateEntitlementsTask.standardError = pipe
            let handle = pipe.fileHandleForReading

            generateEntitlementsTask.launch()

            NSThread.detachNewThreadSelector("watchEntitlements:", toTarget:self, withObject:handle)
        }
    }

    func watchEntitlements(streamHandle: NSFileHandle) {
        entitlementsResult = String(NSString(data: streamHandle.readDataToEndOfFile(), encoding:NSASCIIStringEncoding))
    }

    func checkEntitlementsFix(timer: NSTimer) {
        if !generateEntitlementsTask.running {
            timer.invalidate()
            generateEntitlementsTask = nil
            NSLog("Entitlements fixed done")
            statusLabel.stringValue = "Entitlements generated"
            doEntitlementsEdit()
        }
    }

    func doEntitlementsEdit()
    {
        if let entitlements = entitlementsResult.propertyList() as? NSDictionary {
            if let entitlementElement = entitlements["Entitlements"] as? NSDictionary {
                var filePath = workingPath.stringByAppendingPathComponent("entitlements.plist")
                var xmlData = NSPropertyListSerialization.dataWithPropertyList(entitlements, format: NSPropertyListFormat.XMLFormat_v1_0, options: 0, error: nil)!
                if xmlData.writeToFile(filePath, atomically: true) {
                    NSLog("Error writing entitlements file.")
                    showAlertOfKind(NSAlertStyle.CriticalAlertStyle, title: "Error", message: "Failed entitlements generation")
                    enabledControls()
                    statusLabel.stringValue = "Ready"
                } else {
                    entitlementField.stringValue = filePath;
                    doCodeSigning()
                }
            }
        }
    }

    func doCodeSigning() {
        appPath = nil

        var dirContents = NSFileManager.defaultManager().contentsOfDirectoryAtPath(workingPath.stringByAppendingPathComponent(kPayloadDirName), error: nil) as! [String]

        for file in dirContents {
            if file.pathExtension.lowercaseString == "app" {
                appPath = workingPath.stringByAppendingPathComponent(kPayloadDirName).stringByAppendingPathComponent(file)
                NSLog("Found \(appPath)")
                appName = file
                statusLabel.stringValue = "Codesigning \(file)"
                break
            }
        }

        if let appPath = appPath {
            var arguments = ["-fs", certComboBox.objectValue!]
            var systemVersionDictionary = NSDictionary(contentsOfFile: "/System/Library/CoreServices/SystemVersion.plist")
            var systemVersion = systemVersionDictionary?.objectForKey("ProductVersion") as? String
            if let version = systemVersion?.componentsSeparatedByString(".") {
                if (version[0].toInt()<10 || (version[0].toInt()==10 && (version[1].toInt()<9 || (version[1].toInt()==9 && version[2].toInt()<5)))) {

                    /*
                    Before OSX 10.9, code signing requires a version 1 signature.
                    The resource envelope is necessary.
                    To ensure it is added, append the resource flag to the arguments.
                    */

                    var resourceRulesPath = NSBundle.mainBundle().pathForResource("ResourceRules", ofType:"plist")
                    var resourceRulesArgument = "--resource-rules=\(resourceRulesPath)"
                    arguments.append(resourceRulesArgument)
                } else {

                    /*
                    For OSX 10.9 and later, code signing requires a version 2 signature.
                    The resource envelope is obsolete.
                    To ensure it is ignored, remove the resource key from the Info.plist file.
                    */

                    var infoPath = "\(appPath)/Info.plist"
                    var infoDict = NSMutableDictionary(contentsOfFile: infoPath)
                    infoDict?.removeObjectForKey("CFBundleResourceSpecification")
                    infoDict?.writeToFile(infoPath, atomically: true)
                    arguments.append("--no-strict") // http://stackoverflow.com/a/26204757
                }
            }

            if entitlementField.stringValue == "" {
                arguments.append("--entitlements=\(entitlementField.stringValue)")
            }

            arguments.append(appPath)

            codesignTask = NSTask()
            codesignTask.launchPath = "/usr/bin/codesign"
            codesignTask.arguments = arguments

            NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "checkCodesigning:", userInfo: nil, repeats: true)

            var pipe = NSPipe()
            codesignTask.standardOutput = pipe
            codesignTask.standardError = pipe
            var handle = pipe.fileHandleForReading

            codesignTask.launch()

            NSThread.detachNewThreadSelector("watchCodesigning:", toTarget: self, withObject: handle)
        }
    }

    func watchCodesigning(streamHandle: NSFileHandle) {
        codesigningResult = String(NSString(data: streamHandle.readDataToEndOfFile(), encoding:NSASCIIStringEncoding)!)
    }

    func checkCodesigning(timer: NSTimer) {
        if !codesignTask.running {
            timer.invalidate()
            codesignTask = nil
            NSLog("Codesigning done")
            statusLabel.stringValue = "Codesigning completed"
            doVerifySignature()
        }
    }

    func doVerifySignature() {
        if let appPath = appPath {
            verifyTask = NSTask()
            verifyTask.launchPath = "/usr/bin/codesign"
            verifyTask.arguments = ["-v", appPath]

            NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "checkVerificationProcess:", userInfo: nil, repeats: true)

            NSLog("Verifying %@",appPath)
            statusLabel.stringValue = "Verifying \(appName)"

            var pipe = NSPipe()
            verifyTask.standardOutput = pipe
            verifyTask.standardError = pipe
            var handle = pipe.fileHandleForReading

            verifyTask.launch()

            NSThread.detachNewThreadSelector("watchVerificationProcess:", toTarget: self, withObject: handle)
        }
    }

    func watchVerificationProcess(streamHandle: NSFileHandle) {
        verificationResult = String(NSString(data: streamHandle.readDataToEndOfFile(), encoding:NSASCIIStringEncoding)!)
    }

    func checkVerificationProcess(timer: NSTimer) {
        if !verifyTask.running {
            timer.invalidate()
            verifyTask = nil
            if count(verificationResult) == 0 {
                NSLog("Verification done")
                statusLabel.stringValue = "Verification completed"
                doZip()
            } else {
                var error = codesigningResult + "\n\n" + verificationResult
                showAlertOfKind(NSAlertStyle.CriticalAlertStyle, title: "Signing failed", message: error)
                enableControls()
                statusLabel.stringValue = "Please try again"
            }
        }
    }

    func doZip() {
        if let appPath = appPath {
            let destinationPathComponents = sourcePath.pathComponents
            var destinationPath = ""

            for var i=0; i<destinationPathComponents.count-1; i++ {
                destinationPath = destinationPath.stringByAppendingPathComponent(destinationPathComponents[i])
            }

            fileName = sourcePath.lastPathComponent
            fileName = fileName.substringToIndex(advance(fileName.endIndex, -(count(sourcePath.pathExtension) + 1)))
            fileName = fileName.stringByAppendingString("-resigned")
            fileName = fileName.stringByAppendingPathExtension("ipa")

            destinationPath = destinationPath.stringByAppendingPathComponent(fileName)

            NSLog("Dest: \(destinationPath)")

            zipTask = NSTask()
            zipTask.launchPath = "/usr/bin/zip"
            zipTask.currentDirectoryPath = workingPath
            zipTask.arguments = ["-qry", destinationPath, "."]

            NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "checkZip:", userInfo: nil, repeats: true)

            NSLog("Zipping \(destinationPath)")
            statusLabel.stringValue = "Saving \(fileName)"

            zipTask.launch()
        }
    }

    func checkZip(timer: NSTimer) {
        if !zipTask.running {
            timer.invalidate()
            zipTask = nil

            NSLog("Zipping done")
            statusLabel.stringValue = "Saved \(fileName)"

            NSFileManager.defaultManager().removeItemAtPath(workingPath, error: nil)

            enableControls()

            var result = codesigningResult + "\n\n" + verificationResult
            NSLog("Codesigning result: \(result)")
        }
    }

    @IBAction func browse(sender: AnyObject) {
        var panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false
        panel.allowedFileTypes = ["ipa", "IPA", "xcarchive"]

        if panel.runModal() == NSOKButton {
            if let fileNameOpened = (panel.URLs as! [NSURL])[0].path {
                pathField.stringValue = fileNameOpened
            }
        }
    }

    @IBAction func provisioningBrowse(sender: AnyObject)  {
        var panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false
        panel.allowedFileTypes = ["mobileprovision", "MOBILEPROVISION"]

        if panel.runModal() == NSOKButton {
            if let fileNameOpened = (panel.URLs as! [NSURL])[0].path {
                provisioningPathField.stringValue = fileNameOpened
            }
        }
    }

    @IBAction func entitlementBrowse(sender: AnyObject)  {
        var panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false
        panel.allowedFileTypes = ["plist", "PLIST"]

        if panel.runModal() == NSOKButton {
            if let fileNameOpened = (panel.URLs as! [NSURL])[0].path {
                entitlementField.stringValue = fileNameOpened
            }
        }
    }

    @IBAction func changeBundleIDPressed(sender: NSButton) {
        if sender != changeBundleIDCheckbox {
            return
        }
        bundleIDField.enabled = changeBundleIDCheckbox.state == NSOnState
    }

    func disableControls() {
        pathField.enabled = false
        entitlementField.enabled = false
        browseButton.enabled = false
        resignButton.enabled = false
        provisioningBrowseButton.enabled = false
        provisioningPathField.enabled = false
        changeBundleIDCheckbox.enabled = false
        bundleIDField.enabled = false
        certComboBox.enabled = false

        flurry.startAnimation(self)
        flurry.alphaValue = 1.0
    }

    func enableControls() {
        pathField.enabled = true
        entitlementField.enabled = true
        browseButton.enabled = true
        resignButton.enabled = true
        provisioningBrowseButton.enabled = true
        provisioningPathField.enabled = true
        changeBundleIDCheckbox.enabled = true
        bundleIDField.enabled = changeBundleIDCheckbox.state == NSOnState
        certComboBox.enabled = true

        flurry.stopAnimation(self)
        flurry.alphaValue = 0.5
    }

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