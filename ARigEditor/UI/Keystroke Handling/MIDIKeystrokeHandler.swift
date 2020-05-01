//
//  MIDIKeystrokeHandler.swift
//  ARigEditor
//
//  Created by acb on 2020-05-01.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

class MIDIKeystrokeHandler: KeystrokeReceiver {
    
    var offset: UInt8 = 0
    var velocity: UInt8 = 100
    
    var sendNoteOn: ((UInt8, UInt8)->())? = nil
    var sendNoteOff: ((UInt8, UInt8)->())? = nil

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
    
    typealias Layout = [UInt16:KeyAction]
    
    // the Ableton Live layout: asdfgh=white notes,wetyuop = black notes; zx = octave, cv = velocity
    static let liveLayout: Layout = [
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
    ]
    
    let layout: Layout = MIDIKeystrokeHandler.liveLayout
    
    func triggerNoteOn(_ note: UInt8) {
        print("NoteOn(\(note+offset), \(velocity))")
        self.sendNoteOn?(note+offset, velocity)
    }
    func triggerNoteOff(_ note: UInt8) {
        print("NoteOff(\(note+offset), \(velocity))")
        self.sendNoteOff?(note+offset, velocity)
    }

    func receiveKeyDown(_ keyCode: UInt16) -> Bool {
        guard
            let action = self.layout[keyCode]
        else { return false }
        switch(action) {
        case .midiNote(let n): self.triggerNoteOn(n)
        case .octaveDown: if self.offset >= 12 { self.offset -= 12 }
        case .octaveUp: if self.offset < 120 { self.offset += 12 }
        case .velocityDown: self.velocity = (self.velocity > 10) ? self.velocity - 10 : 0
        case .velocityUp: self.velocity = min(self.velocity+10, 127)
        }
        return true
        
    }
    
    func receiveKeyUp(_ keyCode: UInt16) -> Bool {
        guard
            let action = self.layout[keyCode],
            case let .midiNote(n) = action
        else { return false }
        self.triggerNoteOff(n)
        return true
    }
}
