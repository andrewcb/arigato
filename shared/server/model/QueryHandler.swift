//
//  QueryHandler.swift
//  ARigEditor
//
//  Created by acb on 2020-12-19.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

protocol QueryHandling {
    func handle(query: ControlServer.TCPQuery) -> ControlServer.TCPQueryResponse
}

class QueryHandler: QueryHandling {
    var audioSystem: AudioSystem? = nil
    
    func handle(query: ControlServer.TCPQuery) -> ControlServer.TCPQueryResponse {
        guard let audioSystem = self.audioSystem else {
            return .failure("Not connected")
        }
        switch(query) {
        case .listNodes:
            let r =  audioSystem.nodeTable.flatMap { $0.map { ControlServer.TCPQueryResponse.ResultValue.NodeInfo(id: $0.id, name: $0.name)  } }
            return .success(.nodes(r))
        case .listParametersForNode(let nodeID):
            return .failure("Not implemented")
        @unknown default:
            return .failure("Not implemented")
        }
    }
}
