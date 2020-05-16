//
//  GraphView.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa
import AudioToolbox

protocol GraphViewDataSource {
    var numberOfNodes: Int { get }
    var nodeIDs: [GraphView.NodeID] { get }
    var connections: [GraphView.Connection] { get }
        
    func getMetadata(forNodeID id: GraphView.NodeID) -> GraphView.NodeMetadata
    func makeView(forNodeID id: GraphView.NodeID, withMetadata metadata: GraphView.NodeMetadata) -> GraphNodeView
}

protocol GraphViewLayout {
    func nodePosition(forNodeID id: GraphView.NodeID) -> NSPoint
    func setNodePosition(_ position: NSPoint, forNodeID id: GraphView.NodeID)
}

// the delegate, which handles events triggered by the graph view
protocol GraphViewDelegate {
    func make(connection: GraphView.Connection)
    func makeNewInletConnection(fromNode id: GraphView.NodeID, bus: Int, toNode id2: GraphView.NodeID)
    func `break`(connection: GraphView.Connection)
    func rename(node id: GraphView.NodeID, to: String)
    func createNode(withDesc: AudioComponentDescription, at point: NSPoint)
    func delete(node id: GraphView.NodeID)
    // Called when a node is selected or deselected
    func nodeSelected(_ id: GraphView.NodeID?)

}

protocol GraphNodeView: NSView {
    var id: GraphView.NodeID? { get }
    func inletPoint(_ index: Int) -> NSPoint
    func outletPoint(_ index: Int) -> NSPoint
    func regionHitTest(_ point: NSPoint) -> GraphView.NodeViewRegion?
    
    // notify the GraphNodeView that its connections have changed
    func connectionsChanged()
    
    var graphView: GraphView { get set }
    var isSelected: Bool { get set }
    var isSelectable: Bool { get }
    var isDeletable: Bool { get }
    var canAddInlets: Bool { get }
}

/**
 GraphView is a view which presents a graph of nodes and their connections. It is intended to live inside a NSScrollView and thus resizes itself as needed.
 GraphView is currently coupled to AudioSystem.{Node,Connection}, though a future generic implementation should be possible.
 */
class GraphView: NSView {
    typealias NodeID = AudioSystem.Node.ID
    typealias Connection = AudioSystem.Connection
    
    struct NodeMetadata {
        let title: String
        let numInlets: Int
        let numOutlets: Int
        let audioComponentDescription: AudioComponentDescription?
    }
    
    // The areas of a node view, for hit-testing
    enum NodeViewRegion {
        case body // the main parts of the node, for dragging to move and such
        case inlet(Int)
        case outlet(Int)
    }
    
    enum DragState {
        case movingNode(NodeID, offset: NSPoint)
        case draggingFromInlet(NodeID, Int)
        case draggingFromOutlet(NodeID, Int)
    }
    
    // a visible item which may be manipulated in the GraphView; this is either a node or a connection.
    enum ContentItem: Equatable {
        case connection(Connection)
        case node (NodeID)
        
        var nodeID: NodeID? { if case let .node(id) = self { return id } else { return nil } }
        var connection: Connection? { if case let .connection(c) = self { return c } else { return nil } }
    }
    
    //MARK: view-model state
    var nodeViews: [NodeID:GraphNodeView] = [:]
    var dragState: DragState?
    var selection: ContentItem? = nil {
        didSet(prev) {
            if self.selection != prev {
                // Node selection drawing is done in the node itself
                self.reloadConnections()
                if case let .node(id) = prev { self.nodeViews[id]?.isSelected = false }
                if case let .node(id) = self.selection { self.nodeViews[id]?.isSelected = true }
                if prev?.nodeID != self.selection?.nodeID { self.delegate?.nodeSelected(self.selection?.nodeID) }
            }
        }
    }
    var selectedConnection: Connection? {
        if case let .connection(c) = self.selection { return c }
        return nil
    }

    //MARK: connections to other components
    var delegate: GraphViewDelegate?

    var dataSource: GraphViewDataSource? { didSet  { self.reloadData() } }
    
    var layoutDelegate: GraphViewLayout? { didSet { self.reloadData() } }
    
    //MARK: UI hierarchy
    fileprivate var connectionOverlayView = ConnectionOverlay(frame: .zero)

    //MARK: life cycle
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setUp()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setUp()
    }
    
    fileprivate func setUp() {
        self.connectionOverlayView.frame = self.bounds
        self.connectionOverlayView.autoresizingMask = [.height, .width]
        self.addSubview(self.connectionOverlayView)
        
        registerForDraggedTypes([.audioUnit])
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    //MARK: sizing the window to fit
    var visibleSize: NSSize { return self.superview?.frame.size ?? .zero }
    
    fileprivate func ensureViewFitsSuperview() {
        let visibleSize = self.visibleSize+NSSize(width: max(0,-self.frame.origin.x), height: max(0,-self.frame.origin.y))
        self.frame.size = max(self.frame.size, visibleSize) //NSSize(width: max(self.frame.size.width, visibleSize.width), height: max(self.frame.size.height, visibleSize.height))
    }
    
    // grow the size if needed to accommodate a specific node, which is assumed to have been moved recently
    fileprivate func adjustSizeToFit(node id: NodeID) {
        guard let v = self.nodeViews[id] else { return }
        self.frame.size = NSSize(width: max(max(0, self.frame.size.width), v.frame.maxX), height: max(max(0, self.frame.size.height), v.frame.maxY))
        self.ensureViewFitsSuperview()
    }
    
    // Adjust the view size to wrap all existing nodes
    fileprivate func adjustSizeToWrapNodes() {
        // TODO: if nodes have moved below/left of the origin, adjust the origin and move everything up
        let origin = self.nodeViews.values.reduce(NSPoint.zero) { (prev, v) -> NSPoint in
            NSPoint(x: min(prev.x, v.frame.origin.x), y: min(prev.y, v.frame.origin.y))
        }
        if origin != .zero {
            // move everything up
            self.nodeViews.forEach { (id, v) in
                v.frame.origin = NSPoint(x: v.frame.origin.x-origin.x, y: v.frame.origin.y-origin.y)
            }
            self.frame.origin = NSPoint(x: self.frame.origin.x+origin.x, y: self.frame.origin.y+origin.y)
            self.updateLineLayer()
        }
        
        self.frame.size = self.nodeViews.values.reduce(NSSize.zero) { (prev, v) -> NSSize in
            NSSize(width: max(prev.width, v.frame.maxX), height: max(prev.height, v.frame.maxY))
        }
        self.ensureViewFitsSuperview()
    }
    
    /** The publically available method to make the view adjust its frame to embrace all subviews and fill its container  */
    func adjustFrame() {
        self.adjustSizeToWrapNodes()
    }
    
    // MARK: data source accessors
    var numberOfNodes: Int { return dataSource?.numberOfNodes ?? 0 }
    var nodeIDs: [AudioSystem.Node.ID] { return dataSource?.nodeIDs ?? [] }
    var connections: [Connection] { return dataSource?.connections ?? [] }
    func nodePosition(forNodeID id: Int) -> NSPoint { return self.layoutDelegate?.nodePosition(forNodeID:id) ?? .zero }
    func getMetadata(forNodeID id: GraphView.NodeID) -> GraphView.NodeMetadata {
        guard let dataSource = self.dataSource else { fatalError("getMetadata called without data source") }
        return dataSource.getMetadata(forNodeID: id)
    }
    func makeView(forNodeID id: AudioSystem.Node.ID, withMetadata metadata: GraphView.NodeMetadata) -> GraphNodeView {
        guard let dataSource = self.dataSource else { fatalError("makeView called without data source") }
        return dataSource.makeView(forNodeID: id, withMetadata: metadata)
    }
    // MARK: Methods for node views to communicate with the graph view
    // For requesting changes from the Delegate
    func requestRename(node id: NodeID, to title: String) {
        self.delegate?.rename(node: id, to: title)
    }
    
    // to be called by any node when its intrinsicContentSize changes
    func requestResize(node id: NodeID) {
        guard let view = nodeViews[id] else { return }
        let size = view.intrinsicContentSize
        view.frame = NSRect(x: min(view.frame.origin.x, self.bounds.size.width-size.width), y: max(view.frame.origin.y, size.height), width: size.width, height: size.height)
        // Do any graph layout here
    }
    
    func requestCreateNode(withDesc desc: AudioComponentDescription, at point: NSPoint) {
        self.delegate?.createNode(withDesc: desc, at: point)
    }
    
    // MARK: hit testing
    fileprivate func distance(betweenPoint point: NSPoint, andConnection connection: Connection) -> CGFloat {
        guard let pts = self.points(forConnection: connection) else { return .infinity }
        return point.distanceFromLine(between: pts.0, and: pts.1)
    }
    
    fileprivate func hitTestConnection(_ point: NSPoint) -> Connection? {
        let threshold: CGFloat = 4
        return (self.connections.map { ($0, self.distance(betweenPoint: point, andConnection: $0)) })
            .filter ({ $0.1 < threshold })
            .sorted (by: { $0.1 < $1.1 })
            .first
            .map ({$0.0})
    }
    
    fileprivate func itemAt(point: NSPoint) -> ContentItem? {
        return (self.subviews.compactMap({$0 as? GraphNodeView}).first { $0.frame.contains(point) }?.id).flatMap { ContentItem.node($0) } ?? self.hitTestConnection(point).map { ContentItem.connection($0) }
    }
    
    // MARK: communication with the connection overlay
    
    fileprivate func points(forConnection connection: Connection) -> (NSPoint, NSPoint)? {
        guard let av = nodeViews[connection.from.node], let bv = nodeViews[connection.to.node] else { return nil }
        let ap = av.frame.origin
        let bp = bv.frame.origin
        return (ap+av.outletPoint(connection.from.bus), bp+bv.inletPoint(connection.to.bus))
    }
    
    fileprivate func updateLineLayer() {
        self.connectionOverlayView.lines = self.connections.compactMap { (conn) in
            self.points(forConnection:conn).map { (a, b) in (a, b, conn==self.selectedConnection) }
            
        }
    }
    
    //MARK: reloading
    
    func reloadConnections(affectedNodes: [NodeID]? = nil) {
        updateLineLayer()
        for nodeID in (affectedNodes ?? []) {
            self.nodeViews[nodeID]?.connectionsChanged()
        }
    }
    
    func reloadData() {
        let nodeIDs = self.nodeIDs
        for i in self.nodeViews.keys {
            if !nodeIDs.contains(i) {
                self.nodeViews[i]?.removeFromSuperview()
                nodeViews.removeValue(forKey: i)
            }
        }
        for id in nodeIDs {
            if let prev = self.nodeViews[id] {
                // TODO: recycle
                prev.removeFromSuperview()
            }
            let metadata = self.getMetadata(forNodeID: id)
            let newNodeView = self.makeView(forNodeID: id, withMetadata: metadata)
            self.nodeViews[id] = newNodeView
            newNodeView.frame = NSRect(origin: self.nodePosition(forNodeID: id), size: newNodeView.intrinsicContentSize)
            self.addSubview(newNodeView, positioned: .below, relativeTo: self.connectionOverlayView)
        }
        self.updateLineLayer()
        self.adjustSizeToWrapNodes()
    }

    // MARK: responding to UI events
    override func mouseDown(with event: NSEvent) {
        print("modifier flags = \(event.modifierFlags)")
        let locationInView = self.convert(event.locationInWindow, from: nil)
        // manually find nodes
        self.selection = self.itemAt(point: locationInView)
        if case let .node(id) = self.selection {
            guard let nodeView = self.nodeViews[id] else { fatalError() }
            switch(nodeView.regionHitTest(locationInView-nodeView.frame.origin)) {
            case .body:
                self.dragState = .movingNode(id, offset: NSPoint(x: nodeView.frame.origin.x-locationInView.x, y: nodeView.frame.origin.y-locationInView.y))
            case .inlet(let n):
                self.dragState = .draggingFromInlet(id, n)
            case .outlet(let n):
                self.dragState = .draggingFromOutlet(id, n)
            default:
                break
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let dragState = self.dragState else { return }
        self.dragState = nil
        let locationInView = self.convert(event.locationInWindow, from: nil)
        switch(dragState) {
        case .movingNode(let id, offset: let offset):
            self.adjustSizeToWrapNodes()
            self.layoutDelegate?.setNodePosition(NSPoint(x: locationInView.x+offset.x, y: locationInView.y+offset.y), forNodeID: id)
        case .draggingFromInlet(let id2, let n2):
            self.connectionOverlayView.dragLine = nil
            guard
                case let .node(id1) = self.itemAt(point: locationInView),
                let view = self.nodeViews[id1],
                case let .outlet(n1) = view.regionHitTest(locationInView-view.frame.origin)
            else { return }
            delegate?.make(connection: GraphView.Connection(from:(id1, n1), to:(id2, n2)))
        case .draggingFromOutlet(let id1, let n1):
            self.connectionOverlayView.dragLine = nil
            guard
                case let .node(destid) = self.itemAt(point: locationInView),
                let view = self.nodeViews[destid]
            else { return }
            if case let .inlet(n2) = view.regionHitTest(locationInView-view.frame.origin) {
                delegate?.make(connection: GraphView.Connection(from:(id1, n1), to:(destid, n2)))
            } else if view.canAddInlets {
                delegate?.makeNewInletConnection(fromNode: id1, bus: n1, toNode: destid)
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let dragState = self.dragState else { return }
        let locationInView = self.convert(event.locationInWindow, from: nil)
        switch(dragState) {
        case .movingNode(let id, offset: let offset):
            self.nodeViews[id]?.frame.origin = (locationInView+offset).rounded()
            self.adjustSizeToFit(node: id)
            self.updateLineLayer()
        case .draggingFromInlet(let id, let n):
            guard let v = self.nodeViews[id] else { return }
            let startPt = v.frame.origin + v.inletPoint(n)
            self.connectionOverlayView.dragLine = (startPt, locationInView)
        case .draggingFromOutlet(let id, let n):
            guard let v = self.nodeViews[id] else { return }
            let startPt = v.frame.origin + v.outletPoint(n)
            self.connectionOverlayView.dragLine = (startPt, locationInView)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        switch(event.keyCode) {
        case 51: // backspace
            guard let sel = self.selection else { break }
            switch(sel) {
            case .connection(let conn):
                print("Break connection \(conn)")
                self.delegate?.break(connection: conn)
            case .node(let id):
                guard let nv = self.nodeViews[id], nv.isDeletable else { break }
                print("Delete node \(id)")
                self.delegate?.delete(node: id)
            }
        default:
            nextResponder?.keyDown(with: event)
            break
        }
    }
}

// MARK: drag and drop
extension GraphView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        let point = convert(sender.draggingLocation, from: nil)
        
        if let types=pasteboard.types, types.contains(.audioUnit), let data = pasteboard.data(forType: .audioUnit) {
            guard let desc = AudioComponentDescription(data: data) else {
                print("Invalid data")
                return false
            }
            print("\(desc)")
            self.requestCreateNode(withDesc: desc, at: point)
            self.window?.makeFirstResponder(self)
            return true
        }
        return false
    }
}


///MARK: the connection overlay, a semitransparent view which draws connecting lines between nodes.
extension GraphView {
    class ConnectionOverlay: NSView {
        let lineColor = NSColor.red
        var lines: [(NSPoint, NSPoint, Bool)] = []  {
            didSet {
                self.setNeedsDisplay(self.bounds)
            }
        }
        var dragLine: (NSPoint, NSPoint)? = nil {
            didSet(prev) {
                // TODO: calculate a minimum rectangle enclosing the current and old value
                self.setNeedsDisplay(self.bounds)
            }
        }
        
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }
        
        override func draw(_ dirtyRect: NSRect) {
            for (from, to, isSelected) in lines {
                if (from.x < dirtyRect.minX  && to.x < dirtyRect.minX) || (from.y < dirtyRect.minY  && to.y < dirtyRect.minY) || (from.x > dirtyRect.maxX  && to.x > dirtyRect.maxX) || (from.y > dirtyRect.maxY  && to.y > dirtyRect.maxY) {
                    continue
                }
                lineColor.setStroke()
                let curve = NSBezierPath()
                curve.lineWidth = isSelected ? 2 : 1
                curve.move(to: from)
                curve.line(to: to)
                curve.stroke()
            }
            if let (from, to) = dragLine {
                lineColor.setStroke()
                let curve = NSBezierPath()
                curve.move(to: from)
                curve.line(to: to)
                curve.setLineDash([2, 2], count: 2, phase: 0)
                curve.stroke()

            }
        }
    }

}
