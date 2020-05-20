//
//  MIDIKeyboardNodeDetailViewController.swift
//  ARigEditor
//
//  Created by acb on 2020-05-03.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class MIDIKeyboardNodeDetailViewController: NSViewController {
    @IBOutlet var keyboardView: MIDIComputerKeyboardView!
    @IBOutlet var octaveLabel: NSTextField!
    @IBOutlet var velocityLabel: NSTextField!
    @IBOutlet var velocityLevelIndicator: NSLevelIndicator!
    
    override func viewDidAppear() {
        guard let keystrokeHandler = ((self.parent as? MainViewController)?.midiKeystrokeHandler) else { return }
        keyboardView.keyboardStatusSource = keystrokeHandler
        keyboardView.keyCaps = keystrokeHandler.layout.keyCaps
        
        keystrokeHandler.onPressedKeysChange = keyboardView.refresh
        keystrokeHandler.onOctaveChange = {
            self.octaveLabel.stringValue = "C \(keystrokeHandler.octave)" }
        keystrokeHandler.onVelocityChange = {
            self.velocityLabel.integerValue = Int(keystrokeHandler.velocity)
            self.velocityLevelIndicator.integerValue = Int(keystrokeHandler.velocity)
        }
        
        keystrokeHandler.onOctaveChange?()
        keystrokeHandler.onVelocityChange?()
    }
}
