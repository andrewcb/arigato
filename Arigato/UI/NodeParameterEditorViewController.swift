//
//  NodeParameterEditorViewController.swift
//  Arigato
//
//  Created by acb on 2020-05-09.
//  Copyright © 2020 acb. All rights reserved.
//

import Cocoa
import AVFoundation
import AudioToolbox
import AudioUnit
import CoreAudio

class NodeParameterEditorViewController: NSViewController {
    var tableView: NSTableView!
    
    var auAudioUnit: AUAudioUnit? {
        didSet {
            self.parameters = auAudioUnit?.parameterTree?.allParameters ?? []
        }
    }
    
    var parameters: [AUParameter] = []
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let scrollView = NSScrollView(frame: NSRect(origin: .zero, size: CGSize(width: 300, height: 200)))
        self.view = scrollView
        self.tableView = NSTableView()
        scrollView.documentView = self.tableView
        let column1 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "Col1"))
        let column2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "Col2"))
        column1.title = "Name"
        column2.title = "Value"
        tableView.addTableColumn(column1)
        tableView.addTableColumn(column2)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .none
    }
}

extension NodeParameterEditorViewController {
    class NameCell: NSTableCellView {
        var _tf: NSTextField
        override init(frame frameRect: NSRect) {
            self._tf = NSTextField(frame: NSRect(origin: .zero, size: frameRect.size))
            super.init(frame: frameRect)
            self._tf.autoresizingMask = [.width, .height]
            self._tf.isBordered = false
            self._tf.isEditable = false
            self.addSubview(self._tf)
            self.textField = self._tf
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
    }
    class ValueCell: NSTableCellView {
        var stepper: NSStepper
        var _tf: NSTextField
        var parameter: AUParameter? {
            didSet {
                guard let parameter = self.parameter else { return }
                stepper.minValue = Double(parameter.minValue)
                stepper.maxValue = Double(parameter.maxValue)
                let magnitude: AUValue = parameter.maxValue - parameter.minValue
                stepper.increment = magnitude >= 10 ? Double(pow(10, floor(log10(magnitude))-2 ) )  : Double(magnitude) * 0.0625
            }
        }

        override init(frame frameRect: NSRect) {
            let stepperWidth: CGFloat = 24 // FIXME
            self.stepper = NSStepper(frame: NSRect(x: frameRect.size.width - stepperWidth, y: 0, width: stepperWidth, height: frameRect.size.height))
            self._tf = NSTextField(frame: NSRect(origin: .zero, size: NSSize(width: frameRect.size.width-stepperWidth, height: frameRect.size.height)))
            super.init(frame: frameRect)
            self.stepper.autoresizingMask = [.height]
            self._tf.autoresizingMask = [.width, .height]
            self._tf.isBordered = false
            self.addSubview(self.stepper)
            self.addSubview(self._tf)
            self.textField = self._tf
            self.stepper.target = self
            self.stepper.action = #selector(self.valueChanged(_:))
            self._tf.target = self
            self._tf.action = #selector(self.valueChanged(_:))
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        var value: AUValue? = nil {
            didSet {
                self.textField?.stringValue = self.value.map { String(format: "%0.3f", $0)  } ?? "?"
                if let value = self.value {
                    self.stepper.doubleValue = Double(value)
                }
            }
        }
        var onValueSet: ((AUValue)->())?
        private func setValue(_ val: AudioUnitParameterValue) {
            self.value = val
            self.onValueSet?(val)
        }
        @objc func valueChanged(_ sender: Any) {
            if sender as? NSStepper == self.stepper {
                self.setValue(AudioUnitParameterValue(self.stepper.doubleValue))
            } else if sender as? NSTextField == self._tf {
                (AUValue(self.textField!.stringValue) ?? self.value).map { self.setValue($0) }
            }
        }
    }
}


extension NodeParameterEditorViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.parameters.count
    }
}

extension NodeParameterEditorViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < parameters.count else { return nil }
        let param = parameters[row]
        if tableColumn == self.tableView.tableColumns[0] {
            let cell = NameCell(frame: .zero)
            cell.textField!.stringValue = param.displayName
            return cell
        } else { // column 1
            let cell = ValueCell(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            cell.parameter = param
            cell.value = param.value
            cell.onValueSet = { [weak self] in
                param.setValue($0, originator: &self)
            }
            return cell
        }
    }
}
