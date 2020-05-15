//
//  AudioSystem.serialisation.swift
//  Arigato
//
//  Created by acb on 2020-04-20.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation
import AVFoundation

extension AudioSystem: Snapshottable {
    
    public struct Snapshot {
        // an item for the manifest of modules used; these are stored for validating recently opened documents, and reporting any unavailable units
        public struct ManifestItem {
            let name: String
            let manufacturer: String
            let audioComponentDescription: AudioComponentDescription
            let nodes: [Node.ID]
            
        }
        
        public let nodes: [Node.Snapshot]
        public let manifest: [ManifestItem]
        public let connections: [Connection]
        
        public init(nodes: [Node.Snapshot], manifest: [ManifestItem], connections: [Connection]) {
            self.nodes = nodes
            self.manifest = manifest
            self.connections = connections
        }
    }
    
    //MARK: generating a Snapshot of the current state
    public var snapshot: Snapshot {
        get {
            // gather node state
            let nodeSnapshots: [Node.Snapshot] = self.nodeMap.values.map { $0.snapshot }
                    
            let manifestData = self.nodeMap.values.reduce(into: [AudioComponentDescription:[Node]]()) { (accum, node) in
                if let au = node.avAudioNode as? AVAudioUnit {
                    accum[au.audioComponentDescription] = (accum[au.audioComponentDescription] ?? []) + [node]
                }
            }
            let manifest = manifestData.map { (arg0) -> Snapshot.ManifestItem in
                
                let (key, value) = arg0
                let node = value.first!
                
                let name = node.avAudioNode.auAudioUnit.componentName  ?? ""
                let manufacturer = node.avAudioNode.auAudioUnit.manufacturerName ?? ""
                return Snapshot.ManifestItem(name: name, manufacturer: manufacturer, audioComponentDescription: key, nodes: value.map { $0.id })
            }
            
            return Snapshot(nodes: nodeSnapshots, manifest: manifest, connections: self.connections)
        }
    }
    
    //MARK: loading state from a Snapshot
    public func load(state: Snapshot, onCompletion:  (()->())) throws {
        // validate the manifest, and pass back an error if invalid
        if let err = state.validate() {
            throw err
        }
        
        self.deleteAll()
        // load all nodes
        let nodesFuture: Future<[(Node.Snapshot, AVAudioUnit)]> = sequence(state.nodes.filter { $0.serialisedState != nil  }.map { (n: Node.Snapshot) -> Future<(Node.Snapshot, AVAudioUnit)> in
            let p = Promise<AVAudioUnit>()
            
            do {
                try AudioUnitPreset(data: n.serialisedState!).loadAudioUnit { (result) in
                    p.complete(with: result)
                }
            } catch {
                p.fail(with: error)
            }
            return p.future.map { (n, $0) }
        })
        
        nodesFuture.onSuccess { (nodeData: [(Node.Snapshot, AVAudioUnit)]) in
            for (nodeState,  avau) in nodeData {
                let node = Node(id: nodeState.id, name: nodeState.name, avAudioNode: avau)
                self.engine.attach(avau)
                self.nodeMap[node.id] = node
            }
        }
        
        // wire all nodes together
        for conn in state.connections {
            guard
                let fromNode = nodeMap[conn.from.node],
                let toNode = nodeMap[conn.to.node]
            else { continue }

            engine.connect(fromNode.avAudioNode, to: toNode.avAudioNode, fromBus: conn.from.bus, toBus: conn.to.bus, format: nil)
        }
        self.connections = state.connections
        
        // TODO: set up mixer
        
        self.connectionsChanged()
        
        onCompletion()
    }
}

extension AudioSystem.Node: Snapshottable {
    public struct Snapshot {
        let id: AudioSystem.Node.ID
        let name: String
        let serialisedState: Data?
    }
    
    var snapshot: AudioSystem.Node.Snapshot {
        let data: Data? =  (avAudioNode as? AVAudioUnit)?.auAudioUnit.fullStateForDocument.flatMap({ try? PropertyListSerialization.data(fromPropertyList: $0, format: PropertyListSerialization.PropertyListFormat.xml, options: 0)
        })
        return Snapshot(id: self.id, name: self.name, serialisedState: data)
    }
}

//MARK: Validation

func audioComponentQueryChecker(_ acd: AudioComponentDescription) -> Bool {
    var desc = acd
    return AudioComponentFindNext(nil, &desc) != nil
}

extension AudioSystem.Snapshot {
    func validate(_ checker: ((AudioComponentDescription)->Bool) = audioComponentQueryChecker(_:)) -> AudioSystem.Error? {
        let failed = self.manifest.filter { !$0.validate(checker) }
        if failed.isEmpty { return nil }
        let failedComponents = failed.map { item in
            (name: item.name, manufacturer: item.manufacturer, audioComponentDescription: item.audioComponentDescription, nodeNames: item.nodes.flatMap { nid in (self.nodes.first {
                $0.id == nid })?.name })
        }
        return AudioSystem.Error.componentsNotAvailable(failedComponents)
    }
}

extension AudioSystem.Snapshot.ManifestItem {
    // Validate this ManifestItem, using the passed function for checking the availability of its component; return true if valid
    func validate(_ checker: ((AudioComponentDescription)->Bool)) -> Bool {
        return checker(self.audioComponentDescription)
    }
}

//MARK: Codable conformances
extension AudioSystem.Node.Snapshot: Codable {}
extension AudioSystem.Snapshot.ManifestItem: Codable {}
extension AudioSystem.Connection.Endpoint: Codable {
    enum CodingKeys: String, CodingKey {
        case node
        case bus
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.node = try container.decode(Int.self, forKey: .node)
        self.bus = try container.decode(Int.self, forKey: .bus)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.node, forKey: .node)
        try container.encode(self.bus, forKey: .bus)
    }
}
extension AudioSystem.Connection: Codable {
    enum CodingKeys: String, CodingKey {
        case from
        case to
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.from = try container.decode(AudioSystem.Connection.Endpoint.self, forKey: .from)
        self.to = try container.decode(AudioSystem.Connection.Endpoint.self, forKey: .to)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.from, forKey: .from)
        try container.encode(self.to, forKey: .to)
    }
}

extension AudioSystem.Snapshot: Codable { }


extension AudioSystem {
    public convenience init(fromURL url: URL) throws {
        self.init()
        let data
            = try Data(contentsOf: url)

        let decoder = PropertyListDecoder()
        let snapshot
            = try decoder.decode(AudioSystem.Snapshot.self, from: data)

        let semaphore = DispatchSemaphore(value: 1)
        try self.load(state: snapshot) {
            semaphore.signal()
        }
        semaphore.wait()
    }
}
