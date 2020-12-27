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
    
    private func response(fromInput line: String) -> ControlServer.TCPQueryResponse {
        guard let queryHandler = self.queryHandler else {
            return .failure("Internal error: query handler not present")
        }
        guard let query = parse(query: line) else {
            return .failure("Invalid query")
        }
        return queryHandler.handle(query: query)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let inb = unwrapInboundIn(data)
        let line = inb.getString(at: 0, length: inb.readableBytes) ?? ""
        
        let result = self.response(fromInput: line)
        
        let encoder = JSONEncoder()
        let encoded = try! encoder.encode(result)
        var outbuf = context.channel.allocator.buffer(capacity: encoded.count+2)
        _ = encoded.withUnsafeBytes { (bptr) in
            outbuf.writeBytes(bptr)
        }
        outbuf.writeString("\n")
        context.writeAndFlush(self.wrapOutboundOut(outbuf))
        
    }
}
