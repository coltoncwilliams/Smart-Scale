//
//  RecipeTableViewController.swift
//  smartScale
//
//  Created by Cole Williams on 09/07/2020.
//  Copyright © 2020 Cole Williams. All rights reserved.
//

import UIKit
import os.log
import CoreBluetooth
import QuartzCore

final class RecipeTableViewController: UITableViewController, BluetoothSerialDelegate {

    //MARK: IBOutlets
    @IBOutlet weak var connectButton: UIBarButtonItem!
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    //MARK: Variables
    
    // recipe array from scale
    var recipes = [Recipe]()
    
    // to store a recipe to send to scale
    var recipeTemp: Recipe?
    var receivedMessage = ""
    
    // the state of the scale's connection
    var connected = false
    
    // if currently receiving information from scale
    var waitingForTitles = false
    var waitingForRecipe = false

    var progressHUD: MBProgressHUD?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // change the font of the bar button
        self.navigationItem.leftBarButtonItem!.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "Chalkboard SE", size: 17)!], for: [UIControl.State.normal, UIControl.State.disabled])
        
        // init serial
        serial = BluetoothSerial(delegate: self)
        reloadView()
        
        // add observer to reload the view
        NotificationCenter.default.addObserver(self, selector: #selector(RecipeTableViewController.reloadView), name: NSNotification.Name(rawValue: "reloadStartViewController"), object: nil)
        
        // open connect scene
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.performSegue(withIdentifier: "connectScale", sender: RecipeTableViewController.self)
        }
    }

    // update connect and add buttons based on state of connection
    @objc func reloadView() {
        // in case we're the visible view again
        serial.delegate = self
        
        // if scale not connected, alert user
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if (!self.connected && serial.isReady) {
                super.dismiss(animated: true, completion: nil)
                self.createAlert(title: "Edit Mode", message: "Please select 'edit recipes' on scale")
            }
        }
        
        if serial.isReady {
            connectButton.title = "Connected"
            connectButton.isEnabled = false
            addButton.isEnabled = connected
        } else if serial.centralManager.state == .poweredOn {
            connectButton.title = "Connect"
            connectButton.isEnabled = true
            addButton.isEnabled = false
        } else {
            connectButton.title = "Connect"
            connectButton.isEnabled = false
            addButton.isEnabled = false
        }
    }


    //MARK: Navigation
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        // user deleting recipe
        if editingStyle == .delete {
            
            // show progress wheel
            progressHUD = MBProgressHUD.showAdded(to: view, animated: true)
            progressHUD!.labelText = "Deleting"
            progressHUD!.yOffset = -80
            connected = false
            
            // check to make sure scale is still connected
            serial.sendMessageToDevice("CONN")

            // delete recipe from scale
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if (self.connected) {
                    self.recipes.remove(at: indexPath.row)
                    let delMsg = "DELETE_" + String(indexPath.row + 1)
                    print(delMsg)
                    serial.sendMessageToDevice(delMsg)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                } else {
                    self.reloadView()
                    if let hud = self.progressHUD {
                        hud.hide(true)
                    }
                    super.dismiss(animated: true, completion: nil)
                    self.createAlert(title: "Not connected", message: "Please connect and try again")
                }
            }
        }
    }

    //MARK: BluetoothSerialDelegate
    
    // received message from scale
    func serialDidReceiveString(_ message: String) {
        print(message)
        
        // scale asking if connected
        if (message.contains("CONN?")) {
            serial.sendMessageToDevice("CONN")
            connected = true
            reloadView()
        }
            
        // scale ready for adding/deleting process
        else if (message.contains("READY")) {
            connected = true
            sendRecipe(recipe: recipeTemp!)
        }
            
        // scale sending recipe list
        else if (message.contains("TITLES")) {
            receivedMessage = ""
            receivedMessage += message
            waitingForTitles = true
            if (!connected) {
                connected = true
                reloadView()
                if (message.contains("#")) {
                    recipes = []
                    loadRecipes(titles: receivedMessage)
                    receivedMessage = ""
                    waitingForTitles = false
                }
            }
        }
            
        // scale done with adding/deleting process
        else if (message.contains("SUCCESS")) {
            if let hud = progressHUD {
                hud.hide(true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud?.mode = MBProgressHUDMode.text
            hud?.labelText = "Done"
            hud?.hide(true, afterDelay: 1)
            }
        }
        
        // scale done sending recipe list
        else if (message.contains("#")) {
            receivedMessage += message
            if(waitingForTitles) {
                recipes = []
                loadRecipes(titles: receivedMessage)
                receivedMessage = ""
                waitingForTitles = false
            } else if (waitingForRecipe) {
                // call segue with recipe
                receivedMessage = ""
                waitingForRecipe = false
            }
        }
        
        // scale done editing recipes
        else if (message.contains("EXIT")) {
            serial.disconnect()
            createAlert(title: "Done editing", message: "Disconnecting")
            recipes = []
            tableView.reloadData()
        } else {
            receivedMessage += message
        }

    }

    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        reloadView()
        connected = false
        createAlert(title: "Disconnected", message: "Please reconnect")
    }

    func serialDidChangeState() {
        reloadView()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recipes.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "RecipeTableViewCell"


        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? RecipeTableViewCell else {
            fatalError("The dequeued cell is not an instance of RecipeTableViewCell.")
        }

        let recipe = recipes[indexPath.row]

        cell.recipeTitle.text = recipe.title

        return cell
    }

    //MARK: Actions
    
    @IBAction func connectButton(_ sender: Any) {
        if serial.connectedPeripheral == nil {
            performSegue(withIdentifier: "ShowScanner", sender: self)
        } else {
            serial.disconnect()
            reloadView()
        }
    }

    //MARK: Navigation

    // make sure max recipes not acheived
    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        if (recipes.count > 8) {
            createAlert(title: "Recipe Maximum", message: "Maximum of 9 recipes allowed")
            return false
        }
        return true
    }

    // new recipe to be added
    @IBAction func unwindToRecipeList(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? NewTableViewController, let recipe = sourceViewController.recipe {

            // show progress wheel
            progressHUD = MBProgressHUD.showAdded(to: view, animated: true)
            progressHUD!.labelText = "Adding"
            progressHUD!.yOffset = -80
            connected = false
            
            // make sure scale is still connected
            serial.sendMessageToDevice("CONN")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if (self.connected) {
                    
                    // show new recipe in the table view
                    let newIndexPath = IndexPath(row: self.recipes.count, section: 0)
                    self.recipes.append(recipe)
                    super.tableView.insertRows(at: [newIndexPath], with: .automatic)

                    if !serial.isReady {
                        super.dismiss(animated: true, completion: nil)
                        self.createAlert(title: "Not connected", message: "Please connect to Scale")
                    }
                    self.recipeTemp = recipe
                    
                    // tell scale to get ready for new recipe
                    serial.sendMessageToDevice("ADD")
                } else {
                    self.reloadView()
                    if let hud = self.progressHUD {
                        hud.hide(true)
                    }
                    super.dismiss(animated: true, completion: nil)
                    self.createAlert(title: "Not connected", message: "Please connect and try again")
                }
            }
        }
    }

    //MARK: Private Methods

    // add recipes to table view based on string of titles
    func loadRecipes(titles: String) {
        var recipeTitles = titles
        tableView.reloadData()
        var separator = recipeTitles.firstIndex(of: "_")!
        let r = recipeTitles.index(recipeTitles.index(before: separator), offsetBy: 2)..<recipeTitles.index(recipeTitles.endIndex, offsetBy: 0)
        recipeTitles = String(recipeTitles[r])

        while (recipeTitles.count > 1) {
            print(recipeTitles)
            separator = recipeTitles.firstIndex(of: "_")!
            let l = recipeTitles.startIndex..<recipeTitles.index(recipeTitles.index(before: separator), offsetBy: 1)
            let p = recipeTitles.index(after: separator)..<recipeTitles.endIndex

            let title = String(recipeTitles[l])
            recipeTitles = String(recipeTitles[p])

            let newIndexPath = IndexPath(row: recipes.count, section: 0)
            guard let recipeTitle = Recipe(title: title, steps: []) else {
                fatalError("Unable to instantiate recipe")
            }
            recipes.append(recipeTitle)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        }
    }

    // send a recipe in increments to the scale
    func sendRecipe(recipe: Recipe) {
        usleep(500000)
        var msg = "TITLE_" + recipe.title + "/\n"
        serial.sendMessageToDevice(msg)
        print(msg)
        usleep(500000)
        for step in recipe.steps {
            msg = step.toString() + "/\n"
            serial.sendMessageToDevice(msg)
            print(msg)
            usleep(500000)
        }
        msg = "#\n"
        serial.sendMessageToDevice(msg)
    }

    func createAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            alert.dismiss(animated: true, completion: nil)
        }))
        super.present(alert, animated: true, completion: nil)
    }
}
