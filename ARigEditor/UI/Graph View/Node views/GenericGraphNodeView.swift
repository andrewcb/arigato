//
//  GenericGraphNodeView.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

// The node view for a generic graph node.
class GenericGraphNodeView: NSView, GraphNodeView {
    
    var onInterfaceButtonPress: (()->())?

    // MARK: metrics
    // these are prescaled
    // The depth of the inlet/outlet tabs (width if horizontal, height if vertical)
    // The depth of the tabs for the purposes of dropping links
    let connectionTabDropDepth: CGFloat = 8
    let maxConnectionSize: CGFloat = 8
    // the height of the area beneath the title
    let clientAreaHeight: CGFloat = 32
    
    override var intrinsicContentSize: NSSize {
        return NSSize(
            width: (64*graphView.zoomScale).rounded(.toNearestOrAwayFromZero),
            height: (DrawingModel.reservedHeight+clientAreaHeight)*graphView.zoomScale.rounded(.toNearestOrAwayFromZero))
    }


    // MARK: --
    
    let titleLabel = KeyboardCommittableTextField()
    let interfaceButton = NSButton(title: "", target: nil, action:nil)
    var id: GraphView.NodeID?
    var metadata: GraphView.NodeMetadata?
    
    var graphView: GraphView
    
    let isSelectable: Bool = true
    let isDeletable: Bool = true
    let canAddInlets: Bool = false

    var isSelected: Bool = false {
        didSet(prev) {
            if self.isSelected != prev { self.setNeedsDisplay(self.bounds) }
        }
    }

    init(frame frameRect: NSRect, graphView: GraphView) {
        self.graphView = graphView
        super.init(frame: frameRect)

        self.titleLabel.backgroundColor = NSColor.white
        self.titleLabel.textColor = NSColor.black
        //self.titleLabel.autoresizingMask = [.width]
        self.titleLabel.font = DrawingModel.titleFont
        self.titleLabel.isBezeled = false
        self.titleLabel.isBordered = false
        self.titleLabel.isEditable = true
        self.titleLabel.isSelectable = true
        self.titleLabel.isHidden = true
        self.titleLabel.delegate = self
        self.titleLabel.editCompletionHandler = { if ($0) { self.handleRename() } else { self.closeTitleEditor() } }
        self.addSubview(titleLabel)
        
        self.interfaceButton.bezelStyle = .smallSquare
        self.interfaceButton.isBordered = false
        self.interfaceButton.wantsLayer = true
        self.interfaceButton.image = NSImage(named: "btn_gui")
        self.interfaceButton.target = self
        self.interfaceButton.action = #selector(self.interfaceButtonPressed(_:))
        self.addSubview(interfaceButton)
        
        let click = NSClickGestureRecognizer(target: self, action: #selector(self.click))
        click.numberOfClicksRequired = 1
        click.delaysPrimaryMouseButtonEvents = false
        self.addGestureRecognizer(click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        self.interfaceButton.frame = NSRect(
            x: DrawingModel.unscaledInnerMargin,
            y: drawingModel.titleBottom-24*graphView.zoomScale,
            width: 18*graphView.zoomScale,
            height: 18*graphView.zoomScale)
    }
    
    @objc func click(_ recognizer: NSClickGestureRecognizer) {
        if !self.isSelected, let id=self.id {
            graphView.selection = .node(id)
        }
        let c = recognizer.location(in: self)
        if c.y >= self.bounds.size.height-DrawingModel.unscaledConnectionTabProtrusion-DrawingModel.titleHeight && c.y < self.bounds.size.height-DrawingModel.unscaledConnectionTabProtrusion {
            self.titleLabel.stringValue = self.metadata?.title ?? ""
            self.titleLabel.isHidden = false
            self.titleLabel.frame = NSRect(x: 0, y: self.frame.size.height-(self.titleLabel.intrinsicContentSize.height+DrawingModel.unscaledConnectionTabProtrusion+DrawingModel.unscaledInnerMargin), width: self.frame.size.width, height: self.titleLabel.intrinsicContentSize.height)
            self.titleLabel.becomeFirstResponder()
        }
    }
    
    @objc func interfaceButtonPressed(_ sender: NSButton) {
        self.onInterfaceButtonPress?()
    }
    
    func closeTitleEditor() {
        self.titleLabel.resignFirstResponder()
        self.titleLabel.isHidden = true
    }
    
    func handleRename() {
        let newName = self.titleLabel.stringValue
        closeTitleEditor()
        if let id=self.id,  newName != self.metadata?.title {
            self.graphView.requestRename(node: id, to: newName)
        }
    }
    
    private func actualConnectionMetrics(forNumberOfConnections n: Int) -> (connectionSize: CGFloat, startMargin: CGFloat) {
        if n<1 { return (0, 0) }
        let gaps = (DrawingModel.unscaledConnectionMargin*CGFloat(n-1))*graphView.zoomScale
        let frameExtent = self.frame.size.width
        let availableSpace = frameExtent - gaps
        let connectionSize = min(floor(availableSpace/CGFloat(n)), maxConnectionSize*graphView.zoomScale)
        let remaining = frameExtent - (gaps + connectionSize * CGFloat(n))
        return (connectionSize, floor(remaining*0.5))
    }
    
    func inletPoint(_ index: Int) -> NSPoint {
        let (sz, margin) = self.actualConnectionMetrics(forNumberOfConnections: self.metadata?.numInlets ?? 0)
        let scale = graphView.zoomScale
        return NSPoint(
            x: margin + (sz+(DrawingModel.unscaledConnectionMargin*scale))*CGFloat(index) + sz*0.5,
            y: self.frame.size.height-DrawingModel.unscaledConnectionTabProtrusion*scale*0.5)
    }
    
    func outletPoint(_ index: Int) -> NSPoint {
        let (sz, margin) = self.actualConnectionMetrics(forNumberOfConnections: self.metadata?.numOutlets ?? 0)
        let scale = graphView.zoomScale
        return NSPoint(x: margin + (sz+DrawingModel.unscaledConnectionMargin*scale)*CGFloat(index) + sz*0.5, y: DrawingModel.unscaledConnectionTabProtrusion*scale*0.5)
    }
    
    // given n inlets/outlets and an x coordinate, does it hit one of them?
    private func hitTestConnector(number n: Int, forX x: CGFloat) -> Int? {
        guard n>0 else { return nil }
        let (sz, margin) = self.actualConnectionMetrics(forNumberOfConnections: n)
        let sl = Int(((x-margin)/sz).rounded(.down))
        if sl<0 || sl>=n { return nil }
        return sl
    }
    func regionHitTest(_ point: NSPoint) -> GraphView.NodeViewRegion? {
        if point.y < connectionTabDropDepth*graphView.zoomScale { // the outlet region
            return self.hitTestConnector(number: self.metadata?.numOutlets ?? 0, forX: point.x).map { .outlet($0) }
        } else if point.y  >= self.frame.size.height-connectionTabDropDepth { // the outlet region
            return self.hitTestConnector(number: self.metadata?.numInlets ?? 0, forX: point.x).map { .inlet($0) }
        } else {
            return .body
        }
    }
    
    func connectionsChanged() {}
    
    //MARK: drawing
    
    // All the information required to draw a node shape (not counting native controls embedded in it)
    struct DrawingModel {
        let frame: NSRect
        let title: String
        let type: OSType
        let isSelected: Bool // Perhaps replace with an enum named style or similar?
        let topTabs: [(offset: CGFloat, width: CGFloat)]?
        let bottomTabs: [(offset: CGFloat, width: CGFloat)]?
        let scale: CGFloat
        
        // The depth of the inlet/outlet tabs (width if horizontal, height if vertical)
        static let unscaledConnectionTabProtrusion: CGFloat = 4
        static let unscaledConnectionMargin: CGFloat = 2
        static let unscaledInnerMargin: CGFloat = 2
        
        var connectionTabProtrusion: CGFloat { return  Self.unscaledConnectionTabProtrusion*scale }
        var connectionMargin: CGFloat { return  Self.unscaledConnectionMargin*scale }
        var innerMargin: CGFloat { return  Self.unscaledInnerMargin*scale }

        static let titleFontSize: CGFloat = 8
        static func titleFont(forScale scale: CGFloat) -> NSFont { return NSFont.systemFont(ofSize: Self.titleFontSize*scale) }
        static let titleFont: NSFont = NSFont.systemFont(ofSize: Self.titleFontSize)
        var titleFont: NSFont  { return Self.titleFont(forScale: self.scale) }
        static let titleHeight: CGFloat = {
            return ceil(NSString(string:"Ågy,/|").size(withAttributes: [.font : Self.titleFont(forScale: 1.0)]).height)
        }()
        var titleHeight: CGFloat { return Self.titleHeight*scale }

        var outlineWidth: CGFloat {
            return scale * (self.isSelected ? 1.0 : 0.5)
        }
        
        var titleBottom: CGFloat { return frame.origin.y+frame.size.height - connectionTabProtrusion - innerMargin - titleHeight }

        /// The amount of vertical space used by the frame, tabs, title and other elements handled by the drawing code
        static var reservedHeight: CGFloat = Self.unscaledConnectionTabProtrusion + Self.unscaledInnerMargin + Self.titleHeight  + Self.unscaledInnerMargin + Self.unscaledInnerMargin + Self.unscaledConnectionTabProtrusion
        var reservedHeight: CGFloat  { return connectionTabProtrusion + innerMargin + titleHeight  + innerMargin + innerMargin + connectionTabProtrusion
        }

        
        // A path which, when stroked, will draw an outline for the node. The pen thickness is given to center the line and reduce aliasing
        // tabs are listed as a (distance from previous edge, width) tuple; if they're absent, the body fills the entirety of the bounds
        func outlinePath() -> NSBezierPath {
            let halfOutline = outlineWidth/2
            let top = frame.origin.y+frame.size.height-halfOutline
            let left = frame.origin.x+halfOutline
            let bottom = frame.origin.y+halfOutline
            let right = frame.origin.x+frame.size.width-halfOutline
            let bodyTop = top-((topTabs==nil) ? 0 : connectionTabProtrusion)
            let bodyBottom = bottom+((bottomTabs==nil) ? 0 : connectionTabProtrusion)

            // top tab points, left to right; empty if none
            let topPts: [(CGFloat, CGFloat)] = ((topTabs ?? []).reduce((frame.origin.x, [])) { (prev: (CGFloat, [(CGFloat, CGFloat)]), tab:(CGFloat, CGFloat)) -> (CGFloat, [(CGFloat, CGFloat)]) in
                let l = prev.0+tab.0+halfOutline
                let r = l+tab.1-outlineWidth
                return (r, prev.1+[ (l, bodyTop), (l, top), (r, top), (r, bodyTop) ])
            }).1
            // bottom tab points, right to left; empty if none
            let bottomPts: [(CGFloat, CGFloat)] = ((bottomTabs ?? []).reduce((frame.origin.x, [])) { (prev: (CGFloat, [(CGFloat, CGFloat)]), tab: (CGFloat, CGFloat)) -> (CGFloat, [(CGFloat, CGFloat)]) in
                // we build the list backwards, as this is drawing from right to left
                let l = prev.0+tab.0+halfOutline
                let r = l+tab.1-outlineWidth
                return (r, [(r, bodyBottom), (r, bottom), (l, bottom), (l, bodyBottom) ]+prev.1)
            }).1
            let outlinePathPts: [(CGFloat, CGFloat)] = [(left, bodyBottom), (left, bodyTop)] + topPts + [(right, bodyTop), (right, bodyBottom)] + bottomPts + [(left, bodyBottom)]
            
            let outlineBezierPath = NSBezierPath(fromLineSegmentsAsTuples: outlinePathPts)
            outlineBezierPath.lineWidth = outlineWidth
            return outlineBezierPath
        }
        
        func draw() {
            let backgroundColor  = isSelected ? NSColor.nodeBackground : NSColor.nodeBackground.muted
            let borderColor  = isSelected ? NSColor.nodeBorder : NSColor.nodeBorder.muted
            let nodeTypeColor = NSColor.forAudioUnit(ofType: type)
            let titleBackgroundColor = isSelected ? nodeTypeColor : nodeTypeColor.muted
            let titleFont = NSFont.systemFont(ofSize: 8*scale)
            
            let outlineBezierPath = self.outlinePath()

            backgroundColor.setFill()
            outlineBezierPath.fill()

            let titleNSString  = NSString(string:title)
            let maxLeftIndent: CGFloat = 0
            let rightSpaceBeforeCut: CGFloat = 4
            let titleAttr: [NSAttributedString.Key : Any] = [.font: titleFont, .foregroundColor: NSColor.nodeText]
            let titleSize = titleNSString.size(withAttributes: titleAttr)
            let leftIndent = max(0, min(frame.size.width-titleSize.width-2*innerMargin, maxLeftIndent))
            let titleTopY = frame.origin.y+frame.size.height - (topTabs==nil ? 0 : connectionTabProtrusion)
            let titleBarHeight = innerMargin + titleHeight
            let titleBottomY = titleTopY - titleBarHeight
            // the diagonal cut to the right of the title
            let cutBottomX = frame.origin.x+min(frame.size.width-1, leftIndent+titleSize.width+rightSpaceBeforeCut)
            let cutTopX = min(frame.origin.x+frame.size.width-1, cutBottomX+titleBarHeight)
            let cutTopY = titleBottomY + (cutTopX-cutBottomX)
            let titleBackgroundPath = NSBezierPath(fromLineSegmentsAsTuples: [
                (frame.origin.x, titleTopY), (frame.origin.x, titleBottomY),
            (cutBottomX, titleBottomY), (cutTopX, cutTopY), (cutTopX, titleTopY)
            ])
            titleBackgroundPath.close()
            titleBackgroundColor.setFill()
            titleBackgroundPath.fill()
            
            titleNSString.draw(at: NSPoint(x: frame.origin.x+Self.unscaledInnerMargin+leftIndent, y:frame.origin.y+frame.size.height - titleHeight - (topTabs == nil ? 0 : connectionTabProtrusion) - innerMargin), withAttributes: titleAttr)

            borderColor.setStroke()
            outlineBezierPath.stroke()
        }
    }
    
    var drawingModel: DrawingModel {
        let numInlets = self.metadata?.numInlets ?? 0
        let numOutlets = self.metadata?.numOutlets ?? 0
        let (inSize, inMargin) = self.actualConnectionMetrics(forNumberOfConnections: numInlets)
        let (outSize, outMargin) = self.actualConnectionMetrics(forNumberOfConnections: numOutlets)
        
        let topTabs = (0..<numInlets).map { ($0==0 ? inMargin : DrawingModel.unscaledConnectionMargin, inSize) }
        let bottomTabs = (0..<numOutlets).map { ($0==0 ? outMargin : DrawingModel.unscaledConnectionMargin, outSize) }
        
        return DrawingModel(frame: self.bounds, title: metadata?.title ?? " ", type: metadata?.audioComponentDescription?.componentType ?? 0, isSelected: isSelected, topTabs: topTabs, bottomTabs: bottomTabs, scale: graphView.zoomScale)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        self.drawingModel.draw()
    }
}


extension GenericGraphNodeView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        closeTitleEditor()
    }
}

