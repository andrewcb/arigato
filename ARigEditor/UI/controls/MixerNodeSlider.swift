//
//  MixerNodeSlider.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class MixerNodeSlider: NSSlider {
    enum SliderRole {
        case level
        case pan
    }
    
    let role: SliderRole
    
    init(frame frameRect: NSRect = .zero, role: SliderRole) {
        self.role = role
        super.init(frame: frameRect)
        self.cell = (role == .level) ? Self.LevelSliderCell() : Self.PanSliderCell()
        self.isVertical = (role == .level)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class LevelSliderCell: NSSliderCell {
        override var cellSize: NSSize { return NSSize(width: 5, height: 3) }
        
        override func drawKnob(_ knobRect: NSRect) {
            NSColor.black.setFill()
            knobRect.fill()
        }
        
        override func knobRect(flipped: Bool) -> NSRect {
            guard let size = self.controlView?.frame.size else { return .zero }
            let thickness: CGFloat = 7.0
            let extent = size.height - thickness
            let off = extent * (1.0 - CGFloat(self.doubleValue / self.maxValue))
            return NSRect(x: (size.width-thickness)/2, y: off, width: thickness, height: 1.0)
        }
    }
    
    class PanSliderCell: NSSliderCell {
        override var cellSize: NSSize { return NSSize(width: 3, height: 5) }
        
        override func drawKnob(_ knobRect: NSRect) {
            NSColor.black.setFill()
            knobRect.fill()
        }
        
        override func knobRect(flipped: Bool) -> NSRect {
            guard let size = self.controlView?.frame.size else { return .zero }
            let thickness: CGFloat = 7.0
            let extent = size.width - thickness
            let off = extent * (CGFloat((self.doubleValue+1.0) / (self.maxValue - self.minValue)))
            return NSRect(x: off, y: (size.height-thickness)/2, width: 1.0, height: thickness)
        }
    }

}
