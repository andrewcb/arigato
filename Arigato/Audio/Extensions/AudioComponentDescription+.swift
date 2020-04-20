//
//  AudioComponentDescription+.swift
//  Arigato
//
//  Created by acb on 2020-04-20.
//  Copyright © 2020 acb. All rights reserved.
//

// Extensions for the AudioComponentDescription struct: more convenient initialisation, standard system-provided components, conformance to Equatable/Hashable/Codable, &c.

import Foundation
import CoreAudio
import AudioToolbox

extension AudioComponentDescription {
    
    public init(type: OSType, subType: OSType, manufacturer: OSType) {
        self.init(componentType: type, componentSubType: subType, componentManufacturer: manufacturer, componentFlags: 0, componentFlagsMask: 0)
    }
    
    public static let defaultOutput = AudioComponentDescription(type: kAudioUnitType_Output, subType: kAudioUnitSubType_DefaultOutput, manufacturer: kAudioUnitManufacturer_Apple)
    public static let genericOutput = AudioComponentDescription(type: kAudioUnitType_Output, subType: kAudioUnitSubType_GenericOutput, manufacturer: kAudioUnitManufacturer_Apple)
    public static let stereoMixer = AudioComponentDescription(type: kAudioUnitType_Mixer, subType: kAudioUnitSubType_StereoMixer, manufacturer: kAudioUnitManufacturer_Apple)
    public static let multiChannelMixer = AudioComponentDescription(type: kAudioUnitType_Mixer, subType: kAudioUnitSubType_MultiChannelMixer, manufacturer: kAudioUnitManufacturer_Apple)
    public static let dlsSynth = AudioComponentDescription(type: kAudioUnitType_MusicDevice, subType: kAudioUnitSubType_DLSSynth, manufacturer: kAudioUnitManufacturer_Apple)
    public static let speechSynthesis = AudioComponentDescription(type: kAudioUnitType_Generator, subType: kAudioUnitSubType_SpeechSynthesis, manufacturer: kAudioUnitManufacturer_Apple)
    public static let audioFilePlayer = AudioComponentDescription(type: kAudioUnitType_Generator, subType: kAudioUnitSubType_AudioFilePlayer, manufacturer: kAudioUnitManufacturer_Apple)
}

extension AudioComponentDescription: Equatable {
    // We care only about the (manufacturer, type, subtype) tuple, as the flags field is disused and likely to remain so.
    public static func ==(lhs: AudioComponentDescription, rhs: AudioComponentDescription) -> Bool {
        return lhs.componentType == rhs.componentType && lhs.componentSubType == rhs.componentSubType && lhs.componentManufacturer == rhs.componentManufacturer
    }
}

extension AudioComponentDescription: Hashable {
    public func hash(into hasher: inout Hasher) {
        self.componentType.hash(into: &hasher)
        self.componentSubType.hash(into: &hasher)
        self.componentManufacturer.hash(into: &hasher)
        self.componentFlags.hash(into: &hasher)
        self.componentFlagsMask.hash(into: &hasher)
    }
}

// MARK: encoding to/from string representation

// The line is of the form 'type:subt:manu' if  both flags and flags mask are 0, or 'type:subt:many:flags:mask" if not

extension AudioComponentDescription {
    var asString: String {
        return "\(fourCCToString(self.componentType)):\(fourCCToString(self.componentSubType)):\(fourCCToString(self.componentManufacturer))" + ((self.componentFlags==0 && self.componentFlagsMask == 0) ? "" : ":\(self.componentFlags):\(self.componentFlagsMask)")
    }
    
    struct DecodingError: Swift.Error {}
    
    init(string: String) throws {
        let parts = string.split(separator: ":")
        guard
            parts.count == 3 || parts.count == 5,
            let type = stringToFourCC(String(parts[0])),
            let subType = stringToFourCC(String(parts[1])),
            let manufacturer = stringToFourCC(String(parts[2]))
        else { throw DecodingError() }
        let flags = parts.count==5 ? UInt32(parts[3]) ?? 0 : 0
        let flagsMask = parts.count==5 ? UInt32(parts[4]) ?? 0 : 0
        self.init(componentType: type, componentSubType: subType, componentManufacturer: manufacturer, componentFlags: flags, componentFlagsMask: flagsMask)
    }
}

extension AudioComponentDescription: Codable {
    public init(from decoder: Decoder) throws {
        let ctr = try decoder.singleValueContainer()
        let str = try ctr.decode(String.self)
        try self.init(string: str)
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var ctr = encoder.singleValueContainer()
        try ctr.encode(self.asString)
    }
}

