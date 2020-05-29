//
//  NodeInterfaceManager.swift
//  Arigato
//
//  Created by acb on 2020-04-26.
//  Copyright © 2020 acb. All rights reserved.
//
/// A component which keeps track of all interface components open for a specific instance of a node, enforces their unicity and removes them when the node is disposed

import Cocoa
import AVFoundation
import CoreAudioKit

class NodeInterfaceManager: NSObject {
    enum InterfaceInstance: Equatable {
        // this is an instance in a top-level window
        case window(NSWindow)
        // TODO: possibly add instances in embeddable views (for use in Playgrounds or other workbook-based systems, &c.)
        
        func close() {
            switch(self) {
            case let .window(window):  window.close()
            }
        }
    }
        
    var openNodes: [AudioSystem.NodeID:InterfaceInstance] = [:]
    
    var keystrokeRelayingTarget: NSResponder?
        
    /// A NSWindow subclass  that forwards keystrokes that reach its end of the responder chain to a specified responder; this is intended to, for example, allow the use of the computer keyboard to play MIDI notes when an instrument UI is  focussed.
    class KeystrokeRelayingWindow: NSWindow {
        var keystrokeRelayingTarget: NSResponder? = nil
        
        override func keyDown(with event: NSEvent) {
            keystrokeRelayingTarget?.keyDown(with: event)
        }
        override func keyUp(with event: NSEvent) {
            keystrokeRelayingTarget?.keyUp(with: event)
        }
    }
    
    private struct NoGUIError: Swift.Error {}
    // obtain the view controller for a unit
    private func makeAudioUnitGUIViewController(for audioUnit: AUAudioUnit) -> Future<NSViewController> {
        let promise = Promise<NSViewController>()
        audioUnit.requestViewController { maybeVC in
            if let vc = maybeVC {
                promise.complete(with: .success(vc))
            }  else {
                promise.complete(with: .failure(NoGUIError()))
            }
        }
        return promise.future
    }
    
    private func makeParameterViewController(for audioUnit: AUAudioUnit) -> Future<NSViewController> {
        let vc = NodeParameterEditorViewController()
        vc.auAudioUnit = audioUnit
        return Future.immediate(.success(vc))
    }
    
    private func createWindow(forNode node: AudioSystem.Node, preferringGUI: Bool = true) {
        guard
            let auAudioUnit = (node.avAudioNode as? AVAudioUnit)?.auAudioUnit
        else { return }
        
        struct GUINotSelectedError: Swift.Error { }
        
        let guiFuture: Future<NSViewController> = preferringGUI ? self.makeAudioUnitGUIViewController(for: auAudioUnit) : .immediate(.failure(GUINotSelectedError()))
        let future = guiFuture.orElse(self.makeParameterViewController(for: auAudioUnit))
        future.onCompletion { result in
            switch(result) {
            case .success(let vc):
                let cvc = NodeInterfaceContainerViewController()
                cvc.view.frame = NSRect(origin: .zero, size: vc.view.bounds.size)
                cvc.graphicalViewController = vc
                let window = KeystrokeRelayingWindow(contentViewController: cvc)
                window.keystrokeRelayingTarget = self.keystrokeRelayingTarget
                window.delegate = self
                window.title = node.name
                window.makeKeyAndOrderFront(nil)
                self.openNodes[node.id] = .window(window)
            case .failure(_):
                print("No view controller for AudioUnit")
                return
            }
        }
    }
    
    func openWindow(forNode node: AudioSystem.Node, preferringGUI: Bool = true) {
        if case let .window(window) = self.openNodes[node.id] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        self.createWindow(forNode: node, preferringGUI: preferringGUI)
    }
    
    func closeInterfaces(forNodeWithID id: AudioSystem.NodeID) {
        openNodes[id]?.close()
        openNodes[id] = nil
    }
    
    func closeAll() {
        openNodes.values.forEach { $0.close() }
        openNodes.removeAll()
    }
}

extension NodeInterfaceManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
    }
}
