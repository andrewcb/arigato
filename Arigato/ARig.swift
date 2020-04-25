//
//  ARig.swift
//  Arigato
//
//  Created by acb on 2020-04-25.
//  Copyright © 2020 acb. All rights reserved.
//
/// ARig (or audio rig) is the object encapsulating everything, including the AudioUnit graph and any other elements accessed from its API. ARig is the publicly-acessible interface to Arigato's functionality.

import AVFoundation

public class ARig {
    let audioSystem: AudioSystem
    
    let nodeInterfaceManager = NodeInterfaceManager()
    
    public init(fromURL url: URL) throws {
        audioSystem = try AudioSystem(fromURL: url)
    }
    
    public func audioUnit(byName name: String) -> AVAudioUnit? {
        return audioSystem.audioUnit(byName: name)
    }
    
    public func midiInstrument(byName name: String) -> AVAudioUnitMIDIInstrument? {
        return audioSystem.midiInstrument(byName: name)
    }

    public func mixingHeadNode(forMixerInput ch: Int) -> AVAudioMixing? {
        return audioSystem.findMixingHeadNode(forMixerInput: ch)
    }
    
    public func openWindow(forUnitNamed name: String) {
        guard let node = audioSystem.node(byName: name) else { return }
        nodeInterfaceManager.openWindow(forNode: node)
    }
}

