//
//  Recipe.swift
//  smartScale
//
//  Created by Cole Williams on 09/07/2020.
//  Copyright © 2020 Cole Williams. All rights reserved.
//

import UIKit

// for storing a recipe with title and array of steps
class Recipe {

    // title of recipe
    var title: String
    
    // steps of recipe
    var steps: [Step]

    // constructor
    init?(title: String, steps: [Step]) {
        guard !title.isEmpty else {
            return nil
        }
        self.title = title
        self.steps = steps
    }
}
