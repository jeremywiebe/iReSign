//
//  IRTextFieldDrag.swift
//  iReSign
//
//  Created by Jeremy Wiebe on 2015-07-29.
//  Copyright (c) 2015 nil. All rights reserved.
//

import Foundation
import Cocoa

class IRTextFieldDrag: NSTextField {

    override func awakeFromNib() {
        registerForDraggedTypes([NSFilenamesPboardType])
    }

    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        var pboard = sender.draggingPasteboard()

        if (contains(pboard.types as! [String], NSURLPboardType)) {
            var files = pboard.propertyListForType(NSFilenamesPboardType) as! [String]
            if files.count <= 0 {
                return false
            }
            stringValue = files[0]
        }

        return true
    }

    // Source: http://www.cocoabuilder.com/archive/cocoa/11014-dnd-for-nstextfields-drag-drop.html
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        if enabled {
            return NSDragOperation.None
        }

        var pboard = sender.draggingPasteboard()
        var sourceDragMask = sender.draggingSourceOperationMask()

        if contains(pboard.types as! [String], NSColorPboardType) {
            if sourceDragMask.rawValue & NSDragOperation.Copy.rawValue != 0 {
                return NSDragOperation.Copy
            }
        }

        if contains(pboard.types as! [String], NSFilenamesPboardType) {
            if sourceDragMask.rawValue & NSDragOperation.Copy.rawValue != 0 {
                return NSDragOperation.Copy
            }
        }

        return NSDragOperation.None
    }
}