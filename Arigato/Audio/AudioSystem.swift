//
//  AudioSystem.swift
//  Arigato
//
//  Created by acb on 2020-04-20.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation
import AVFoundation

/** The AudioSystem  encapsulates the entire AudioUnit network as initialised, along with metadata for finding and addressing individual AudioUnits programmatically.
 */
public class AudioSystem {
    internal let engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()

    // MARK: Node metadata
    struct Node {
        typealias ID = Int
        static let mainOutputID = 0
        static let mainMixerID = 1
        static var nextID: ID = 2
        
        let id: ID
        let avAudioNode: AVAudioNode
        var name: String
        
        init(id: ID? = nil, name: String, avAudioNode: AVAudioNode) {
            self.id = id ?? Node.nextID
            Node.nextID  = max(Node.nextID, self.id+1)
            self.name = name
            self.avAudioNode = avAudioNode
        }
    }
    
    var nodeMap: [Node.ID:Node] = [:]
    
    // MARK: Connections
    struct Connection: Equatable, Hashable {
        struct Endpoint: Equatable, Hashable {
            let node: Node.ID
            let bus: Int
        }
        let from: Endpoint
        let to: Endpoint
        
        init(from:(Node.ID, Int), to: (Node.ID, Int)) {
            self.from = Endpoint(node: from.0, bus: from.1)
            self.to = Endpoint(node: to.0, bus: to.1)
        }
    }

    var connections: [Connection] = []
    
    //MARK: internal handlers for events
    // do any processing required when the topology of connections changes
    internal func connectionsChanged() {
        // invalidate caches, recalculate derived data, &c.
    }

    
    
    // MARK: initialisation
    private func initNodeMap() {
        self.nodeMap = [
            Node.mainMixerID : Node(name: "$mixer", avAudioNode: self.engine.mainMixerNode)
        ]
    }
    
    public init() {
        let engine = self.engine
        self.initNodeMap()
        try? engine.start()
    }
    
    //MARK: Public methods for accessing nodes
    func node(byName name: String) -> Node? {
        //  TODO: index this
        return nodeMap.values.first { $0.name == name }
    }
    public func audioUnit(byName name: String) -> AVAudioUnit? {
        return node(byName: name)?.avAudioNode as? AVAudioUnit
    }
    public func midiInstrument(byName name: String) -> AVAudioUnitMIDIInstrument? {
        return node(byName: name)?.avAudioNode as? AVAudioUnitMIDIInstrument
    }

    //MARK: internal methods for editing the node graph
    func deleteAll() {
        for (id, node) in nodeMap {
            guard id != Node.mainMixerID && id != Node.mainOutputID else { continue }
            engine.disconnectNodeInput(node.avAudioNode)
            engine.disconnectNodeOutput(node.avAudioNode)
            engine.detach(node.avAudioNode)
        }
        self.initNodeMap()
        self.connections = []
    }

}
