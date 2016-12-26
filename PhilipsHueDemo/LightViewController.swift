//
//  LightViewController.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/19/16.
//  Copyright © 2016 senic. All rights reserved.
//

import PhilipsHue
import UIKit

class LightViewController: UIViewController {

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
        prepareLight(forceGroupUpdate: true)
        light.isOn = onSwitch.isOn
    }

    @IBAction func didChangeBrightness() {
        prepareLight()
        light.brightness = brightnessSlider.value
    }

    @IBAction func didChangeHue() {
        prepareLight()
        light.hue = hueSlider.value
    }

    @IBAction func didChangeSaturation() {
        prepareLight()
        light.saturation = saturationSlider.value
    }

    @IBAction func didChangeColorTemperature() {
        prepareLight()
        light.colorTemperature = colorTemperatureSlider.value
    }

    func prepareLight(forceGroupUpdate: Bool = false) {
        guard let group = light as? PhilipsHueGroup else { return }
        group.updateLightsIndividually = !forceGroupUpdate && group.reachableLights.count < 10
    }
}
