//
//  KeyboardCommittableTextField.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class KeyboardCommittableTextField: NSTextField {
    /// The callback called when the user presses a key finalising the edit action, either committing it (Enter) or cancelling (Esc). Takes one argument: a Bool, which is true iff the user committed the edit.
    var editCompletionHandler: ((Bool)->())?
    
    override func keyUp(with event: NSEvent) {
        switch(event.keyCode) {
        case 36: // ENTER
            self.editCompletionHandler?(true)
        case 53: // ESC
            self.editCompletionHandler?(false)
        default:
            super.keyUp(with: event)
        }
    }
}
