//
//  UDPPacketHandler.swift
//  ARigEditor
//
//  Created by acb on 2020-12-27.
//  Copyright © 2020 acb. All rights reserved.
//

import NIO
import AVFoundation

enum UDPPacket {
    case midiEvent(AudioSystem.Node.ID,UInt8,UInt8,UInt8?)
    init?(byteBuffer: ByteBuffer) {
        let type  = byteBuffer.getInteger(at: 0, endianness: .little, as: UInt32.self)
        switch(type) {
        case 0x7645644d: //  MdEv
            guard
                let nodeID = byteBuffer.getInteger(at: 4, endianness: .little, as: UInt32.self),
                let u1: UInt8 = byteBuffer.getInteger(at: 8),
                let u2: UInt8 = byteBuffer.getInteger(at: 9)
            else { return nil }
            self = .midiEvent(Int(nodeID), u1, u2, byteBuffer.getInteger(at: 10))
            break
        default:
            return nil
        }
    }
}

protocol UDPPacketReceiving {
    func receive(udpPacket: UDPPacket)
}

extension AudioSystem: UDPPacketReceiving {
    func receive(udpPacket: UDPPacket) {
        switch(udpPacket) {
        case let  .midiEvent(nodeID, u0, u1, u2):
            guard
                nodeID < self.nodeTable.count,
                let n = self.nodeTable[nodeID],
                let inst = n.avAudioNode as? AVAudioUnitMIDIInstrument
            else { return }
            if let u2 = u2 {
                inst.sendMIDIEvent(u0, data1: u1, data2: u2)
            } else {
                inst.sendMIDIEvent(u0, data1: u1)
            }
        }
    }
}

final class UDPPacketHandler: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    
    var target: UDPPacketReceiving? = nil
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let inb = unwrapInboundIn(data)
        
        let bytes = inb.data.getBytes(at: 0, length: inb.data.readableBytes)
        let str = inb.data.getString(at: 0, length: inb.data.readableBytes) ?? "\(inb.data.getBytes(at: 0, length: inb.data.readableBytes))"
        
        let hexcode = inb.data.getInteger(at: 0, endianness: .little, as: UInt32.self).map { String($0, radix: 16, uppercase: true) } ?? "----"
        
        print("UDP: \(hexcode) -> \(str)")
        
        if let packet = UDPPacket(byteBuffer: inb.data) {
            target?.receive(udpPacket: packet)
        } else {
//            print("Not a valid packet")
        }
    }
}

