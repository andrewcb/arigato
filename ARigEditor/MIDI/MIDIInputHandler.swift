//
//  MIDIInputHandler.swift
//  ARigEditor
//
//  Created by acb on 2020-06-07.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation
import CoreMIDI

protocol MIDIEventRecipient {
    func receive(midiEvent: ArraySlice<UInt8>)
}

/// A long-lived object that connects to MIDI input devices and relays input from them
class MIDIInputHandler {
    var midiClient: MIDIClientRef = 0
    var inputPort: MIDIPortRef = 0
    
    var recipient: MIDIEventRecipient?
    
    func findAndConnectSources() {
        let sourceCount = MIDIGetNumberOfSources()
        for srcIndex in  0..<sourceCount {
            let midiEndPoint = MIDIGetSource(srcIndex)
            MIDIPortConnectSource(self.inputPort, midiEndPoint, nil)
        }
    }
    
    init() {
        let name = (Bundle.main.bundleIdentifier ??  "ARigEditor") + ".midi"
        // FIXME:  throw if OSStatus != 0
        MIDIClientCreateWithBlock(NSString(string: name), &midiClient, {
            [weak self] (notificationPtr: UnsafePointer<MIDINotification>)  -> () in
            self?.handle(midiNotification: notificationPtr.pointee)
        })
        MIDIInputPortCreateWithBlock(midiClient, NSString(string: name+".input"), &inputPort, { (packetList: UnsafePointer<MIDIPacketList>, srcConnRefCon: UnsafeMutableRawPointer?)  in
            var p = packetList.pointee.packet
            let len =  Int(p.length)
            let bufdata = withUnsafePointer(to: &p) { (ptr) -> [UInt8] in
                let offset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
                let ptr2 = UnsafeRawBufferPointer(start: UnsafeRawPointer(ptr).advanced(by: offset), count: len)
                return (0..<len).map { ptr2[$0] }
            }
            self.handleMIDIBuffer(bufdata)
        })
        self.findAndConnectSources()
    }
    
    func handle(midiNotification:MIDINotification) {
        if midiNotification.messageID == .msgObjectAdded {
            self.findAndConnectSources()
        }
    }
    
    /// take  the next event off the buffer slice if there is one, and if so, consume it. Otherwise, return nil
    /// this breaks if there are sysexes, but so does the rest of this code
    func takeMIDIEvent(_ b: inout ArraySlice<UInt8>) -> ArraySlice<UInt8>? {
        guard
            let t = ((b.first).map { $0  & 0xf0 }),
            t>=0x80 && t<=0xe0
        else { return nil }
        let len = (t==0xc0 || t==0xd0) ? 2 : 3
        guard  b.count >= len else { return nil }
        defer { b = b.dropFirst(len) }
        return b.prefix(len)
    }

    func handleMIDIBuffer(_ buf: [UInt8]) {
        var remaining = buf[0..<buf.count]
        while let  msg = takeMIDIEvent(&remaining) {
            recipient?.receive(midiEvent: msg)
        }
    }

}
