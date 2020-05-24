//
//  AVAudioNode+.swift
//  Arigato
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import AVFoundation

extension AVAudioNode {
    func matches(audioComponentDescription: AudioComponentDescription) -> Bool {
        return ((self as?AVAudioUnit)?.audioComponentDescription).map { $0  == audioComponentDescription } ?? false
    }
    
    var isMusicDevice: Bool {
        return ((self as? AVAudioUnit)?.audioComponentDescription.componentType).map { $0 == kAudioUnitType_MusicDevice } ?? false
    }
    
    var isSpeechSynthesizer: Bool {
        return self.matches(audioComponentDescription: .speechSynthesis)
    }
    
    var isAudioFilePlayer: Bool {
        return self.matches(audioComponentDescription: .audioFilePlayer)
    }
    
    public func speak(_ text: String) {
        guard let au = (self as? AVAudioUnit)?.audioUnit else { return }
        var chptr: SpeechChannel? = nil
        var sz: UInt32 = UInt32(MemoryLayout<SpeechChannel>.size)
        AudioUnitGetProperty(au, kAudioUnitProperty_SpeechChannel, kAudioUnitScope_Global, 0, &chptr, &sz)
        
        guard let channel = chptr else { return }
        SpeakCFString(channel, text as NSString, nil)
    }
}
