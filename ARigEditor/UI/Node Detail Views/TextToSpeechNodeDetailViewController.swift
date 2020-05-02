//
//  TextToSpeechNodeDetailViewController.swift
//  ARigEditor
//
//  Created by acb on 2020-05-03.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa

class TextToSpeechNodeDetailViewController: NSViewController {
    @IBOutlet var inputTextField: KeyboardCommittableTextField!
    
    var textSubmitHandler: ((String)->())?
    
    override func viewDidLoad() {
        inputTextField.editCompletionHandler = { (commit) in
            if commit { self.textSubmitHandler?(self.inputTextField.stringValue) }
        }
    }
}
