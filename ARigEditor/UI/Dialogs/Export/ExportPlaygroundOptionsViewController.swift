//
//  ExportPlaygroundOptionsViewController.swift
//  ARigEditor
//
//  Created by acb on 2020-05-23.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class ExportPlaygroundOptionsViewController: NSViewController {
    
    // Options governing the process of exporting
    struct ActionOptions {
        enum OnCompletion: String, CaseIterable {
            case doNothing = "Do nothing"
            case showInFinder = "Show in Finder"
            case openInXcode = "Open in Xcode"
        }
        let onCompletion: OnCompletion
    }
    
    var onConfirm: ((PlaygroundExporter.Options, ActionOptions)->())?
    
    @IBOutlet var includeSampleCodeCheckBox: NSButton!
    @IBOutlet var onCompletionPopUp: NSPopUpButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        onCompletionPopUp.removeAllItems()
        for item in ActionOptions.OnCompletion.allCases {
            onCompletionPopUp.addItem(withTitle: item.rawValue)
        }
    }
    
    var formatOptions: PlaygroundExporter.Options {
        return PlaygroundExporter.Options(includeSampleCode: self.includeSampleCodeCheckBox.intValue != 0)
    }
    var actionOptions: ActionOptions {
        return ActionOptions(
            onCompletion: ActionOptions.OnCompletion(rawValue:onCompletionPopUp.itemTitle(at: onCompletionPopUp.indexOfSelectedItem)) ?? .doNothing
        )
    }
    
    @IBAction func nextPressed(_ sender: Any) {
        self.presentingViewController?.dismiss(self)
        self.onConfirm?(self.formatOptions, self.actionOptions)
    }
    
    @IBAction func cancelPressed(_ sender: Any) {
        self.presentingViewController?.dismiss(self)
    }
}
