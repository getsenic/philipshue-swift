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

    @IBOutlet weak var updateModeStackView:        UIStackView!
    @IBOutlet weak var updateModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var onSwitch:                   UISwitch!
    @IBOutlet weak var brightnessSlider:           UISlider!
    @IBOutlet weak var hueSlider:                  UISlider!
    @IBOutlet weak var saturationSlider:           UISlider!
    @IBOutlet weak var colorTemperatureSlider:     UISlider!
    @IBOutlet weak var startBatchUpdateButton:     UIButton!
    @IBOutlet weak var sendBatchUpdateButton:      UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = (light is PhilipsHueLight ? "Light" : "Group").appending(" \(light.identifier)")

        if let group = light as? PhilipsHueGroup {
            updateModeStackView.isHidden = false
            updateModeSegmentedControl.selectedSegmentIndex = group.updateRequestMode == .singleGroupRequest ? 0 : 1
        }
        else {
            updateModeStackView.isHidden = true
        }

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

    override func viewWillDisappear(_ animated: Bool) {
        light.endUpdates()
        super.viewWillDisappear(animated)
    }

    @IBAction func didChangeUpdateMode() {
        guard let group = light as? PhilipsHueGroup else { return }
        group.updateRequestMode = [.singleGroupRequest, .multipleLightRequests][updateModeSegmentedControl.selectedSegmentIndex]
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

    @IBAction func startBatchUpdates() {
        light.beginUpdates()
        startBatchUpdateButton.isEnabled = false
        sendBatchUpdateButton.isEnabled  = true
    }

    @IBAction func sendBatchUpdates() {
        light.endUpdates()
        startBatchUpdateButton.isEnabled = true
        sendBatchUpdateButton.isEnabled  = false
    }
}
