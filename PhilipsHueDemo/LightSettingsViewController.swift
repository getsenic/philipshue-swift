//
//  LightSettingsViewController.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/19/16.
//  Copyright © 2016 senic. All rights reserved.
//

import UIKit

class LightSettingsViewController: UIViewController {

    var lights: [PhilipsHueLightItem]!

    @IBOutlet weak var onSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "\(lights.count) Lights/Groups"
        onSwitch.isOn = lights.filter({ $0.isOn }).count == lights.count
    }

    @IBAction func didChangeIsOn() {
        lights.forEach { $0.isOn = onSwitch.isOn }
    }
}
