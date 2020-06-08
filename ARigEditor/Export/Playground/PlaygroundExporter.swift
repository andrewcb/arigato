//
//  PlaygroundExporter.swift
//  ARigEditor
//
//  Created by acb on 2020-05-23.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

class PlaygroundExporter {
    struct Options {
        let includeSampleCode: Bool
    }
    
    private class func fileName(forDocument doc: ARigDocument) -> String {
        return (doc.fileURL?.lastPathComponent).map {  $0.hasSuffix(".arig") ? String($0.dropLast(5)) : $0  } ?? "audioSetup"
    }
    
    private class func playgroundSource(forDocument doc: ARigDocument, options: Options) -> String {
        let arigName = fileName(forDocument: doc)
        
        let audioSystem = doc.audioSystem
        
        let instName =  options.includeSampleCode ? (audioSystem.musicDeviceIDs.first).flatMap { audioSystem.node(byId: $0)?.name } : nil
        let speechName = options.includeSampleCode ? (audioSystem.speechSynthesizerIDs.first).flatMap { audioSystem.node(byId: $0)?.name } : nil

        // TODO: maybe put this into some sort of templated file in the resources?
        let prologue = """
            import Foundation
            import AVFoundation
            import PlaygroundSupport
                    
            let arig = try ARig(fromResource: "\(arigName)")
            
            """
        
        let instSetup = instName.map { (instName) in """
            let instrument = arig.midiInstrument(byName: "\(instName)")
            
            """
        } ?? ""
        
        let speechSetup = speechName.map { (speechName) in """
            let speech = arig.audioUnit(byName: "\(speechName)")
            
            """
        } ?? ""
        
        let playCode: String
        if instName != nil || speechName != nil {
            let instPlayCode = instName.map { _ in
                """
                    // strum a (CMaj7) chord, holding the last note longer
                    for note in [60, 64, 67, 71, 72] {
                        instrument?.play(note: UInt8(note), withVelocity: 90, onChannel: 0, forDuration: (note == 72) ? 0.8 : 0.2)
                        sleep(for: 0.2)
                    }
                    sleep(for:0.4)

                """
            } ?? ""
            let speechPlayCode = speechName.map { _ in
                """
                    speech?.speak("Can you hear me?")
                    sleep(2)

                """
            }  ?? ""
            playCode = """
            
            DispatchQueue.global().async {
            \(instPlayCode)
            \(speechPlayCode)
                PlaygroundPage.current.finishExecution()
            }
            
            """
        } else {
            playCode = ""
        }
                
        let epilogue = options.includeSampleCode ? """
            PlaygroundPage.current.needsIndefiniteExecution = true

            """ : ""
        
        
        return prologue + instSetup + speechSetup + playCode + epilogue
    }
    
    class func export(_ doc: ARigDocument, toURL url: URL, withOptions options: Options) throws {
        let fileManager = FileManager.default
        let resourceData = try doc.data(ofType: "arig")
        let arigName = fileName(forDocument: doc)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(atPath: url.path)
        }
        try fileManager.copyItem(at: Bundle.main.resourceURL!.appendingPathComponent("Export Templates/Playground"), to: url)
        try fileManager.createDirectory(at: url.appendingPathComponent("Resources"), withIntermediateDirectories: true, attributes: nil)
        fileManager.createFile(atPath: url.appendingPathComponent("Contents.swift").path, contents: playgroundSource(forDocument: doc, options: options).data(using: .utf8)!, attributes: nil)
        fileManager.createFile(atPath: url.appendingPathComponent("Resources/\(arigName).arig").path, contents: resourceData, attributes: nil)

    }
}
