//
//  NewViewController.swift
//  smartScale
//
//  Created by Cole Williams on 10/07/2020.
//  Copyright © 2020 Cole Williams. All rights reserved.
//

import UIKit
import os.log

class NewViewController: UIViewController, UITextFieldDelegate {

    // if step has a weight value
    @IBOutlet weak var weightBool: UISwitch!
    
    // instruction or item text field
    @IBOutlet weak var instInput: UITextField!
    
    // weight value text field
    @IBOutlet weak var weightInput: UITextField!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!

    // the step to be saved
    var step: Step?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // change the button fonts
        self.navigationItem.leftBarButtonItem!.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "Chalkboard SE", size: 17)!], for: UIControl.State.normal)
        self.navigationItem.rightBarButtonItem!.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "Chalkboard SE", size: 17)!], for: [UIControl.State.normal, UIControl.State.disabled])
        instInput.delegate = self
        weightInput.delegate = self
        
        // update save button
        updateSaveButtonState()
        
        // add a done button to the numerical keyboard
        addDoneButtonOnNumpad(textField: weightInput)
    }

    //MARK: UITextFieldDelegate
    
    // hide keyboard on return
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        return true
    }

    // update button when done editing
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateSaveButtonState()
    }


    //MARK: Navigation
    
    // if inputs do not meet satisfactions, cancel segue and tell user
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        if (instInput.text!.count > 40 || instInput.text!.contains("#") || instInput.text!.contains("/") || weightInput.text!.count > 3 || weightInput.text!.contains("#") || weightInput.text!.contains("/")) {
            createAlert(title: "Fix Step", message: "Instruction and weight must be less than 40 characters and not contain '#' or '/'")
            return false
        }
        return true
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        // save button is pressed, configure the destination view controller
        guard let button = sender as? UIBarButtonItem, button === saveButton else {
            os_log("The save button was not pressed, cancelling", log: OSLog.default, type: .debug)
            return
        }
        os_log("Save button pressed", log: OSLog.default, type: .debug)
        let body = instInput.text ?? ""
        let weightSwitch = weightBool.isOn
        var weight: String
        weight = ""
        if (weightSwitch) {
            weight = weightInput.text ?? ""
        }


        // pass the step to the parent view controller
        step = Step(body: body, weight: weight)
    }

    //MARK: Actions

    // cancel button pressed
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    // disable weight input on weight switch off
    @IBAction func weightBool(_ sender: Any) {
        updateSaveButtonState()
        let weightSwitch = weightBool.isOn
        weightInput.isEnabled = weightSwitch
        if (weightSwitch) {
            weightInput.alpha = 1
        } else {
            weightInput.alpha = 0.3
        }
    }

    //MARK: PrivateMethods

    // disable save button if no inputs in required fields
    private func updateSaveButtonState() {
        let inst = instInput.text ?? ""
        let weightSwitch = weightBool.isOn
        let weight = weightInput.text ?? ""
        if(weightSwitch) {
            if (!inst.isEmpty && !weight.isEmpty) {
                saveButton.isEnabled = true
            } else {
                saveButton.isEnabled = false
            }
        } else {
            if (!inst.isEmpty) {
                saveButton.isEnabled = true
            } else {
                saveButton.isEnabled = false
            }
        }
    }

    // add a done button to the numberpad
    func addDoneButtonOnNumpad(textField: UITextField) {
        let keypadToolbar: UIToolbar = UIToolbar()
        keypadToolbar.items = [
            UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: textField, action: #selector(UITextField.resignFirstResponder)),
            UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        ]
        keypadToolbar.sizeToFit()
        // add a toolbar with a done button above the number pad
        textField.inputAccessoryView = keypadToolbar
    }
    
    // creates user alert
    func createAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            alert.dismiss(animated: true, completion: nil)
        }))
        super.present(alert, animated: true, completion: nil)
    }
}
