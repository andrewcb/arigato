//
//  AppDelegate.swift
//  ARigEditor
//
//  Created by acb on 2020-04-24.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let documentController = ARigEditorDocumentController()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    //MARK: zoom/scale
    
    // this is mapped to an exponential function; i.e., scale(z) =~ B^z, and z=0 is 1.0
    var zoomLevel: Int = 0  {
        didSet {
            NotificationCenter.default.post(name: .zoomChanged, object: self, userInfo: [kZoomLevel: zoomLevel])
            // send a notification here
        }
    }
    @IBAction func zoomIn(_ sender: Any) {
        self.zoomLevel += 1
    }

    @IBAction func zoomOut(_ sender: Any) {
        self.zoomLevel -= 1

    }

    @IBAction func actualSize(_ sender: Any) {
        self.zoomLevel = 0

    }
}

