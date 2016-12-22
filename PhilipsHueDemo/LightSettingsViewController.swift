//
//  LightSettingsViewController.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/19/16.
//  Copyright © 2016 senic. All rights reserved.
//

import PhilipsHue
import UIKit

class LightSettingsViewController: UIViewController {

    var light: PhilipsHueLightItem!

    @IBOutlet weak var onSwitch:               UISwitch!
    @IBOutlet weak var brightnessSlider:       UISlider!
    @IBOutlet weak var hueSlider:              UISlider!
    @IBOutlet weak var saturationSlider:       UISlider!
    @IBOutlet weak var colorTemperatureSlider: UISlider!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = (light is PhilipsHueLight ? "Light" : "Group").appending(" \(light.identifier)")

        onSwitch.isOn = light.isOn

        brightnessSlider.isEnabled = light.brightness != nil
        if let brightness = light.brightness { brightnessSlider.value = brightness }

        hueSlider.isEnabled = light.hue != nil
        if let hue = light.hue { hueSlider.value = hue }

        saturationSlider.isEnabled = light.saturation != nil
        if let saturation = light.saturation { saturationSlider.value = saturation }

        colorTemperatureSlider.isEnabled = light.colorTemperature != nil
        if let colorTemperature = light.colorTemperature { colorTemperatureSlider.value = Float(colorTemperature) }
    }

    @IBAction func didChangeIsOn() {
        light.isOn = onSwitch.isOn
    }

    @IBAction func didChangeBrightness() {
        light.brightness = brightnessSlider.value
    }

    @IBAction func didChangeHue() {
        light.hue = hueSlider.value
    }

    @IBAction func didChangeSaturation() {
        light.saturation = saturationSlider.value
    }

    @IBAction func didChangeColorTemperature() {
        light.colorTemperature = colorTemperatureSlider.value
    }
}
