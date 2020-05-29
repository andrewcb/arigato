//
//  NodeInterfaceContainerViewController.swift
//  Arigato
//
//  Created by acb on 2020-05-28.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class NodeInterfaceContainerViewController: NSViewController {
    let containerView = NSView()
    
    var graphicalViewController: NSViewController? {
        didSet(prev) {
            if let prev = prev {
                prev.view.removeFromSuperview()
                prev.removeFromParent()
            }
            if let gvc = self.graphicalViewController {
                self.addChild(gvc)
                self.containerView.addSubview(gvc.view)
                gvc.view.frame = self.containerView.bounds
                gvc.view.autoresizingMask = [.width, .height]
            }
        }
    }
    
    override func loadView() {
        self.view = NSView()
        
        self.view.addSubview(self.containerView)
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.topAnchor.anchorWithOffset(to: self.containerView.topAnchor).constraint(equalToConstant: 0).isActive = true
        self.view.bottomAnchor.anchorWithOffset(to: self.containerView.bottomAnchor).constraint(equalToConstant: 0).isActive = true
        self.view.leadingAnchor.anchorWithOffset(to: self.containerView.leadingAnchor).constraint(equalToConstant: 0).isActive = true
        self.view.trailingAnchor.anchorWithOffset(to: self.containerView.trailingAnchor).constraint(equalToConstant: 0).isActive = true
    }
    
}
