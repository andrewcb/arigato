//
//  NSColor+application.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa
import AudioToolbox

fileprivate func isDarkColorScheme() -> Bool {
    let textBrightness = NSColor.textColor.usingColorSpace(.deviceGray)?.whiteComponent ?? 0
    return textBrightness > 0.5
}

extension NSColor {
    static let nodeBackground = NSColor(white: isDarkColorScheme() ? 0.5 : 0.8, alpha: 1.0)
    static let nodeText = NSColor.textColor //NSColor(white: isDarkMode() : 0.05, alpha: 1.0)
    static let nodeBorder = isDarkColorScheme() ? NSColor(white: 0.8, alpha: 1.0) : NSColor.black
    
    static func forAudioUnit(ofType type: OSType) -> NSColor {
        let typeHueMap: [OSType: CGFloat] = [
        kAudioUnitType_Generator: 0.175,
        kAudioUnitType_MusicDevice: 0.2,
        kAudioUnitType_MusicEffect: 0.3,
        kAudioUnitType_Effect: 0.5,
        kAudioUnitType_FormatConverter: 0.55,
        kAudioUnitType_Panner: 0.66,
        kAudioUnitType_Mixer: 0.9
        ]
        guard let hue = typeHueMap[type] else { return NSColor.lightGray }
        return NSColor(hue: hue, saturation: 1.0, brightness: isDarkColorScheme() ? 0.7 : 1.0, alpha: 1.0)
    }
    
    var muted: NSColor {
        guard let cs = self.usingColorSpace(.genericRGB) else { return self.blended(withFraction: 0.2, of: .lightGray) ?? self }
        return NSColor(
            hue: cs.hueComponent,
            saturation: cs.saturationComponent*0.9,
            brightness: (cs.brightnessComponent*0.5)+(isDarkColorScheme() ? 0.1 : 0.4),
            alpha: cs.alphaComponent)
    }
}
