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
    public enum Error: Swift.Error {
        /// Thrown if referring to a nonexistent node
        case nodeNotFound
        
        ///  Thrown if attempting to load state containing unavailable components
        case componentsNotAvailable([(name: String, manufacturer: String, audioComponentDescription: AudioComponentDescription, nodeNames: [String])])
    }

    internal let engine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()

    // MARK: Node metadata
    public struct Node {
        public typealias ID = Int
        public static let mainOutputID = 0
        public static let mainMixerID = 1
        static var nextID: ID = 2
        
        public let id: ID
        public let avAudioNode: AVAudioNode
        public var name: String
        
        init(id: ID? = nil, name: String, avAudioNode: AVAudioNode) {
            self.id = id ?? Node.nextID
            Node.nextID  = max(Node.nextID, self.id+1)
            self.name = name
            self.avAudioNode = avAudioNode
        }
    }
    public typealias NodeID = Node.ID
    
    var nodeMap: [Node.ID:Node] = [:]
    
    // MARK: Connections
    public struct Connection: Equatable, Hashable {
        public struct Endpoint: Equatable, Hashable {
            public let node: Node.ID
            public let bus: Int
        }
        public let from: Endpoint
        public let to: Endpoint
        
        public init(from:(Node.ID, Int), to: (Node.ID, Int)) {
            self.from = Endpoint(node: from.0, bus: from.1)
            self.to = Endpoint(node: to.0, bus: to.1)
        }
    }

    public internal(set) var connections: [Connection] = []
    
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
    
    public var nodeCount: Int { return nodeMap.count }
    
    public var nodeIDs: AnyCollection<NodeID> { return AnyCollection(nodeMap.keys) }
    
    public func node(byId id: NodeID) -> Node? {
        return nodeMap[id]
    }
    public func node(byName name: String) -> Node? {
        //  TODO: index this
        return nodeMap.values.first { $0.name == name }
    }
    public func audioUnit(byName name: String) -> AVAudioUnit? {
        return node(byName: name)?.avAudioNode as? AVAudioUnit
    }
    public func midiInstrument(byName name: String) -> AVAudioUnitMIDIInstrument? {
        return node(byName: name)?.avAudioNode as? AVAudioUnitMIDIInstrument
    }
    
    // finding mixer nodes for inputs
    public func findMixingHeadNode(forMixerInput ch: Int) -> AVAudioMixing? {
        // Assumption: the node immediately upstream of the mixer input will be the one we want if  it's available. If this turns out to not be the case, we may need to follow links upstream
        return self.connections.first { $0.to == Connection.Endpoint(node: Node.mainMixerID, bus: ch)
        }.flatMap { self.nodeMap[$0.from.node]?.avAudioNode as? AVAudioMixing }
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
