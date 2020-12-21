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
        public static let firstUserID = 2
        
        public let id: ID
        public let avAudioNode: AVAudioNode
        public var name: String
        
        init(id: ID, name: String, avAudioNode: AVAudioNode) {
            self.id = id
            self.name = name
            self.avAudioNode = avAudioNode
        }
    }
    public typealias NodeID = Node.ID
    
    var nodeTable: [Node?] = []
    
    // insert a node into the data structures
    internal func add(node: Node) {
        assert(node.id == nodeTable.count)
        nodeTable.append(.some(node))
    }
    
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
    
    // all node graph operations are performed on this queue, and thus made atomic
    private let nodeGraphSyncQueue = DispatchQueue(label: "nodeGraphQueue")
    // an array of nodes, indexable by offset; array indices never change, hence the contents are optional, and deleted nodes are replaced with nil
    
    //MARK: internal handlers for events
    // do any processing required when the topology of connections changes
    internal func connectionsChanged() {
        // invalidate caches, recalculate derived data, &c.
    }

    
    
    // MARK: initialisation
    private func initNodeMap() {
        self.nodeTable = (0..<Node.firstUserID).map { _ in nil }
        self.nodeTable[Node.mainMixerID] = Node(id: Node.mainMixerID, name: "$mixer", avAudioNode: self.engine.mainMixerNode)
    }
    
    public init() {
        let engine = self.engine
        self.initNodeMap()
        try? engine.start()
    }
    
    //MARK: Public methods for accessing nodes
    
    public var nodeCount: Int {
        return nodeTable.reduce(0) { $1==nil ? $0 : $0+1 }
    }
    
    public var nodeIDs: AnyCollection<NodeID> {
        return AnyCollection(nodeTable.compactMap { $0?.id })
    }
    
    public func node(byId id: NodeID) -> Node? {
        return nodeTable[id]
    }
    public func node(byName name: String) -> Node? {
        //  TODO: index this
        return nodeTable.first { $0?.name == name }.map { $0! }
    }
    public func audioUnit(byName name: String) -> AVAudioUnit? {
        return node(byName: name)?.avAudioNode as? AVAudioUnit
    }
    public func midiInstrument(byName name: String) -> AVAudioUnitMIDIInstrument? {
        return node(byName: name)?.avAudioNode as? AVAudioUnitMIDIInstrument
    }
    
    func nodeIDsMatching(_ predicate: ((Node)->Bool)) -> [NodeID] {
        return self.nodeTable.compactMap { maybeNode in
            maybeNode.flatMap { node in
                predicate(node) ? node.id  : nil
            }
        }
    }
    
    public var musicDeviceIDs: [NodeID] {
        return nodeIDsMatching { $0.avAudioNode.isMusicDevice }
    }
    
    public var speechSynthesizerIDs: [NodeID] {
        return nodeIDsMatching { $0.avAudioNode.isSpeechSynthesizer }
    }
    
    //MARK: Public node manipulation methods for editing the graph
    public  func createNode(withDesc desc: AudioComponentDescription, callback: ((NodeID)->())?) {
        desc.loadAudioUnit { (result) in
            guard let unit = try? result.get() else {
                print("Error loading unit: \(result)")
                return
            }
            callback?(self.add(node: unit, withName: unit.name))
        }
    }
    
    public func connect(fromNode from: Node.ID, bus fromBus: AVAudioNodeBus, toNode  to: Node.ID, bus toBus: AVAudioNodeBus) throws {
        guard
            let fromNode = nodeTable[from],
            let toNode = nodeTable[to]
        else { throw Error.nodeNotFound }
        nodeGraphSyncQueue.sync {
            engine.connect(fromNode.avAudioNode, to: toNode.avAudioNode, fromBus: fromBus, toBus: toBus, format: nil)
            let newConnection = Connection(from: (from, fromBus), to: (to, toBus))
            self.connections.removeAll { $0.from == newConnection.from || $0.to == newConnection.to }
            self.connections.append(newConnection)
        }
        self.connectionsChanged()
    }
    
    // Connect to the next available slot on the main mixer
    public func connectToMainMixer(node: Node.ID, bus: AVAudioNodeBus = 0) throws {
        guard
            let fromNode = nodeTable[node]
        else { throw Error.nodeNotFound }
        nodeGraphSyncQueue.sync {
            let toBus = engine.mainMixerNode.nextAvailableInputBus
            engine.connect(fromNode.avAudioNode, to: engine.mainMixerNode, fromBus: bus, toBus: toBus, format: nil)
            self.connections.append(Connection(from: (node, bus), to: (Node.mainMixerID, toBus)))
        }
        self.connectionsChanged()
    }
    
    public func disconnect(inputBus: AVAudioNodeBus, ofNode nodeID: Node.ID) throws {
        guard
            let node = nodeTable[nodeID]
        else { throw Error.nodeNotFound }
        nodeGraphSyncQueue.sync {
            engine.disconnectNodeInput(node.avAudioNode, bus: inputBus)
            self.connections.removeAll { ($0.to.node, $0.to.bus) == (nodeID, inputBus) }
        }
        self.connectionsChanged()
    }
    
    public func delete(node id: NodeID) {
        guard let node = self.nodeTable[id] else { return }
        nodeGraphSyncQueue.sync {
            self.connections.removeAll { id == $0.from.node || id == $0.to.node }
            engine.disconnectNodeInput(node.avAudioNode)
            engine.disconnectNodeOutput(node.avAudioNode)
            engine.detach(node.avAudioNode)
            nodeTable[id] = nil
        }
        self.connectionsChanged()
    }
        

    // finding mixer nodes for inputs
    public func findMixingHeadNode(forMixerInput ch: Int) -> AVAudioMixing? {
        // Assumption: the node immediately upstream of the mixer input will be the one we want if  it's available. If this turns out to not be the case, we may need to follow links upstream
        return self.connections.first { $0.to == Connection.Endpoint(node: Node.mainMixerID, bus: ch)
        }.flatMap { self.nodeTable[$0.from.node]?.avAudioNode as? AVAudioMixing }
    }

    //MARK: internal methods for editing the node graph
    @discardableResult func add(node avAudioNode: AVAudioNode, withName name: String)  -> Node.ID {
        return nodeGraphSyncQueue.sync {
            let node = Node(id: nodeTable.count, name: name, avAudioNode: avAudioNode)
            engine.attach(avAudioNode)
            self.add(node: node)
            return node.id
        }
    }
    
    func deleteAll() {
        nodeGraphSyncQueue.sync {
            for maybeNode in nodeTable {
                guard let node = maybeNode, node.id != Node.mainMixerID && node.id != Node.mainOutputID else { continue }
                engine.disconnectNodeInput(node.avAudioNode)
                engine.disconnectNodeOutput(node.avAudioNode)
                engine.detach(node.avAudioNode)
            }
            self.initNodeMap()
            self.connections = []
        }
    }

}

extension AudioSystem.Error: Equatable {
    public static func == (lhs: AudioSystem.Error, rhs: AudioSystem.Error) -> Bool {
        switch (lhs, rhs) {
        case (.nodeNotFound, .nodeNotFound): return true
        case (.componentsNotAvailable(let la), .componentsNotAvailable(let lb)):
            return zip(la,lb).reduce(true) {
                (prev, pair) -> Bool in
                return prev && (pair.0.name == pair.1.name) && (pair.0.manufacturer == pair.1.manufacturer) && (pair.0.audioComponentDescription == pair.1.audioComponentDescription) && (pair.0.nodeNames == pair.1.nodeNames)
            }
        default: return false
        }
    }
}
