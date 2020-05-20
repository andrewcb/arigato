//
//  MIDIComputerKeyboardView.swift
//  ARigEditor
//
//  Created by acb on 2020-05-16.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

protocol MIDIComputerKeyboardStatusSource {
    func keyIsPressed(_ index: Int) -> Bool
    var octave: Int { get }
    var velocity: UInt8 { get }
}

class MIDIComputerKeyboardView: NSView {
    
    /*
     The view is divided into a grid of columns; each key takes up two columns; white notes start on an even column, and black notes on an odd column.
     */
    
    var keyboardStatusSource: MIDIComputerKeyboardStatusSource? = nil {
        didSet {
            self.refresh()
        }
    }
    var keyCaps: [String] = [] {
        didSet {
            self.refresh()
        }
    }
    
    var numColumns: Int = 19
    var columnWidth: CGFloat { return floor(min(self.frame.size.width / CGFloat(numColumns), self.frame.size.height*0.25)) }
    
    var blackWidthRatio: CGFloat = 0.75
    var blackHeightRatio: CGFloat = 0.7
    
    let whiteKeyInactiveColour =  NSColor(white: 0.75, alpha: 1)
    let blackKeyInactiveColour =  NSColor(white: 0.5, alpha: 1)
    let activeColour = NSColor(deviceHue: 0.02, saturation: 1.0, brightness: 1.0, alpha: 0.7)
    let highlightLineColour =  NSColor(white: 1.0, alpha: 0.2)
    let shadowLineColour = NSColor(white: 0.0, alpha: 0.2)
    
    public func refresh() {
        self.setNeedsDisplay(self.bounds)
    }
        
    private func drawWhiteKey(atColumn column: Int, active: Bool, leftCutout: Bool, rightCutout: Bool) {

        let backingScaleFactor = self.window?.screen?.backingScaleFactor ?? 1.0
        let pixelWidth = 1/backingScaleFactor
        let outlineWidth: CGFloat = 1
        let halfOutline = outlineWidth *  0.5
        let highlightWidth: CGFloat = 1
        let hw2 = highlightWidth/2
        let left = CGFloat(column)*columnWidth + pixelWidth
        let right = left + 2*columnWidth - pixelWidth
        let bottom: CGFloat = 0 + pixelWidth
        let top = self.frame.size.height - pixelWidth
        let mid  = floor(self.frame.size.height * (1.0-blackHeightRatio))
        let leftInsetX = left + floor((blackWidthRatio)*columnWidth) + pixelWidth
        let rightInsetX = right - floor((blackWidthRatio)*columnWidth) - 2*pixelWidth
        
        let leftside: [(CGFloat, CGFloat)] = [(left, bottom)] +
            (leftCutout ? [(left, mid), (leftInsetX, mid), (leftInsetX, top)] : [(left,  top)])
        let topright =  [(rightCutout ? rightInsetX : right,  top)]
        
        let wholeOutline = leftside + topright + (rightCutout ? [(rightInsetX, mid), (right,  mid)] : []) + [(right, bottom), (left, bottom)]
        
        let outlineBezierPath = NSBezierPath(fromLineSegmentsAsTuples: wholeOutline)
        (active ? activeColour : whiteKeyInactiveColour).setFill()
        outlineBezierPath.fill()
        
        let highlightBezierPath1 = NSBezierPath(fromLineSegmentsAsTuples:
            [(left+hw2,  bottom+hw2)] +
                (leftCutout  ? [ (left+hw2, mid-hw2), (leftInsetX+hw2, mid-hw2), (leftInsetX+hw2, top-hw2)] : [ (left+hw2, top-hw2)]) +
                [((rightCutout ? rightInsetX : right)-hw2, top-hw2)])
        highlightLineColour.setStroke()
        highlightBezierPath1.stroke()

        if rightCutout {
            NSBezierPath(fromLineSegmentsAsTuples: [(rightInsetX-hw2, mid-hw2), (right-hw2, mid-0.5)]).stroke()
        }

        let shadowBezierPath = NSBezierPath(fromLineSegmentsAsTuples: [ (rightCutout ? (right-0.5, mid-0.5) : (right-hw2, top-hw2)) , (right-hw2, bottom+hw2), (left+hw2, bottom+hw2)])
        shadowLineColour.setStroke()
        shadowBezierPath.stroke()

        if rightCutout {
            NSBezierPath(fromLineSegmentsAsTuples: [(rightInsetX-hw2, top-hw2),(rightInsetX-hw2, mid-hw2)]).stroke()
        }
        
    }
    
    func columnToKey(_ col: Int) -> Int {
        let inOct = col%14
        return (col/14)*12 + (inOct>4 ? inOct-1 : inOct)
    }
    
    func keyToColumn(_ key: Int) -> Int {
        let inOct = key%12
        return (key/12)*14 + (inOct>4 ? inOct+1 : inOct)
    }
    
    private func drawBlackKey(atColumn column: Int, active: Bool) {
        let backingScaleFactor = self.window?.screen?.backingScaleFactor ?? 1.0
        let pixelWidth = 1/backingScaleFactor
        let outlineWidth: CGFloat = 1
        let halfOutline = outlineWidth * 0.5
        let highlightWidth: CGFloat = 1
        let hw2 = highlightWidth/2
        let insetAmount = floor(columnWidth*(1-blackWidthRatio))
        let left = CGFloat(column)*columnWidth + insetAmount + pixelWidth
        let right = left + 2*columnWidth - 2*insetAmount - 1
        let top = self.frame.size.height - pixelWidth
        let bottom  = floor(self.frame.size.height * (1.0-blackHeightRatio)) + pixelWidth

        let outlineBezierPath = NSBezierPath(fromLineSegmentsAsTuples: [
            (left, bottom), (left, top), (right, top), (right, bottom)
        ])
        (active ? activeColour : blackKeyInactiveColour).setFill()
        outlineBezierPath.fill()
        
        let highlightBezierPath  = NSBezierPath(fromLineSegmentsAsTuples: [
        (left+hw2, bottom+hw2), (left+hw2, top-hw2), (right-hw2, top-hw2)])
        highlightLineColour.setStroke()
        highlightBezierPath.stroke()

        let shadowBezierPath = NSBezierPath(fromLineSegmentsAsTuples: [
            (right-hw2, top-hw2), (right-hw2, bottom+hw2), (left+hw2, bottom+hw2)
        ])
        shadowLineColour.setStroke()
        shadowBezierPath.stroke()

    }
    
    private func drawLabel(_ text: String, forColumn col: Int) {
        let isBlack = (col%2)==1
        let nsstring = NSString(string:text)
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: 1, height: -1)
        shadow.shadowColor = NSColor(white: 1.0, alpha: 0.5)
        let attributes: [NSAttributedString.Key : Any] = [NSAttributedString.Key.font :  NSFont.systemFont(ofSize: 8), NSAttributedString.Key.shadow : shadow ]
        let w = nsstring.size(withAttributes: attributes).width
        nsstring.draw(at: NSPoint(x: CGFloat(col)*columnWidth + (2*columnWidth-w)/2, y: (isBlack ? self.frame.size.height*(1-self.blackHeightRatio) : 0)+1 ), withAttributes: attributes)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        print("height = \(frame.size.height); columnWidth = \(columnWidth)")
        
//        NSColor(deviceHue: 0.5, saturation: 1.0, brightness: 0.5, alpha: 1.0).setFill()
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: self.columnWidth*CGFloat(self.numColumns), height: self.frame.size.height).fill()
        
        // white
        for i in 0..<9 {
            let col = i*2
            let octpos = i%7
            drawWhiteKey(atColumn: col, active: keyboardStatusSource?.keyIsPressed(columnToKey(col)) ?? false, leftCutout: (octpos != 0 && octpos != 3), rightCutout: (octpos != 2 && octpos != 6))
        }
        drawWhiteKey(atColumn: 18, active: false, leftCutout: true, rightCutout: false)
        
        for i in [0,1,3,4,5,7,8] {
            let col = 1+(i*2)
            drawBlackKey(atColumn: col, active: keyboardStatusSource?.keyIsPressed(columnToKey(col)) ?? false)
        }

        for (key, label) in self.keyCaps.enumerated() {
            self.drawLabel(label, forColumn: keyToColumn(key))
        }

    }
}
