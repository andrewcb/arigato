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
    
    struct Snapshot {
        // an item for the manifest of modules used; these are stored for validating recently opened documents, and reporting any unavailable units
        struct ManifestItem {
            let name: String
            let manufacturer: String
            let audioComponentDescription: AudioComponentDescription
            let nodes: [Node.ID]
            
        }
        
        let nodes: [Node.Snapshot]
        let manifest: [ManifestItem]
        let connections: [Connection]
    }
    
    var snapshot: Snapshot {
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
}

extension AudioSystem.Node: Snapshottable {
    struct Snapshot {
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

