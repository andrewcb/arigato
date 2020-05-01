//
//  KeystrokeReceiver.swift
//  ARigEditor
//
//  Created by acb on 2020-05-01.
//  Copyright © 2020 acb. All rights reserved.
//
//  A protocol for an object that wants, and may handle, keystrokes. This is decoupled from the NSResponder that gets them from Cocoa, to compartmentalise functionality, and allow keystroke handling to be decoupled from the GUI. One example of this would be a soft MIDI keyboard, which is not intrinsically a part of any view.

import Cocoa

protocol KeystrokeReceiver {
    /// Receive a keyDown event; return true if this event has been handled and should be considered consumed, false to propagate.
    func receiveKeyDown(_ keyCode: UInt16) -> Bool
    func receiveKeyUp(_ keyCode: UInt16) -> Bool
}
