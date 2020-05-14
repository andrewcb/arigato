//
//  AudioSystemSerialisationTests.swift
//  ArigatoTests
//
//  Created by acb on 2020-05-14.
//  Copyright © 2020 acb. All rights reserved.
//

import XCTest
import AudioToolbox
@testable import Arigato

class AudioSystemSerialisationTests: XCTestCase {
    
    let mockValidationOracle = { (acd: AudioComponentDescription) -> Bool in
        let mockValidComponents = Set(arrayLiteral: "aufx:fx01:acme", "aufx:fx02:ajax", "aumu:syn1:ajax")
        return mockValidComponents.contains(acd.asString)
    }

    func testValidateHappyPath() {
        let input = AudioSystem.Snapshot(
            nodes: [
                AudioSystem.Node.Snapshot(id: 2, name: "effect", serialisedState: nil),
                AudioSystem.Node.Snapshot(id: 3, name: "inst", serialisedState: nil),
                AudioSystem.Node.Snapshot(id: 4, name: "effect", serialisedState: nil),
                AudioSystem.Node.Snapshot(id: 5, name: "effect", serialisedState: nil),
                AudioSystem.Node.Snapshot(id: 6, name: "inst", serialisedState: nil)
            ],
            manifest: [
                AudioSystem.Snapshot.ManifestItem(name: "FX01", manufacturer: "Acme", audioComponentDescription: try! AudioComponentDescription(string: "aufx:fx01:acme"), nodes: [2, 5]),
                AudioSystem.Snapshot.ManifestItem(name: "FX02", manufacturer: "Ajax", audioComponentDescription: try! AudioComponentDescription(string: "aufx:fx02:ajax"), nodes: [4]),
                AudioSystem.Snapshot.ManifestItem(name: "SYN1", manufacturer: "Ajax", audioComponentDescription: try! AudioComponentDescription(string: "aumu:syn1:ajax"), nodes: [3, 6])
            ],
            connections: [
                AudioSystem.Connection(from: (3, 0), to: (2, 0)),
                AudioSystem.Connection(from: (2, 0), to: (1, 0)),
                AudioSystem.Connection(from: (6, 0), to: (4, 0)),
                AudioSystem.Connection(from: (4, 0), to: (5, 0)),
                AudioSystem.Connection(from: (5, 0), to: (1, 0))
            ])
        XCTAssertNil(input.validate(self.mockValidationOracle))
    }

    func testValidateFail() {
        let input = AudioSystem.Snapshot(
            nodes: [
                AudioSystem.Node.Snapshot(id: 2, name: "effect", serialisedState: nil),
                AudioSystem.Node.Snapshot(id: 3, name: "inst", serialisedState: nil),
                AudioSystem.Node.Snapshot(id: 4, name: "argh", serialisedState: nil),
                AudioSystem.Node.Snapshot(id: 5, name: "blah", serialisedState: nil),
                AudioSystem.Node.Snapshot(id: 6, name: "urgh", serialisedState: nil)
            ],
            manifest: [
                AudioSystem.Snapshot.ManifestItem(name: "FX01", manufacturer: "Acme", audioComponentDescription: try! AudioComponentDescription(string: "aufx:fx01:acme"), nodes: [2]),
                AudioSystem.Snapshot.ManifestItem(name: "Bogus1", manufacturer: "BogoCorp", audioComponentDescription: try! AudioComponentDescription(string: "aufx:bg01:bogo"), nodes: [4, 5]),
                AudioSystem.Snapshot.ManifestItem(name: "SYN1", manufacturer: "Ajax", audioComponentDescription: try! AudioComponentDescription(string: "aumu:syn1:ajax"), nodes: [3]),
                AudioSystem.Snapshot.ManifestItem(name: "Bogus2", manufacturer: "BogoTech", audioComponentDescription: try! AudioComponentDescription(string: "aumu:bg02:bgtc"), nodes: [6])
            ],
            connections: [
                AudioSystem.Connection(from: (3, 0), to: (2, 0)),
                AudioSystem.Connection(from: (2, 0), to: (1, 0)),
                AudioSystem.Connection(from: (6, 0), to: (4, 0)),
                AudioSystem.Connection(from: (4, 0), to: (5, 0)),
                AudioSystem.Connection(from: (5, 0), to: (1, 0))
            ])
        XCTAssertEqual(input.validate(self.mockValidationOracle), AudioSystem.Error.componentsNotAvailable([
            (name: "Bogus1", manufacturer: "BogoCorp", audioComponentDescription: try! AudioComponentDescription(string: "aufx:bg01:bogo"), nodeNames: ["argh", "blah"]),
            (name: "Bogus2", manufacturer: "BogoTech", audioComponentDescription: try! AudioComponentDescription(string: "aumu:bg02:bgtc"), nodeNames: ["urgh"]),
        ]))

    }

}
