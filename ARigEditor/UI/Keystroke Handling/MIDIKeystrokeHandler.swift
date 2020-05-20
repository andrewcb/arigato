//
//  MIDIKeystrokeHandler.swift
//  ARigEditor
//
//  Created by acb on 2020-05-01.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

class MIDIKeystrokeHandler: KeystrokeReceiver {
    
    var offset: UInt8 = 24 // C0
    var velocity: UInt8 = 100
    
    var sendNoteOn: ((UInt8, UInt8)->())? = nil
    var sendNoteOff: ((UInt8, UInt8)->())? = nil
    var onPressedKeysChange: (()->())? = nil
    var onOctaveChange: (()->())? = nil
    var onVelocityChange: (()->())? = nil

    enum KeyAction {
        // Emit a MIDI note, with the value added to the offset
        case midiNote(UInt8)
        // decrement the offset by one octave
        case octaveDown
        // increment the offset by one octave
        case octaveUp
        // decrement the velocity
        case velocityDown
        // increment the velocity
        case velocityUp
    }
    
    struct Layout {
        let keyActions: [UInt16:KeyAction]
        let keyCaps: [String]
    }
    
    // the Ableton Live layout: asdfgh=white notes,wetyuop = black notes; zx = octave, cv = velocity
    static let liveLayout = Layout(
        keyActions: [
            // Hypothesis: key codes are based on physical position, not letter; so this will work equally on, say, a French AZERTY as on a US QWERTY
            0: .midiNote(0),
            13: .midiNote(1),
            1: .midiNote(2),
            14: .midiNote(3),
            2: .midiNote(4),
            3: .midiNote(5),
            17: .midiNote(6),
            5: .midiNote(7),
            16: .midiNote(8),
            4: .midiNote(9),
            32: .midiNote(10),
            38: .midiNote(11),
            40: .midiNote(12),
            31: .midiNote(13),
            37: .midiNote(14),
            33: .midiNote(15),
            6: .octaveDown,
            7: .octaveUp,
            8: .velocityDown,
            9: .velocityUp
        ],
        // TODO: make this portable across layouts somehow
        keyCaps: ["A", "W", "S", "E", "D", "F", "T", "G", "Y", "H", "U", "J", "K", "O", "L", "P"]
    )
    
    let layout: Layout = MIDIKeystrokeHandler.liveLayout
    
    var pressedKeys = Set<Int>()
    
    func triggerNoteOn(_ note: UInt8) {
        print("NoteOn(\(note+offset), \(velocity))")
        pressedKeys.insert(Int(note))
        self.onPressedKeysChange?()
        self.sendNoteOn?(note+offset, velocity)
    }
    func triggerNoteOff(_ note: UInt8) {
        print("NoteOff(\(note+offset), \(velocity))")
        pressedKeys.remove(Int(note))
        self.onPressedKeysChange?()
        self.sendNoteOff?(note+offset, velocity)
    }

    func receiveKeyDown(_ keyCode: UInt16) -> Bool {
        guard
            let action = self.layout.keyActions[keyCode]
        else { return false }
        switch(action) {
        case .midiNote(let n): self.triggerNoteOn(n)
        case .octaveDown: if self.offset >= 12 { self.offset -= 12; self.onOctaveChange?() }
        case .octaveUp: if self.offset < 120 { self.offset += 12; self.onOctaveChange?() }
        case .velocityDown:
            self.velocity = (self.velocity > 10) ? self.velocity - 10 : 0
            self.onVelocityChange?()
        case .velocityUp:
            self.velocity = min(self.velocity+10, 127)
            self.onVelocityChange?()
        }
        return true
        
    }
    
    func receiveKeyUp(_ keyCode: UInt16) -> Bool {
        guard
            let action = self.layout.keyActions[keyCode],
            case let .midiNote(n) = action
        else { return false }
        self.triggerNoteOff(n)
        return true
    }
}

extension MIDIKeystrokeHandler: MIDIComputerKeyboardStatusSource {
    func keyIsPressed(_ index: Int) -> Bool {
        return self.pressedKeys.contains(index)
    }
    
    var octave: Int { return (Int(self.offset)/12)-2 }
}
