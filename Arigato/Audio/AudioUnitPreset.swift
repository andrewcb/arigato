//
//  AudioUnitPreset.swift
//  Arigato
//
//  Created by acb on 2020-04-21.
//  Copyright © 2020 acb. All rights reserved.
//
//  A helper object for encapsulating the serialised state of an AudioUnit

import Foundation
import AudioToolbox
import AVFoundation

public struct AudioUnitPreset {

    public let propertyList: [String:Any]

    public enum Error: Swift.Error {
        case malformedData(String)
        case badName
    }

    // convenience function for constructing from a resource in a bundle

    public static func fromResource(named name: String, inBundle bundle: Bundle = .main) throws -> AudioUnitPreset {
        guard let url = Bundle.main.url(forResource: name, withExtension: "aupreset") else { throw Error.badName }
        return try AudioUnitPreset(url: url)
    }

    // initialise it from a .aupreset file
    public init(path: String) throws {
        try self.init(url: URL(fileURLWithPath: path))
    }
    public init(url: URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(data: data)
    }
    
    public init(data: Data) throws {
        guard let pl = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String:Any] else { throw Error.malformedData("Not a property list") }
        try self.init(propertyList: pl)
    }
    
    public init(propertyList pl: [String:Any]) throws {
        guard
            pl["type"] as? OSType != nil,
            pl["subtype"] as? OSType != nil,
            pl["manufacturer"] as? OSType != nil
            else { throw Error.malformedData("One or more of (type, subtype, manufacturer) is missing") }
        
        self.propertyList = pl
    }
    
    // synthesise a bare-bones AudioUnitPreset from an AudioComponentDescription; this will not actually do anything more than load the component and leave it in its default state, though it is guaranteed to produce a valid AudioUnitPreset for any AudioComponentDescription; it may be used if a unit, for some reason, will not return a valid ClassInfo
    public static func makeWithComponentOnly(from desc: AudioComponentDescription) -> AudioUnitPreset {
        return try! AudioUnitPreset(propertyList: [
            "type" : desc.componentType,
            "subtype": desc.componentSubType,
            "manufacturer": desc.componentManufacturer
        ])
    }
    
    var type: OSType { return self.propertyList["type"] as! OSType }
    var subtype: OSType { return self.propertyList["subtype"] as! OSType }
    var manufacturer: OSType { return self.propertyList["manufacturer"] as! OSType }
    public var audioComponentDescription: AudioComponentDescription {
        return AudioComponentDescription(
            componentType: self.type,
            componentSubType: self.subtype,
            componentManufacturer: self.manufacturer,
            componentFlags: 0, componentFlagsMask: 0)
    }
    
    public func asData() throws -> Data {
        return try PropertyListSerialization.data(fromPropertyList: self.propertyList, format: PropertyListSerialization.PropertyListFormat.xml, options: 0)
    }
}

extension AudioUnitPreset {
    func loadAudioUnit(_ callback: @escaping (Result<AVAudioUnit, Swift.Error>)->()) {
        AVAudioUnit.instantiate(with: self.audioComponentDescription, options: .loadOutOfProcess) { (unit, err) in
            guard let unit = unit else {
                if let err = err { callback(.failure(err)) }
                return
            }
            unit.auAudioUnit.fullState = self.propertyList
            callback(.success(unit))
        }
    }
}
