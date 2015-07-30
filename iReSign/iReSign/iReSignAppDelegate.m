//
//  iReSignAppDelegate.m
//  iReSign
//
//  Created by Maciej Swic on 2011-05-16.
//  Copyright (c) 2011 Maciej Swic, Licensed under the MIT License.
//  See README.md for details
//

#import "iReSignAppDelegate.h"

@implementation iReSignAppDelegate

@synthesize window,workingPath;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [flurry setAlphaValue:0.5];
    
    defaults = [NSUserDefaults standardUserDefaults];
    
    // Look up available signing certificates
    [self getCerts];
    
    if ([defaults valueForKey:@"ENTITLEMENT_PATH"])
        [entitlementField setStringValue:[defaults valueForKey:@"ENTITLEMENT_PATH"]];
    if ([defaults valueForKey:@"MOBILEPROVISION_PATH"])
        [provisioningPathField setStringValue:[defaults valueForKey:@"MOBILEPROVISION_PATH"]];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/zip"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the zip utility present at /usr/bin/zip"];
        exit(0);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/unzip"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the unzip utility present at /usr/bin/unzip"];
        exit(0);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the codesign utility present at /usr/bin/codesign"];
        exit(0);
    }
}


- (IBAction)resign:(id)sender {
    //Save cert name
    [defaults setValue:[NSNumber numberWithInteger:[certComboBox indexOfSelectedItem]] forKey:@"CERT_INDEX"];
    [defaults setValue:[entitlementField stringValue] forKey:@"ENTITLEMENT_PATH"];
    [defaults setValue:[provisioningPathField stringValue] forKey:@"MOBILEPROVISION_PATH"];
    [defaults setValue:[bundleIDField stringValue] forKey:kKeyPrefsBundleIDChange];
    [defaults synchronize];
    
    codesigningResult = nil;
    verificationResult = nil;
    
    sourcePath = [pathField stringValue];
    workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.appulize.iresign"];
    
    if ([certComboBox objectValue]) {
        if (([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) ||
            ([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"xcarchive"])) {
            [self disableControls];
            
            NSLog(@"Setting up working directory in %@",workingPath);
            [statusLabel setHidden:NO];
            [statusLabel setStringValue:@"Setting up working directory"];
            
            [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
            
            [[NSFileManager defaultManager] createDirectoryAtPath:workingPath withIntermediateDirectories:TRUE attributes:nil error:nil];
            
            if ([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
                if (sourcePath && [sourcePath length] > 0) {
                    NSLog(@"Unzipping %@",sourcePath);
                    [statusLabel setStringValue:@"Extracting original app"];
                }
                
                unzipTask = [[NSTask alloc] init];
                [unzipTask setLaunchPath:@"/usr/bin/unzip"];
                [unzipTask setArguments:[NSArray arrayWithObjects:@"-q", sourcePath, @"-d", workingPath, nil]];
                
                [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkUnzip:) userInfo:nil repeats:TRUE];
                
                [unzipTask launch];
            }
            else {
                NSString* payloadPath = [workingPath stringByAppendingPathComponent:kPayloadDirName];
                
                NSLog(@"Setting up %@ path in %@", kPayloadDirName, payloadPath);
                [statusLabel setStringValue:[NSString stringWithFormat:@"Setting up %@ path", kPayloadDirName]];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:payloadPath withIntermediateDirectories:TRUE attributes:nil error:nil];
                
                NSLog(@"Retrieving %@", kInfoPlistFilename);
                [statusLabel setStringValue:[NSString stringWithFormat:@"Retrieving %@", kInfoPlistFilename]];
                
                NSString* infoPListPath = [sourcePath stringByAppendingPathComponent:kInfoPlistFilename];
                
                NSDictionary* infoPListDict = [NSDictionary dictionaryWithContentsOfFile:infoPListPath];
                
                if (infoPListDict != nil) {
                    NSString* applicationPath = nil;
                    
                    NSDictionary* applicationPropertiesDict = [infoPListDict objectForKey:kKeyInfoPlistApplicationProperties];
                    
                    if (applicationPropertiesDict != nil) {
                        applicationPath = [applicationPropertiesDict objectForKey:kKeyInfoPlistApplicationPath];
                    }
                    
                    if (applicationPath != nil) {
                        applicationPath = [[sourcePath stringByAppendingPathComponent:kProductsDirName] stringByAppendingPathComponent:applicationPath];
                        
                        NSLog(@"Copying %@ to %@ path in %@", applicationPath, kPayloadDirName, payloadPath);
                        [statusLabel setStringValue:[NSString stringWithFormat:@"Copying .xcarchive app to %@ path", kPayloadDirName]];
                        
                        copyTask = [[NSTask alloc] init];
                        [copyTask setLaunchPath:@"/bin/cp"];
                        [copyTask setArguments:[NSArray arrayWithObjects:@"-r", applicationPath, payloadPath, nil]];
                        
                        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCopy:) userInfo:nil repeats:TRUE];
                        
                        [copyTask launch];
                    }
                    else {
                        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:[NSString stringWithFormat:@"Unable to parse %@", kInfoPlistFilename]];
                        [self enableControls];
                        [statusLabel setStringValue:@"Ready"];
                    }
                }
                else {
                    [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:[NSString stringWithFormat:@"Retrieve %@ failed", kInfoPlistFilename]];
                    [self enableControls];
                    [statusLabel setStringValue:@"Ready"];
                }
            }
        }
        else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"You must choose an *.ipa or *.xcarchive file"];
            [self enableControls];
            [statusLabel setStringValue:@"Please try again"];
        }
    } else {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"You must choose an signing certificate from dropdown."];
        [self enableControls];
        [statusLabel setStringValue:@"Please try again"];
    }
}

- (void)checkUnzip:(NSTimer *)timer {
    if ([unzipTask isRunning] == 0) {
        [timer invalidate];
        unzipTask = nil;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName]]) {
            NSLog(@"Unzipping done");
            [statusLabel setStringValue:@"Original app extracted"];
            
            if (changeBundleIDCheckbox.state == NSOnState) {
                [self doBundleIDChange:bundleIDField.stringValue];
            }
            
            if ([[provisioningPathField stringValue] isEqualTo:@""]) {
                [self doCodeSigning];
            } else {
                [self doProvisioning];
            }
        } else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Unzip failed"];
            [self enableControls];
            [statusLabel setStringValue:@"Ready"];
        }
    }
}

- (void)checkCopy:(NSTimer *)timer {
    if ([copyTask isRunning] == 0) {
        [timer invalidate];
        copyTask = nil;
        
        NSLog(@"Copy done");
        [statusLabel setStringValue:@".xcarchive app copied"];
        
        if (changeBundleIDCheckbox.state == NSOnState) {
            [self doBundleIDChange:bundleIDField.stringValue];
        }
        
        if ([[provisioningPathField stringValue] isEqualTo:@""]) {
            [self doCodeSigning];
        } else {
            [self doProvisioning];
        }
    }
}

- (BOOL)doBundleIDChange:(NSString *)newBundleID {
    BOOL success = YES;
    
    success &= [self doAppBundleIDChange:newBundleID];
    success &= [self doITunesMetadataBundleIDChange:newBundleID];
    
    return success;
}


- (BOOL)doITunesMetadataBundleIDChange:(NSString *)newBundleID {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:workingPath error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"plist"]) {
            infoPlistPath = [workingPath stringByAppendingPathComponent:file];
            break;
        }
    }
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistiTunesArtwork newBundleID:newBundleID plistOutOptions:NSPropertyListXMLFormat_v1_0];
    
}

- (BOOL)doAppBundleIDChange:(NSString *)newBundleID {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            infoPlistPath = [[[workingPath stringByAppendingPathComponent:kPayloadDirName]
                              stringByAppendingPathComponent:file]
                             stringByAppendingPathComponent:kInfoPlistFilename];
            break;
        }
    }
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistApp newBundleID:newBundleID plistOutOptions:NSPropertyListBinaryFormat_v1_0];
}

- (BOOL)changeBundleIDForFile:(NSString *)filePath bundleIDKey:(NSString *)bundleIDKey newBundleID:(NSString *)newBundleID plistOutOptions:(NSPropertyListWriteOptions)options {
    
    NSMutableDictionary *plist = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        plist = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        [plist setObject:newBundleID forKey:bundleIDKey];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:options options:kCFPropertyListImmutable error:nil];
        
        return [xmlData writeToFile:filePath atomically:YES];
        
    }
    
    return NO;
}


- (void)doProvisioning {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            if ([[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                NSLog(@"Found embedded.mobileprovision, deleting.");
                [[NSFileManager defaultManager] removeItemAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] error:nil];
            }
            break;
        }
    }
    
    NSString *targetPath = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    
    provisioningTask = [[NSTask alloc] init];
    [provisioningTask setLaunchPath:@"/bin/cp"];
    [provisioningTask setArguments:[NSArray arrayWithObjects:[provisioningPathField stringValue], targetPath, nil]];
    
    [provisioningTask launch];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkProvisioning:) userInfo:nil repeats:TRUE];
}

- (void)checkProvisioning:(NSTimer *)timer {
    if ([provisioningTask isRunning] == 0) {
        [timer invalidate];
        provisioningTask = nil;
        
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
        
        for (NSString *file in dirContents) {
            if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
                appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
                if ([[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                    
                    BOOL identifierOK = FALSE;
                    NSString *identifierInProvisioning = @"";
                    
                    NSString *embeddedProvisioning = [NSString stringWithContentsOfFile:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] encoding:NSASCIIStringEncoding error:nil];
                    NSArray* embeddedProvisioningLines = [embeddedProvisioning componentsSeparatedByCharactersInSet:
                                                          [NSCharacterSet newlineCharacterSet]];
                    
                    for (int i = 0; i <= [embeddedProvisioningLines count]; i++) {
                        if ([[embeddedProvisioningLines objectAtIndex:i] rangeOfString:@"application-identifier"].location != NSNotFound) {
                            
                            NSInteger fromPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"<string>"].location + 8;
                            
                            NSInteger toPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"</string>"].location;
                            
                            NSRange range;
                            range.location = fromPosition;
                            range.length = toPosition-fromPosition;
                            
                            NSString *fullIdentifier = [[embeddedProvisioningLines objectAtIndex:i+1] substringWithRange:range];
                            
                            NSArray *identifierComponents = [fullIdentifier componentsSeparatedByString:@"."];
                            
                            if ([[identifierComponents lastObject] isEqualTo:@"*"]) {
                                identifierOK = TRUE;
                            }
                            
                            for (int i = 1; i < [identifierComponents count]; i++) {
                                identifierInProvisioning = [identifierInProvisioning stringByAppendingString:[identifierComponents objectAtIndex:i]];
                                if (i < [identifierComponents count]-1) {
                                    identifierInProvisioning = [identifierInProvisioning stringByAppendingString:@"."];
                                }
                            }
                            break;
                        }
                    }
                    
                    NSLog(@"Mobileprovision identifier: %@",identifierInProvisioning);
                    
                    NSString *infoPlist = [NSString stringWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"] encoding:NSASCIIStringEncoding error:nil];
                    if ([infoPlist rangeOfString:identifierInProvisioning].location != NSNotFound) {
                        NSLog(@"Identifiers match");
                        identifierOK = TRUE;
                    }
                    
                    if (identifierOK) {
                        NSLog(@"Provisioning completed.");
                        [statusLabel setStringValue:@"Provisioning completed"];
                        [self doEntitlementsFixing];
                    } else {
                        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Product identifiers don't match"];
                        [self enableControls];
                        [statusLabel setStringValue:@"Ready"];
                    }
                } else {
                    [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Provisioning failed"];
                    [self enableControls];
                    [statusLabel setStringValue:@"Ready"];
                }
                break;
            }
        }
    }
}


@end
