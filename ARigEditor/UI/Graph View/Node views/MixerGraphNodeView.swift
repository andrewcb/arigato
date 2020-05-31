//
//  MixerGraphNodeView.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

protocol MixerTarget {
    func getLevel(forChannel ch: Int) -> Float
    func getPan(forChannel ch: Int) -> Float
    func setLevel(forChannel ch: Int, to value: Float)
    func setPan(forChannel ch: Int, to value: Float)
}

class MixerGraphNodeView: NSView, GraphNodeView {
    
    class ChannelView: NSView {
        var levelSlider: NSSlider
        var panSlider: NSSlider
                
        let innerMargin: CGFloat = 2
        let levelSliderWidth: CGFloat = 4
        let panSliderHeight: CGFloat = 4
        // the height of the section containing the pan slider; includes non-slider space around it
        let panSectionHeight: CGFloat = 20

        init(channelNumber: Int, scale: CGFloat) {
            let frame = NSRect(origin: CGPoint(x: CGFloat(channelNumber)*MixerGraphNodeView.channelSize.width*scale, y: 0), size: MixerGraphNodeView.channelSize*scale)
            levelSlider = MixerNodeSlider(role: .level)
            panSlider = MixerNodeSlider(role: .pan)
            panSlider.minValue = -1
            panSlider.maxValue = 1
            panSlider.doubleValue = 0
            super.init(frame: frame)
            self.addSubview(levelSlider)
            self.addSubview(panSlider)
            self.levelSlider.target = self
            self.levelSlider.action = #selector(self.levelChanged(_:))
            self.panSlider.target = self
            self.panSlider.action = #selector(self.panChanged(_:))
        }
                
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        var level: Float {
            get { return self.levelSlider.floatValue }
            set(v) { self.levelSlider.floatValue = v; self.levelSlider.isHidden = (v.isNaN) }
        }
        
        var pan: Float {
            get { return self.panSlider.floatValue }
            set(v) { self.panSlider.floatValue = v; self.panSlider.isHidden = (v.isNaN) }
        }
        
        var onLevelChange: ((Float)->())?
        var onPanChange: ((Float)->())?

        @objc func levelChanged(_ sender: Any) {
            self.onLevelChange?(self.level)
        }
        
        @objc func panChanged(_ sender: Any) {
            self.onPanChange?(self.pan)
        }
        
        var levelSliderFrame: NSRect {
            return NSRect(x: (self.frame.size.width-levelSliderWidth)/2, y: panSectionHeight+innerMargin, width: levelSliderWidth, height: self.frame.size.height-panSectionHeight-2*innerMargin)
        }
        var panSliderFrame: NSRect {
            return NSRect(x: innerMargin, y: (panSectionHeight-panSliderHeight)/2, width: self.frame.size.width-2*innerMargin, height: panSliderHeight)
        }
        
        override func layout() {
            super.layout()
            levelSlider.frame = self.levelSliderFrame
            panSlider.frame = self.panSliderFrame
        }
        
        override func draw(_ dirtyRect: NSRect) {
            NSColor(white: 0.5, alpha: 0.2).setFill()
            let levelRect = self.levelSliderFrame
            levelRect.fill()
            self.panSliderFrame.fill()
            NSColor(white: 0.5, alpha: 0.5).setFill()
            for i in 0...4 {
                NSRect(x: levelRect.maxX+2, y: levelRect.origin.y + floor((levelRect.size.height-2) * CGFloat(i)/4), width: 5, height: 2).fill()
            }
            
        }
    }
    
//    var scale: CGFloat = 1.0
    
    //MARK: Metrics
    
    static let channelSize = CGSize(width: 48, height: 64)
    var channelSize: CGSize { return Self.channelSize*graphView.zoomScale }
    
    // The depth of the inlet/outlet tabs (width if horizontal, height if vertical)
    var connectionTabProtrusion: CGFloat { return 4*graphView.zoomScale }
    // The depth of the tabs for the purposes of dropping links
    var connectionTabDropDepth: CGFloat { return 8*graphView.zoomScale }
    
    var connectionTabWidth: CGFloat { return 8*graphView.zoomScale }
    
    var dragBarWidth: CGFloat { return 8*graphView.zoomScale }

    //MARK: ----

    func inletPoint(_ index: Int) -> NSPoint {
        return NSPoint(
            x: channelSize.width*(CGFloat(index)+0.5),
            y: bounds.size.height-(connectionTabProtrusion*0.5))
    }
    
    func outletPoint(_ index: Int) -> NSPoint {
        return .zero
    }
    
    var graphView: GraphView
    
    var channelViews: [ChannelView] = []
    
    func connectionsChanged() {
        fetchMixerValues()
    }
    
    // Create/destroy channel views when the number of channels changes
    fileprivate func createOrDestroyChannelViews() {
        // if there are too few, create some
        if self.channelCount > self.channelViews.count {
            for i in (self.channelViews.count..<self.channelCount) {
                let newView = ChannelView(channelNumber: i, scale: graphView.zoomScale)
                newView.onLevelChange = { [weak self] v in self?.mixerTarget?.setLevel(forChannel: i, to: v) }
                newView.onPanChange = { [weak self] v in self?.mixerTarget?.setPan(forChannel: i, to: v) }
                self.addSubview(newView)
                self.channelViews.append(newView)
            }
        }
        
        // if there are too many, destroy some
        while self.channelViews.count > self.channelCount {
            guard let v = self.channelViews.popLast() else { break }
            v.removeFromSuperview()
        }
    }
    
    var id: GraphView.NodeID?
    var metadata: GraphView.NodeMetadata?  {
        didSet {
            guard let id = self.id else { return }
            self.graphView.requestResize(node: id)
            createOrDestroyChannelViews()
            self.needsDisplay = true
        }
    }
    
    var channelCount: Int { return self.metadata?.numInlets ?? 1}
    
    //MARK: interfacing with the mixer
    var mixerTarget: MixerTarget? {
        didSet {
            self.fetchMixerValues()
        }
    }
    
    fileprivate func fetchMixerValues() {
        guard let mt = self.mixerTarget else { return }
        for (i, cv) in self.channelViews.enumerated()  {
            cv.level = mt.getLevel(forChannel: i)
            cv.pan = mt.getPan(forChannel: i)
        }
    }
    
    //MARK: Node attributes
    let isSelectable: Bool = false
    let isDeletable: Bool = false
    var isSelected: Bool = false
    let canAddInlets: Bool = true

    override var intrinsicContentSize: NSSize {
        return NSSize(
            width: channelSize.width*CGFloat(channelCount),
            height: channelSize.height+dragBarWidth+connectionTabProtrusion)
    }
    
    func regionHitTest(_ point: NSPoint) -> GraphView.NodeViewRegion? {
        if point.y >= self.frame.size.height-connectionTabDropDepth {
            let channel = Int(floor(point.x / channelSize.width))
            let xc = point.x.truncatingRemainder(dividingBy: channelSize.width)
            let tabOffset = (channelSize.width-connectionTabWidth)/2
            return (xc>=tabOffset && xc<tabOffset+connectionTabWidth) ? .inlet(channel) : nil
        }
        return .body
    }
    
    init(frame frameRect: NSRect, graphView: GraphView) {
        self.graphView = graphView
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // A path which, when stroked, will draw an outline for the node. The pen thickness is given to center the line and reduce aliasing
    fileprivate func outlinePath(forLineWidth  outlineWidth: CGFloat) -> NSBezierPath {
        let inOffset = (channelSize.width - self.connectionTabWidth)/2
        let halfOutline = outlineWidth/2
        let bodyTop = self.frame.size.height-connectionTabProtrusion-halfOutline
        let top = self.bounds.size.height-halfOutline
        let left = halfOutline
        let bottom = halfOutline
        let right = self.bounds.size.width-halfOutline

        let pts: [(CGFloat, CGFloat)] = [
            (left, bottom), (left, bodyTop)] + (0..<channelCount).flatMap { (i) -> [(CGFloat, CGFloat)] in
                let tx1 = inOffset + channelSize.width*CGFloat(i) + halfOutline
                let tx2 = tx1+connectionTabWidth - outlineWidth
                return [(tx1, bodyTop),  (tx1, top), (tx2, top), (tx2, bodyTop)]
            } + [(right, bodyTop), (right, bottom), (left, bottom)]

        let outlineBezierPath = NSBezierPath(fromLineSegmentsAsTuples: pts)
        outlineBezierPath.lineWidth = outlineWidth
        return outlineBezierPath
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let backgroundColor  = self.isSelected ? NSColor.nodeBackground : NSColor.nodeBackground.muted
        //let titleFont = NSFont.systemFont(ofSize: 8)
        
        let outlineWidth: CGFloat = 0.5
        let outlineBezierPath = self.outlinePath(forLineWidth: outlineWidth)

        backgroundColor.setFill()
        outlineBezierPath.fill()
        
        NSColor.nodeBorder.muted.setStroke()
        outlineBezierPath.stroke()
    }
}
