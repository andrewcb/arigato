//
//  ARigEditorDocumentController.swift
//  ARigEditor
//
//  Created by acb on 2020-05-16.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class  ARigEditorDocumentController : NSDocumentController {
    
    /** Override presentError to present validation failures in a more informative fashion. */
    override func presentError(_ error: Error) -> Bool {
        if
            let underlyingError = ((error as? NSError)?.userInfo[NSUnderlyingErrorKey]) as? AudioSystem.Error,
            case let AudioSystem.Error.componentsNotAvailable(missing) = underlyingError
        {
            let alert = NSAlert()
            alert.messageText = "The document cannot be loaded because the following AudioUnits are unavailable:\n\n" + missing.map {
                let nodeListStr = (($0.nodeNames.count>1) ? "nodes " : "node ") + $0.nodeNames.map{"\"\($0)\"" }.joined(separator: ", ")
                return "• \($0.name) (used in \(nodeListStr))"
                
            }.joined(separator: ", ")
            alert.runModal()
            return false
        }
        return super.presentError(error)
    }
}
