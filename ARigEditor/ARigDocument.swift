//
//  ARigDocument.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class ARigDocument: NSDocument {
    
    let audioSystem = AudioSystem()
    var nodePositions: [AudioSystem.NodeID:NSPoint] = [:]

    override init() {
        super.init()
        self.hasUndoManager = false
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
    }

    // MARK: saving/loading of state
    
    struct State {
        struct EditorData: Codable {
            struct NodeLayout: Codable {
                let id: AudioSystem.NodeID
                let position: NSPoint
            }
            let nodes: [NodeLayout]
        }
        
        let audioSystemState: AudioSystem.Snapshot
        let editorData: EditorData

    }
    
    private var state: State {
        return State(audioSystemState: self.audioSystem.snapshot, editorData: State.EditorData(nodes: self.nodePositions.map { (id, pos) in State.EditorData.NodeLayout(id: id, position: pos) }))
    }
    
    private func load(state: State) throws {
        try self.audioSystem.load(state: state.audioSystemState) {
            self.nodePositions = [Int:NSPoint](uniqueKeysWithValues: state.editorData.nodes.map {  ($0.id, $0.position) })
            // update the UI
        }
    }
        
    override func data(ofType typeName: String) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml // for debugging
        return try encoder.encode(self.state)
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        let decoder = PropertyListDecoder()
        let decoded = try decoder.decode(State.self, from: data)
        try self.load(state: decoded)
    }

}

// MARK: SnapshotData Codable
extension ARigDocument.State: Codable {
    enum CodingKeys: String, CodingKey {
        case nodes
        case manifest
        case connections
        case editorData = "_editorData"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nodes = try container.decode([AudioSystem.Node.Snapshot].self, forKey: .nodes)
        let manifest = try container.decode([AudioSystem.Snapshot.ManifestItem].self, forKey: .manifest)
        let connections = try container.decode([AudioSystem.Connection].self, forKey: .connections)
        self.audioSystemState = AudioSystem.Snapshot(nodes: nodes, manifest: manifest, connections: connections)
        self.editorData  = try container.decodeIfPresent(EditorData.self, forKey: .editorData) ?? EditorData(nodes: [])
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.audioSystemState.nodes, forKey: .nodes)
        try container.encode(self.audioSystemState.manifest, forKey: .manifest)
        try container.encode(self.audioSystemState.connections, forKey: .connections)
        try container.encode(self.editorData, forKey: .editorData)
    }

}
