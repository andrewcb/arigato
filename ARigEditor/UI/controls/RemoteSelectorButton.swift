//
//  RemoteSelectorButton.swift
//  ARigEditor
//
//  Created by acb on 2020-12-22.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class RemoteSelectorButton: NSView {
    enum State {
        case inactive
        case active(onPort:Int)
        case error
    }
    
    override var intrinsicContentSize: NSSize  { return NSSize(width: 20, height: 20)}
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(self.clicked))
        self.addGestureRecognizer(recognizer)
    }
    
    var state: State  = .inactive {
        didSet {
            self.needsDisplay = true
        }
    }
    
    var onClick: (()->())? = nil
    
    private var drawRays: Bool = false
    
    /// Flash the display to indicate incoming commands
    func indicateTraffic() {
        // TODO
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // TODO: draw an icon as appropriate
        let ctx = NSGraphicsContext.current
        //NSPoint(x: 0, y: 0)
        let x1=0, y1=0, x2=self.frame.size.width-1, y2=self.frame.size.height-1, mx=x2/2, my=y2/2
        let color: NSColor // = (isActive ? NSColor.black : NSColor.lightGray)
        switch(self.state) {
        case .inactive: color = .lightGray
        case .active: color = .black
        case .error: color = .red
        }
        color.setStroke()
        color.setFill()
        let path  = NSBezierPath()
        let baseSize: CGFloat = 4
        let topClearance: CGFloat = 6
        
        path.move(to: NSPoint(x: mx, y: baseSize))
        path.line(to: NSPoint(x: mx-baseSize/2, y:0))
        path.line(to: NSPoint(x: mx+baseSize/2, y:0))
        path.line(to: NSPoint(x: mx, y: baseSize))
        path.fill()
        path.move(to: NSPoint(x: mx, y: baseSize))
        path.line(to: NSPoint(x: mx, y: y2-topClearance))
        
        //path.appendArc(withCenter: NSPoint(x:mx, y:y2-topClearance), radius: topClearance, startAngle: -45, endAngle: 225)
        
        // draw the rays
        
        if drawRays {
            let numRays = 5
            let startAngle: CGFloat = .pi/4
            let endAngle = .pi*2  - startAngle
            let incr = (endAngle-startAngle)/CGFloat(numRays-1)
            
            for i in (0..<numRays) {
                let θ = startAngle + incr*CGFloat(i)
                let x = sin(θ)
                let y = -cos(θ)
                path.move(to: NSPoint(x: mx+x*3, y: y2-topClearance+y*3))
                path.line(to: NSPoint(x: mx+x*6, y: y2-topClearance+y*6))
            }
        }
                
        path.stroke()
        
        path.removeAllPoints()
        
        path.appendOval(in: NSRect(x: mx-1, y:y2-topClearance-1, width:2, height:2))
        path.fill()
        
        if case let .active(onPort: port) = self.state {
            let str = NSString(string:"\(port)")
            str.draw(
                in: NSRect(x: 0, y:0, width: self.frame.size.width, height: self.frame.size.height/2),
                withAttributes: [
                    NSAttributedString.Key.font : NSFont.systemFont(ofSize: 6),
                    NSAttributedString.Key.backgroundColor: NSColor.white
            ])
            
        }
    }
    
    @objc func clicked(_ recognizer: NSClickGestureRecognizer) {
        self.onClick?()
    }
}
