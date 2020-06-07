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
    @IBOutlet var selectedNodeDetailContainerView: NSView!
    
    let nodeInterfaceManager  = NodeInterfaceManager()

    var selectedNode: AudioSystem.Node? {
        didSet {
            self.currentNodeDetailViewController = selectedNode.flatMap { NodeDetailType(node: $0) }.flatMap { self.nodeDetailViewControllers[$0] }
        }
    }
    var selectedMIDIInstrument: AVAudioUnitMIDIInstrument? {
        return self.selectedNode?.avAudioNode as? AVAudioUnitMIDIInstrument
    }
    
    /// The type of detail view a selected node should have, if any.
    enum NodeDetailType: String, Equatable, CaseIterable {
        case midi = "NodeDetailMIDI"
        case textToSpeech = "NodeDetailTTS"
        
        init?(node: AudioSystem.Node) {
            if node.avAudioNode.isSpeechSynthesizer { self = .textToSpeech }
            else if (node.avAudioNode as? AVAudioUnitMIDIInstrument) != nil { self = .midi }
            else { return nil }
        }
    }
    var currentNodeDetailViewController: NSViewController? {
        didSet(prev) {
            guard self.currentNodeDetailViewController != prev else { return }
            if let prevVC = prev {
                /* remove the previous view */
                prevVC.removeFromParent()
                prevVC.view.removeFromSuperview()
            }
            if let vc = currentNodeDetailViewController {
                // add the new view controller
                self.selectedNodeDetailContainerView.addSubview(vc.view)
                vc.view.frame = self.selectedNodeDetailContainerView.bounds
                self.addChild(vc)
            }
            self.view.window?.makeFirstResponder(self.graphView)
        }
    }
    
    var nodeDetailViewControllers: [NodeDetailType:NSViewController] = [:]

    var document: ARigDocument? {
        return self.view.window?.windowController?.document as? ARigDocument
    }
    
    let midiKeystrokeHandler = MIDIKeystrokeHandler()
    
    var keystrokeReceiverChain: [KeystrokeReceiver] = []

    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.graphView.dataSource = self
        self.graphView.layoutDelegate = self
        self.graphView.delegate = self
        
        self.graphView.wantsLayer = true
        self.graphView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.05).cgColor
        self.graphView.layer?.borderWidth = 1.0
        
        self.keystrokeReceiverChain = [midiKeystrokeHandler]
        self.midiKeystrokeHandler.sendNoteOn = { (n,v) in self.selectedMIDIInstrument?.startNote(n, withVelocity: v, onChannel: 0) }
        self.midiKeystrokeHandler.sendNoteOff = { (n,_) in self.selectedMIDIInstrument?.stopNote(n, onChannel: 0) }
        
        for key in NodeDetailType.allCases {
            nodeDetailViewControllers[key] = self.storyboard?.instantiateController(withIdentifier: key.rawValue) as? NSViewController
        }
        (nodeDetailViewControllers[.textToSpeech] as? TextToSpeechNodeDetailViewController)?.textSubmitHandler = { (text) in
            self.selectedNode?.avAudioNode.speak(text)
        }
        
        nodeInterfaceManager.keystrokeRelayingTarget =  self
    }

    override func viewWillAppear() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleZoomNotification(_:)), name: .zoomChanged, object: nil)
        self.graphView.reloadData()
    }
    
    override func viewWillDisappear() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        self.graphView.adjustFrame()
    }
    
    //MARK: menus
    
    @IBAction func exportPlaygroundRequested(_ sender: Any) {
        guard let vc = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ExportPlaygroundOptions")) as? ExportPlaygroundOptionsViewController else { return }
        vc.onConfirm = { [weak self] (fmtOptions, actOptions) in
            guard let self = self else { return }
            let savePanel = NSSavePanel()
            savePanel.allowedFileTypes =  ["playground"]
            savePanel.allowsOtherFileTypes = false
            savePanel.nameFieldStringValue = (self.document?.fileURL?.lastPathComponent).map {  $0.hasSuffix(".arig") ? String($0.dropLast(5)) : $0  } ?? "Untitled"
            guard
                savePanel.runModal() == .OK,
                let url = savePanel.url
            else { return }
            do {
                try PlaygroundExporter.export(self.document!, toURL: url, withOptions: fmtOptions)
                switch(actOptions.onCompletion) {
                    
                case .doNothing: break
                case .showInFinder: NSWorkspace.shared.activateFileViewerSelecting([url])
                case .openInXcode: NSWorkspace.shared.open(url)
                }
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
        self.presentAsSheet(vc)
    }
    
    @objc func handleZoomNotification(_ notification: Notification) {
        guard let zoomLevel = notification.userInfo?[kZoomLevel] as? Int else { return }
        self.graphView.zoomLevel = zoomLevel
    }
    
    //MARK: keystroke handling
    override func keyDown(with event: NSEvent) {
        if event.isARepeat { return }
        for receiver in self.keystrokeReceiverChain {
            if receiver.receiveKeyDown(event.keyCode) { return }
        }
        nextResponder?.keyDown(with: event)
    }
    
    override func keyUp(with event: NSEvent) {
        for receiver in self.keystrokeReceiverChain {
            if receiver.receiveKeyUp(event.keyCode) { return }
        }
        nextResponder?.keyUp(with: event)
    }
    
    //MARK: UI windows
    func openUIView(forNode id: AudioSystem.NodeID, preferringGUI: Bool = true) {
        guard let node = document?.audioSystem.node(byId: id) else { return }
        nodeInterfaceManager.openWindow(forNode: node, preferringGUI: preferringGUI)
    }
}

extension MainViewController: GraphViewDelegate {
    func nodeSelected(_ id: GraphView.NodeID?) {
        self.selectedNode = id.flatMap { document?.audioSystem.node(byId:$0) }
    }
    
    func make(connection: GraphView.Connection) {
        try? document?.audioSystem.connect(fromNode: connection.from.node, bus: connection.from.bus, toNode: connection.to.node, bus: connection.to.bus)
        self.graphView.reloadConnections(affectedNodes: [connection.from.node, connection.to.node])
    }
    
    func makeNewInletConnection(fromNode id: GraphView.NodeID, bus: Int, toNode id2: GraphView.NodeID) {
        guard id2 == AudioSystem.Node.mainMixerID else {
            print("makeNewInletConnection called with non-mixer destination node; not supported")
            return
        }
        try? document?.audioSystem.connectToMainMixer(node: id, bus: bus)
        self.graphView.reloadConnections(affectedNodes: [id, id2])
        self.graphView.reloadData()
    }
    
    func `break`(connection: GraphView.Connection) {
        try? document?.audioSystem.disconnect(inputBus: connection.to.bus, ofNode: connection.to.node)
        self.graphView.reloadConnections(affectedNodes: [connection.from.node, connection.to.node])
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
                let ctrlPressed = NSEvent.modifierFlags.contains(.control)
                self.openUIView(forNode: id, preferringGUI: !ctrlPressed)
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

extension MainViewController: MIDIEventRecipient {
    func receive(midiEvent: ArraySlice<UInt8>) {
        guard
            let inst = self.selectedMIDIInstrument,
            let st  = midiEvent.first,
            let d1 = midiEvent.dropFirst().first
        else { return }
        let t = st & 0xf0
        let ch = st & 0x0f

        let d2 = midiEvent.dropFirst(2).first ?? 0
        switch(t) {
        case 0x80: // note off
            inst.stopNote(d1, onChannel: ch)
        case 0x90: // note on
            inst.startNote(d1, withVelocity: d2, onChannel: ch)
        case 0xa0:
            inst.sendPressure(forKey: d1, withValue: d2, onChannel: ch)
        case 0xb0:
            inst.sendController(d1, withValue: d2, onChannel: ch)
        case 0xc0:
            inst.sendProgramChange(d1, onChannel: ch)
        case 0xd0:
            inst.sendPressure(d1, onChannel: ch)
        case 0xe0:
            inst.sendPitchBend(UInt16(d1) | (UInt16(d2)<<7), onChannel: ch)
        default: break
        }
    }
}
