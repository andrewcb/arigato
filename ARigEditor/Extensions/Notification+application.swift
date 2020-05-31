//
//  Notification+application.swift
//  ARigEditor
//
//  Created by acb on 2020-05-29.
//  Copyright © 2020 acb. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let zoomChanged = Notification.Name((Bundle.main.bundleIdentifier ??  "") + ".zoomChanged")
}

//MARK: dictionary keys
public let kZoomLevel =  "zoom"
