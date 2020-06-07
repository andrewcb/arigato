//
//  MainWindowController.swift
//  ARigEditor
//
//  Created by acb on 2020-06-07.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class  MainWindowController: NSWindowController {
    var mainViewController: MainViewController? { return self.contentViewController as? MainViewController }
}

extension MainWindowController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        (NSApplication.shared.delegate as? AppDelegate)?.midiInputHandler.recipient = mainViewController
    }
}
