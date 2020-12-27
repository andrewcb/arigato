//
//  TCPQueryHandler.swift
//  ARigEditor
//
//  Created by acb on 2020-12-19.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation
import NIO

// This class expects each input to consist of one line, i.e., one command
final class TCPQueryHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    var queryHandler: QueryHandling?  = nil
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let id = ObjectIdentifier(context.channel)
        let inb = unwrapInboundIn(data)
        let line = inb.getString(at: 0, length: inb.readableBytes) ?? ""
        let sp = line.split(separator: " ", maxSplits: 1)
        
        let query  = ControlServer.TCPQuery.listNodes // FIXME: parse this
        
        
        guard
            let result = queryHandler?.handle(query: query)
        else {
            print("No query handler set")
            return
        }
        //ControlServer.TCPQueryResponse.success(.nodes([ControlServer.TCPQueryResponse.ResultValue.NodeInfo(id: 23, name: "test")]))
        
        let encoder = JSONEncoder()
        let encoded = try! encoder.encode(result)
        var outbuf = context.channel.allocator.buffer(capacity: encoded.count+2)
        encoded.withUnsafeBytes { (bptr) in
            outbuf.writeBytes(bptr)
        }
        outbuf.writeString("\n")
        context.writeAndFlush(self.wrapOutboundOut(outbuf))
        print("Line: \(line)")
        
    }
}
