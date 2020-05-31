//
//  CocoaExtensions.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

func +(_ a: NSPoint, _ b: NSPoint) -> NSPoint {
    return NSPoint(x: a.x+b.x, y: a.y+b.y)
}

func -(_ a: NSPoint, _ b: NSPoint) -> NSPoint {
    return NSPoint(x: a.x-b.x, y: a.y-b.y)
}

extension NSPoint {
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> NSPoint {
        return NSPoint(x: self.x.rounded(rule), y: self.y.rounded(rule))
    }
    
    func distanceFromLine(between p1: NSPoint, and p2: NSPoint) -> CGFloat {
        let d = p2-p1
        return abs(self.x*d.y - self.y*d.x + p2.x*p1.y - p2.y*p1.x) / sqrt(d.y*d.y+d.x*d.x)
    }
}

func +(_ a: NSSize, _ b: NSSize) -> NSSize {
    return NSSize(width: a.width+b.width, height: a.height+b.height)
}

func *(_ a: NSPoint, _ b: CGFloat) -> NSPoint {
    return NSPoint(x: a.x*b, y: a.y*b)
}

func *(_ a: NSSize, _ b: CGFloat) -> NSSize {
    return NSSize(width: a.width*b, height: a.height*b)
}

func max(_ a: NSSize, _ b: NSSize) -> NSSize {
    return NSSize(width: max(a.width, b.width), height: max(a.height, b.height))
}

extension NSBezierPath {
    convenience init(fromLineSegments lineSegments:[NSPoint]) {
        self.init()
        guard let first = lineSegments.first else { return }
        self.move(to: first)
        for pt in lineSegments.dropFirst() {
            self.line(to: pt)
        }
    }
    // calling both fromLineSegments: causes the typechecker to prematurely cast numbers to types other than CGFloat.
    convenience init(fromLineSegmentsAsTuples lineSegments:[(CGFloat, CGFloat)]) {
        self.init(fromLineSegments: lineSegments.map { NSPoint(x:$0.0, y:$0.1) })
    }
}
