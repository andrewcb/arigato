//
//  ComponentSelectorViewController.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa
import AudioToolbox

extension NSPasteboard.PasteboardType {
    static let audioUnit = NSPasteboard.PasteboardType("com.kineticfactory.TEST.audioUnit")
}

class ComponentCellView: NSTableCellView {

    var component: AudioUnitComponent? = nil
    var zoomScale: CGFloat = 1.0

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func draw(_ dirtyRect: NSRect) {
        GenericGraphNodeView.DrawingModel(frame: NSRect(x: 8, y: 2, width: 128*zoomScale, height: self.frame.size.height-4), title: component?.componentName ?? "", type: component?.audioComponentDescription.componentType ?? 0, isSelected: false, topTabs: nil, bottomTabs: nil, scale: self.zoomScale).draw()
        

        let titleAttr: [NSAttributedString.Key : Any] = [.font: NSFont.systemFont(ofSize: 8*self.zoomScale), .foregroundColor: NSColor.nodeText]

        NSString(string:(component?.audioComponentDescription.componentType.audioUnitTypeName ?? "")).draw(
            at: NSPoint(
                x: 8+GenericGraphNodeView.DrawingModel.unscaledInnerMargin,
                y: 2+frame.size.height - (2*GenericGraphNodeView.DrawingModel.titleHeight + 3*GenericGraphNodeView.DrawingModel.unscaledInnerMargin)*zoomScale), withAttributes: titleAttr)
    }
}

extension UInt32 {
    var audioUnitTypeName: String? {
        switch(self) {
        case kAudioUnitType_Effect: return "Effect"
        case kAudioUnitType_FormatConverter: return "Format Converter"
        case kAudioUnitType_Generator: return "Generator"
        case kAudioUnitType_MIDIProcessor: return "MIDI Processor"
        case kAudioUnitType_Mixer: return "Mixer"
        case kAudioUnitType_MusicDevice: return "Music Device"
        case kAudioUnitType_MusicEffect: return "Music Effect"
        case kAudioUnitType_OfflineEffect: return "Offline Effect"
        case kAudioUnitType_Output: return "Output"
        case kAudioUnitType_Panner: return "Panner"
        default: return nil
        }
    }
}

class ComponentSelectorViewController: NSViewController {

    enum Selection {
        case component(AudioUnitComponent)
    }

    @IBOutlet weak var typeSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var instrumentsOutlineView: NSOutlineView!

    //private var hasSoundFontItem: Bool { return self.componentType == .instrument }

    enum OutlineItem {
        case manufacturer(Int)
        case component(AudioUnitComponent)
    }

    var onSelection: ((Selection)->())? = nil

    struct TypeFilterOption {
        let label: String
        let types: [UInt32]
        
        func apply(_ component: AudioUnitComponent) -> Bool {
            return types.contains(component.audioComponentDescription.componentType)
        }
    }
    
    let visibleAudioUnitTypes: Set<UInt32> = [kAudioUnitType_Generator, kAudioUnitType_MusicDevice, kAudioUnitType_MusicEffect, kAudioUnitType_Effect, kAudioUnitType_Mixer, kAudioUnitType_Panner]
    
    let typeFilterOptions: [TypeFilterOption] = [
        TypeFilterOption(label: "Inst", types: [kAudioUnitType_MusicDevice]),
        TypeFilterOption(label: "FX", types: [kAudioUnitType_Effect, kAudioUnitType_MusicEffect]),
        TypeFilterOption(label: "Gen", types: [kAudioUnitType_Generator])
    ]
    var currentTypeFilter: TypeFilterOption? {
        didSet { self.filterAvailableInstruments() }
    }
    
    private func filterAvailableInstruments() {
        self.filteredComponents = self.availableInstruments
            .filter { visibleAudioUnitTypes.contains($0.audioComponentDescription.componentType)}
            .filter  { currentTypeFilter?.apply($0) ?? true }
    }

    var availableInstruments = [AudioUnitComponent]() {
        didSet {  self.filterAvailableInstruments() }
    }
    var filteredComponents = [AudioUnitComponent]() {
        didSet {
            var d: [String:[AudioUnitComponent]] = [:]
            for inst in self.filteredComponents {
                let manufacturerName = inst.manufacturerName ?? "?"
                var a = d[manufacturerName] ?? []
                a.append(inst)
                d[manufacturerName] = a
            }
            self.instrumentsByManufacturer = d.keys.sorted().map { ($0, d[$0]!.sorted { ($0.componentName ?? "") < ($1.componentName ?? "") })}
        }
    }
    var instrumentsByManufacturer: [(String, [AudioUnitComponent])] = [] {
        didSet(prev) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let expanded: [String] = (0..<self.instrumentsOutlineView.numberOfRows).compactMap { (row:Int) -> String? in
                    let item = self.instrumentsOutlineView.item(atRow: row)
                    if self.instrumentsOutlineView.isExpandable(item) && self.instrumentsOutlineView.isItemExpanded(item),
                        let outlineItem = item as? OutlineItem,
                        case let .manufacturer(index) = outlineItem {
                        return prev[index].0
                    }
                    return nil
                }
                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    // expand blocks here
                    for row in 0..<self.instrumentsOutlineView.numberOfRows {
                        let item = self.instrumentsOutlineView.item(atRow: row)
                        if
                            let outlineItem = item as? OutlineItem,
                            case let .manufacturer(index) = outlineItem,
                            expanded.contains(self.instrumentsByManufacturer[index].0)
                        {
                            self.instrumentsOutlineView.expandItem(item)
                        }
                    }
                }
                self.instrumentsOutlineView.reloadData()
                CATransaction.commit()
            }
        }
    }
    
    private func reloadOutlinePreservingExpandedState() {
        let v = self.instrumentsByManufacturer
        self.instrumentsByManufacturer = v
    }
    
    var zoomScale: CGFloat = 1 {
        didSet(prev) {
            self.reloadOutlinePreservingExpandedState()
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleZoomNotification(_:)), name: .zoomChanged, object: nil)
        self.typeSegmentedControl.segmentCount = typeFilterOptions.count+1
        for (i,t) in typeFilterOptions.enumerated() {
            self.typeSegmentedControl.setLabel(t.label, forSegment: i+1)
        }
        self.instrumentsOutlineView.registerForDraggedTypes([.audioUnit])
        self.reloadInstruments()
    }

    func component(byDescription description: AudioComponentDescription) -> AudioUnitComponent? {
        return self.availableInstruments.first(where: { $0.audioComponentDescription == description })
    }

    private func reloadInstruments() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let s = self else { return }
            s.availableInstruments = AudioUnitComponent.findAll(matching: AudioComponentDescription(componentType: 0, componentSubType: 0, componentManufacturer: 0, componentFlags: 0, componentFlagsMask: 0))
        }
    }

    @IBAction func doubleClicked(_ sender: NSOutlineView) {
        let itemAtRow = sender.item(atRow: sender.clickedRow)
        guard let item = itemAtRow as? OutlineItem else { return }
        switch(item) {
        case .component(let component):
            self.onSelection?(.component(component))
        case .manufacturer(_):
            // The item needs to be the same reference pointer as returned by item(atRow) to match
            if sender.isItemExpanded(itemAtRow) {
                sender.collapseItem(itemAtRow)
            } else {
                sender.expandItem(itemAtRow)
            }
        }
    }
    
    @IBAction func typeSelected(_ sender: NSSegmentedControl) {
        let index = sender.indexOfSelectedItem
        print("\(sender.indexOfSelectedItem)")
        self.currentTypeFilter = index>0 ? self.typeFilterOptions[index-1] : nil
    }

    @objc func handleZoomNotification(_ notification: Notification) {
        guard let zoomLevel = notification.userInfo?[kZoomLevel] as? Int else { return }
        self.zoomScale = computeZoomScale(fromLevel: zoomLevel)
    }
}

extension ComponentSelectorViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let i2 = item, let item = i2 as? OutlineItem else {
            // top-level
            return self.instrumentsByManufacturer.count
        }
        switch(item) {
        case .manufacturer(let index): return self.instrumentsByManufacturer[index].1.count
        default: return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let ii = item, let oi = ii as? OutlineItem else {
            return OutlineItem.manufacturer(index)
        }
        switch(oi) {
        case .manufacturer(let mi): return OutlineItem.component(self.instrumentsByManufacturer[mi].1[index])
        default: fatalError()
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let oi = item as? OutlineItem, case .manufacturer(_) = oi { return true }
        else { return false }
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard case let .component(component) = item as? OutlineItem else { return nil }
        let item = NSPasteboardItem()
        item.setData(component.audioComponentDescription.asData, forType: .audioUnit)
        return item
    }
    
    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
        let dragImageSize = (NSSize(width: 64, height: 48)*self.zoomScale)
        session.enumerateDraggingItems(options: .concurrent, for: nil, classes: [NSPasteboardItem.self], searchOptions: [:]) { (draggingItem, index, stopPtr) in
            
            guard case let .component(component) = draggedItems.first as? OutlineItem else { return }

            draggingItem.setDraggingFrame(NSRect(origin: session.draggingLocation, size: dragImageSize), contents: NSImage(size: dragImageSize, flipped: false, drawingHandler: { (rect) -> Bool in
                GenericGraphNodeView.DrawingModel(
                    frame: rect,
                    title: component.componentName ?? "",
                    type: component.audioComponentDescription.componentType,
                    isSelected: false, topTabs: nil, bottomTabs: nil, scale: self.zoomScale).draw()
                return true
            }))
            
        }
    }
}

extension ComponentSelectorViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        
        guard let oi = item as? OutlineItem else { return nil }
        switch(oi) {
        case .manufacturer(let i):
            let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ManufacturerCell"), owner: self) as? NSTableCellView
            if let textField = view?.textField {
                textField.font = NSFont.systemFont(ofSize: 12*self.zoomScale)
                textField.stringValue = self.instrumentsByManufacturer[i].0
            }
            return view
        case .component(let component):
            let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ComponentCell"), owner: self) as? ComponentCellView
            view?.zoomScale = self.zoomScale
            view?.component = component
            return view
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        guard let oi = item as? OutlineItem else { return outlineView.rowHeight }

        if case .component(_) = oi {
            return 34*self.zoomScale
        }
        return outlineView.rowHeight*self.zoomScale
    }
}
