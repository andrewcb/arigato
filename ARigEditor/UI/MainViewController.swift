//
//  MainViewController.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa
import AudioToolbox
import AVFoundation
//import Arigato

class MainViewController: NSViewController {
    
    @IBOutlet var graphView: GraphView!
    
    let nodeInterfaceManager  = NodeInterfaceManager()

    var midiDest: AudioSystem.Node?

    var document: ARigDocument? {
        return self.view.window?.windowController?.document as? ARigDocument
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.graphView.dataSource = self
        self.graphView.layoutDelegate = self
        self.graphView.delegate = self
        
        self.graphView.wantsLayer = true
        self.graphView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.05).cgColor
        self.graphView.layer?.borderWidth = 1.0
    }

    override func viewWillAppear() {
        self.graphView.reloadData()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        self.graphView.adjustFrame()
    }
    
    override func keyDown(with event: NSEvent) {
        print("VC: keyDown: \(event.keyCode)")
        nextResponder?.keyDown(with: event)
    }
    
    //MARK: UI windows
    func openUIView(forNode id: AudioSystem.NodeID) {
        guard let node = document?.audioSystem.node(byId: id) else { return }
        nodeInterfaceManager.openWindow(forNode: node)
    }
}

extension MainViewController: GraphViewDelegate {
    func nodeSelected(_ id: GraphView.NodeID?) {
        self.midiDest = id.flatMap { document?.audioSystem.node(byId:$0) }
    }
    
    func make(connection: GraphView.Connection) {
        try? document?.audioSystem.connect(fromNode: connection.from.node, bus: connection.from.bus, toNode: connection.to.node, bus: connection.to.bus)
        self.graphView.reloadConnections()
    }
    
    func makeNewInletConnection(fromNode id: GraphView.NodeID, bus: Int, toNode id2: GraphView.NodeID) {
        guard id2 == AudioSystem.Node.mainMixerID else {
            print("makeNewInletConnection called with non-mixer destination node; not supported")
            return
        }
        try? document?.audioSystem.connectToMainMixer(node: id, bus: bus)
        self.graphView.reloadData()
    }
    
    func `break`(connection: GraphView.Connection) {
        try? document?.audioSystem.disconnect(inputBus: connection.to.bus, ofNode: connection.to.node)
        self.graphView.reloadConnections()
    }
    
    func rename(node id: Int, to newTitle: String) {
        document?.audioSystem.nodeMap[id]?.name = newTitle
        self.graphView.reloadData()
    }
    
    func createNode(withDesc desc: AudioComponentDescription, at point: NSPoint) {
        self.document?.audioSystem.createNode(withDesc: desc) { (newID) in
            self.document?.nodePositions[newID] = point
            self.graphView.reloadData()
        }
    }
    
    func delete(node id: GraphView.NodeID) {
        nodeInterfaceManager.closeInterfaces(forNodeWithID: id)
        self.document?.audioSystem.delete(node: id)
        self.graphView.reloadData()
    }

}

extension MainViewController: GraphViewDataSource {
    var numberOfNodes: Int {
        return self.document?.audioSystem.nodeCount ?? 0
    }
    
    var nodeIDs: [GraphView.NodeID] { return self.document?.audioSystem.nodeIDs.map { $0 }  ?? [] }
    
    var connections: [GraphView.Connection] { return self.document?.audioSystem.connections ?? [] }
    
    func getMetadata(forNodeID id: GraphView.NodeID) -> GraphView.NodeMetadata {
        guard let node = document?.audioSystem.node(byId:id)  else { fatalError("No node for id \(id)")}
        let auAudioUnit = node.avAudioNode.auAudioUnit
        return GraphView.NodeMetadata(title: node.name, numInlets: auAudioUnit.inputBusses.count, numOutlets: auAudioUnit.outputBusses.count, audioComponentDescription: (node.avAudioNode as? AVAudioUnit)?.audioComponentDescription)
    }
    
    func makeView(forNodeID id: AudioSystem.Node.ID, withMetadata metadata: GraphView.NodeMetadata) -> GraphNodeView {
        if id == AudioSystem.Node.mainMixerID {
            let view =  MixerGraphNodeView(frame: .zero, graphView: graphView)
            view.id = id
            view.metadata = metadata
            view.mixerTarget = self
            return view
        } else {
            let view = GenericGraphNodeView(frame: .zero, graphView: graphView)
            view.id = id
            view.metadata = metadata
            view.onInterfaceButtonPress = {
                //#warning("not implemented: openUIView")
                self.openUIView(forNode: id)
            }
            return view
        }
    }
}

extension MainViewController: GraphViewLayout {
    func setNodePosition(_ position: NSPoint, forNodeID id: Int) {
        self.document?.nodePositions[id] = position
    }
    
    func nodePosition(forNodeID id: Int) -> NSPoint {
        return self.document?.nodePositions[id] ?? .zero
    }
}

extension MainViewController: MixerTarget {
    // TODO: cache the head nodes?
    func getLevel(forChannel ch: Int) -> Float {
        return self.document?.audioSystem.findMixingHeadNode(forMixerInput: ch)?.volume ?? .nan
    }
    
    func getPan(forChannel ch: Int) -> Float {
        return (self.document?.audioSystem.findMixingHeadNode(forMixerInput: ch))?.pan ?? .nan
    }
    
    func setLevel(forChannel ch: Int, to value: Float) {
        self.document?.audioSystem.findMixingHeadNode(forMixerInput: ch)?.volume = value
    }
    
    func setPan(forChannel ch: Int, to value: Float) {
        self.document?.audioSystem.findMixingHeadNode(forMixerInput: ch)?.pan = value
    }
}
