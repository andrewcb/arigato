//
//  AudioComponentDescriptionTests.swift
//  ArigatoTests
//
//  Created by acb on 2020-04-21.
//  Copyright © 2020 acb. All rights reserved.
//

import XCTest
@testable import Arigato
import CoreAudio
import AudioToolbox

class AudioComponentDescriptionTests: XCTestCase {

    func testConstructFromString() {
        XCTAssertEqual(try AudioComponentDescription(string:"abcd:efgh:\\x01\\xffab"), AudioComponentDescription(componentType: 0x61626364, componentSubType: 0x65666768, componentManufacturer: 0x01ff6162, componentFlags: 0, componentFlagsMask: 0))
        XCTAssertEqual(try AudioComponentDescription(string:"abcd:efgh:\\x01\\xffab:5:7"), AudioComponentDescription(componentType: 0x61626364, componentSubType: 0x65666768, componentManufacturer: 0x01ff6162, componentFlags: 5, componentFlagsMask: 7))
    }
    
}
