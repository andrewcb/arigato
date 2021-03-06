//
//  ControlServer.swift
//  ARigEditor
//
//  Created by acb on 2020-12-19.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation
import NIO

/// The top-level object instantiating a  server that listens on TCP/UDP ports for commands
class ControlServer {
    let host: String
    var port: Int
    
    let eventLoopGroup: EventLoopGroup
    let bootstrapTCP: ServerBootstrap
    let channelTCP: Channel
    let bootstrapUDP: DatagramBootstrap
    let channelUDP: Channel
    
    var queryHandler: QueryHandling = QueryHandler()
    var udpPacketHandler: UDPPacketHandler? = nil
    
    // the query type
    enum TCPQuery {
        case listNodes
        case listParametersForNode(Int)
    }
    
    enum TCPQueryResponse {
        enum ResultValue {
            struct NodeInfo {
                let id: Int
                let name: String
            }
            case nodes([NodeInfo])
            // TODO: case params(...)
        }
        
        case success(ResultValue)
        case failure(String)
    }

    
    var audioSystem: AudioSystem? = nil {
        didSet {
            (self.queryHandler as? QueryHandler)?.audioSystem = self.audioSystem
            self.udpPacketHandler?.target = self.audioSystem
        }
    }

    init(host: String = "::1", port: Int) throws {
        self.host = host
        self.port = port
        
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let tcpQueryHandler = TCPQueryHandler()
        bootstrapTCP = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel -> EventLoopFuture<Void> in
                channel.pipeline.addHandlers([
                    BackPressureHandler(),
                    ByteToMessageHandler(LineDelimiterCodec()),
                    tcpQueryHandler
                    
                ])
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        let udpPacketHandler = UDPPacketHandler()
        bootstrapUDP = DatagramBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel -> EventLoopFuture<Void> in
                channel.pipeline.addHandler(udpPacketHandler)
            }
        self.udpPacketHandler = udpPacketHandler
        
        var tcpCh: Channel? = nil,  udpCh: Channel? = nil
        var retriesLeft = 256
        while ((tcpCh == nil || udpCh == nil) && retriesLeft>0) {
            do {
                tcpCh = try bootstrapTCP.bind(host: host, port: self.port).wait()
                udpCh = try bootstrapUDP.bind(host: host, port: self.port).wait()
            } catch  {
                tcpCh?.close()
                self.port += 1
                retriesLeft -=  1
                if retriesLeft < 1 { throw error }
            }
        }
        self.channelTCP = tcpCh!
        self.channelUDP = udpCh!
        
        tcpQueryHandler.queryHandler = self.queryHandler
    }
    
    func shutDown() throws {
        try channelTCP.close().wait()
        try channelUDP.close().wait()
    }
    
    var closeFuture: EventLoopFuture<Void>  {
        return channelTCP.closeFuture.and(channelUDP.closeFuture).map { _ in () }
    }
}

extension ControlServer.TCPQueryResponse.ResultValue.NodeInfo: Encodable {
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name  = "name"
    }
}

extension ControlServer.TCPQueryResponse.ResultValue: Encodable {
    func encode(to encoder: Encoder) throws {
        switch(self) {
        case .nodes(let nodeInfo):
            var ctr = encoder.unkeyedContainer()
            try ctr.encode(contentsOf: nodeInfo)
        }
    }
}

extension ControlServer.TCPQueryResponse: Encodable {
    enum CodingKeys: String, CodingKey {
        case success = "success"
        case result = "result"
        case error = "error"
    }
    func encode(to encoder: Encoder) throws {
        var ctr = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success(let v):
            try ctr.encode(true, forKey: .success)
            try ctr.encode(v, forKey: .result)
            break
        case .failure(let err):
            try ctr.encode(false, forKey: .success)
            try ctr.encode(err, forKey: .error)
            break
        }
    }
}
