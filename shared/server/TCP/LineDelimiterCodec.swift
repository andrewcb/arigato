//
//  LineDelimiterCodec.swift
//  ARigEditor
//
//  Created by acb on 2020-12-19.
//  Copyright © 2020 acb. All rights reserved.
//

import NIO

private let newLine = "\n".utf8.first!
final class LineDelimiterCodec: ByteToMessageDecoder {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = ByteBuffer

    public var cumulationBuffer: ByteBuffer?

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let readable = buffer.withUnsafeReadableBytes { $0.firstIndex(of: newLine) }
        if let r = readable {
            context.fireChannelRead(self.wrapInboundOut(buffer.readSlice(length: r)!))
            buffer.moveReaderIndex(forwardBy: 1)
            return .continue
        }
        return .needMoreData
    }
}

