//
//  NewTableViewCell.swift
//  smartScale
//
//  Created by Cole Williams on 10/07/2020.
//  Copyright © 2020 Cole Williams. All rights reserved.
//

import UIKit

class NewTableViewCell: UITableViewCell {

    //MARK: IBOutlets
    
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var weightLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
