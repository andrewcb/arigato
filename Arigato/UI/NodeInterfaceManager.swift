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
    
    private func createWindow(forNode node: AudioSystem.Node) {
        guard
            let auAudioUnit = (node.avAudioNode as? AVAudioUnit)?.auAudioUnit
        else { return }
        auAudioUnit.requestViewController { vc in
            guard let vc = vc else { return }
            let window = NSWindow(contentViewController: vc)
            window.delegate = self
            window.makeKeyAndOrderFront(nil)
            self.openNodes[node.id] = .window(window)
        }
    }
    
    func openWindow(forNode node: AudioSystem.Node) {
        if case let .window(window) = self.openNodes[node.id] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        self.createWindow(forNode: node)
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
        guard
            let window = notification.object as? NSWindow,
            let id = (self.openNodes.first { $0.value == InterfaceInstance.window(window) }).map({ $0.key })
        else { return }
        openNodes[id] = nil
    }
}
