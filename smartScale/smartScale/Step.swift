//
//  Step.swift
//  smartScale
//
//  Created by Cole Williams on 10/07/2020.
//  Copyright © 2020 Cole Williams. All rights reserved.
//

import UIKit

// for storing a step with instruction and weight
class Step {

    // to store the instruction or item amount
    var body: String
    
    // to store the weight value
    var weight: String

    // constructor
    init?(body: String, weight: String) {
        guard !body.isEmpty else {
            return nil
        }
        self.body = body
        self.weight = weight
    }

    //MARK: Private Functions

    // converts the step into a string to send to the scale
    func toString() -> String {
        if (weight.isEmpty) {
            return "INST_" + body
        }
        return "WEIGHT_" + weight + "_" + body
    }

}
