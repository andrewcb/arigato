//
//  Helpers.swift
//  Arigato
//
//  Created by acb on 2020-05-29.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation
import AVFoundation

// Code for making AudioUnits and such quicker to use in code

extension AVAudioUnit {
    var parameters: [AUParameter] {
        return (self.auAudioUnit.parameterTree?.allParameters ?? [])
    }
    var parameterNames: [String] { return self.parameters.map { $0.displayName } }
    
    func parameter(matching pred: ((AUParameter)->Bool)) -> AUParameter? {
        return self.parameters.first(where:pred)
    }

    func parameter(named name: String) -> AUParameter? {
        return self.parameter(matching: { $0.displayName == name })
    }
}

let noteOffQueue = DispatchQueue(label: "ArigatoNoteOff")
extension AVAudioUnitMIDIInstrument {
    public func play(note: UInt8, withVelocity vel: UInt8, onChannel channel: UInt8, forDuration duration: Double) {
        self.startNote(note, withVelocity: vel, onChannel: channel)
        noteOffQueue.asyncAfter(deadline: DispatchTime.now()+duration) {
            self.stopNote(note, onChannel: channel)
        }
    }
}

func sleep(for time: Double) {
    usleep(useconds_t(time*1000000))
}

