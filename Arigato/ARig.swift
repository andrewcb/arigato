//
//  ARig.swift
//  Arigato
//
//  Created by acb on 2020-04-25.
//  Copyright © 2020 acb. All rights reserved.
//
/// ARig (or audio rig) is the object encapsulating everything, including the AudioUnit graph and any other elements accessed from its API. ARig is the publicly-acessible interface to Arigato's functionality.

import AVFoundation

public class ARig: NSObject {
    let audioSystem: AudioSystem
    
    let nodeInterfaceManager = NodeInterfaceManager()
    
    @objc public override init() {
        audioSystem = AudioSystem()
        super.init()
    }
    
    @objc public init(fromURL url: URL) throws {
        audioSystem = try AudioSystem(fromURL: url)
    }
    
    @objc public func load(fromURL url: URL) throws {
        try audioSystem.load(fromURL: url)
    }
    
    enum Error: Swift.Error {
        case resourceNotFound
    }
    public convenience init(fromResource resname: String, withExtension ext:String = "arig") throws {
        guard let url = Bundle.main.url(forResource: resname, withExtension: ext) else {
            throw Error.resourceNotFound
        }
        try self.init(fromURL: url)
    }
    
    @objc public func audioUnit(byName name: String) -> AVAudioUnit? {
        return audioSystem.audioUnit(byName: name)
    }
    
    @objc public func midiInstrument(byName name: String) -> AVAudioUnitMIDIInstrument? {
        return audioSystem.midiInstrument(byName: name)
    }

    @objc public func mixingHeadNode(forMixerInput ch: Int) -> AVAudioMixing? {
        return audioSystem.findMixingHeadNode(forMixerInput: ch)
    }
    
    @objc public func openWindow(forUnitNamed name: String) {
        guard let node = audioSystem.node(byName: name) else { return }
        nodeInterfaceManager.openWindow(forNode: node)
    }
}

