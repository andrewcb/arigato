//
//  Diagnostics.swift
//  PyArigato
//
//  Created by acb on 2020-06-22.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation
import AudioToolbox

public class DiagGlue: NSObject {
    @objc class var availableComponents: [String] {
        AudioUnitComponent.findAll(matching: AudioComponentDescription(componentType: 0, componentSubType: 0, componentManufacturer: 0, componentFlags: 0, componentFlagsMask: 0)).map { $0.componentName ?? "-" }
    }
}

public let startup: Bool = {
    print("--- starting")
    AudioUnitComponent.findAll(matching: AudioComponentDescription(componentType: 0, componentSubType: 0, componentManufacturer: 0, componentFlags: 0, componentFlagsMask: 0)).forEach {
        print("- found component: \($0)")
    }
    return true
}()
