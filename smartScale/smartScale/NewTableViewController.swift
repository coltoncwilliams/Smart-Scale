//
//  RecipeTableViewController.swift
//  smartScale
//
//  Created by Cole Williams on 09/07/2020.
//  Copyright © 2020 Cole Williams. All rights reserved.
//

import UIKit
import os.log

class NewTableViewController: UITableViewController, UITextFieldDelegate {

    //MARK: IBOutlets
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var titleInput: UITextField!
    
    //MARK: Variables

    var steps = [Step]()
    var recipe: Recipe?
    var alertController: UIAlertController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // change the fonts of the bar buttons
        self.navigationItem.leftBarButtonItem!.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "Chalkboard SE", size: 17)!], for: UIControl.State.normal)
        self.navigationItem.rightBarButtonItem!.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "Chalkboard SE", size: 17)!], for: [UIControl.State.normal, UIControl.State.disabled])
        self.navigationController!.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.font: UIFont(name: "Chalkboard SE", size: 17)!]
        titleInput.delegate = self
        self.tableView.isEditing = true
        updateSaveButtonState()
    }

    //MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        // Hide the keyboard.
        textField.resignFirstResponder()
        return true
    }

    // when done editing check if can be saved
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateSaveButtonState()
    }

    //MARK: Navigation

    // if title is incorrect cancel segue
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        if (titleInput.text!.count > 20 || titleInput.text!.contains("#") || titleInput.text!.contains("/")) {
                createAlert(title: "Fix Title", message: "Must be less than 20 characters and not contain '#' or '/'")
            return false
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard let button = sender as? UIBarButtonItem, button === saveButton else {
            os_log("The save button was not pressed, cancelling", log: OSLog.default, type: .debug)
            return
        }
        let title = titleInput.text ?? ""
        
        // new recipe to be added
        recipe = Recipe(title: title, steps: steps)
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedObject = self.steps[sourceIndexPath.row]
        steps.remove(at: sourceIndexPath.row)
        steps.insert(movedObject, at: destinationIndexPath.row)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return steps.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "NewTableViewCell"


        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? NewTableViewCell else {
            fatalError("The dequeued cell is not an instance of NewTableViewCell.")
        }

        let step = steps[indexPath.row]
        cell.stepLabel.text = step.body
        cell.weightLabel.text = step.weight
        return cell
    }

    //MARK: Actions
    
    // step added to new recipe
    @IBAction func unwindToStepList(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? NewViewController, let step = sourceViewController.step {

            // Add a new step
            let newIndexPath = IndexPath(row: steps.count, section: 0)
            steps.append(step)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
            updateSaveButtonState()
        }
    }
    
    @IBAction func saveButton(_ sender: Any) {
        if (titleInput.text!.count > 20 || titleInput.text!.contains("#") || titleInput.text!.contains("/")) {
            createAlert(title: "Fix Title", message: "Must be less than 20 characters and not contain '#' or '/'")
        }
    }

    @IBAction func addStep(_ sender: Any) {
        titleInput.endEditing(true)
    }


    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }


    //MARK: PrivateMethods

    // Disable the Save button if the text field is empty.
    private func updateSaveButtonState() {
        let title = titleInput.text ?? ""
        if(steps.count != 0 && !title.isEmpty) {
            saveButton.isEnabled = true
        } else {
            saveButton.isEnabled = false
        }

    }
    
    func createAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            alert.dismiss(animated: true, completion: nil)
        }))
        super.present(alert, animated: true, completion: nil)
    }
}
