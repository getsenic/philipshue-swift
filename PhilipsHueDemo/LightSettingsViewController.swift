//
//  LightSettingsViewController.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/19/16.
//  Copyright © 2016 senic. All rights reserved.
//

import UIKit

class LightSettingsViewController: UIViewController {

    var light: PhilipsHueLightItem!

    @IBOutlet weak var onSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = (light is PhilipsHueLight ? "Light" : "Group").appending(" \(light.identifier)")
        onSwitch.isOn = light.isOn
    }

    @IBAction func didChangeIsOn() {
        light.isOn = onSwitch.isOn
    }
}
