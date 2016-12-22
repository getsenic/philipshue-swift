//
//  PhilipsHueLight.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/16/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Alamofire

public class PhilipsHueLight: PhilipsHueBridgeLightItem {
    public private(set) weak var bridge: PhilipsHueBridge?

    public private(set) var isReachable:  Bool
    public private(set) var name:         String
    public private(set) var manufacturer: String
    public private(set) var model:        String

    public let identifier:       String
    public var isOn:             Bool                  { didSet { addParameterUpdate(name: "on",    value: self.isOn                                                           as AnyObject) } }
    public var alert:            PhilipsHueLightAlert? { didSet { addParameterUpdate(name: "alert", value: self.alert?.jsonValue                                               as AnyObject) } }
    public var brightness:       Float?                { didSet { addParameterUpdate(name: "bri",   value: self.brightness?.clamped().multiplied(by: 254.0).toUInt()           as AnyObject) } }
    public var hue:              Float?                { didSet { addParameterUpdate(name: "hue",   value: self.hue?.clamped().multiplied(by: 65535.0).toUInt()                as AnyObject) } }
    public var saturation:       Float?                { didSet { addParameterUpdate(name: "sat",   value: self.saturation?.clamped().multiplied(by: 254.0).toUInt()           as AnyObject) } }
    /// Color temperature in Kelvin: 2000..6500
    public var colorTemperature: UInt?                 { didSet { addParameterUpdate(name: "ct",    value: self.colorTemperature?.divided(by: 1_000_000.0).inversed().toUInt() as AnyObject) } }

    internal var stateUpdateUrl: String { return "lights/\(self.identifier)/state" }
    internal var stateUpdateDuration: TimeInterval { return 0.1 }
    internal var stateUpdateParameters: [String : AnyObject] = [:]

    private var isUpdatingInternally = false

    public required init?(bridge: PhilipsHueBridge, identifier: String, json: [String : AnyObject]) {
        guard
            let stateJson   = json["state"]          as? [String : AnyObject],
            let isOn        = stateJson["on"]        as? Bool,
            let isReachable = stateJson["reachable"] as? Bool
        else {
            return nil
        }
        self.bridge           = bridge
        self.identifier       = identifier
        self.isReachable      = isReachable
        self.isOn             = isOn
        self.alert            = PhilipsHueLightAlert(fromJsonValue: stateJson["alert"] as? String ?? "")
        self.name             = json["name"]             as? String ?? ""
        self.manufacturer     = json["manufacturername"] as? String ?? ""
        self.model            = json["modelid"]          as? String ?? ""
        self.brightness       = (stateJson["bri"]        as? Int)?.toFloat().divided(by: 254.0)
        self.hue              = (stateJson["hue"]        as? Int)?.toFloat().divided(by: 65535.0)
        self.saturation       = (stateJson["sat"]        as? Int)?.toFloat().divided(by: 254.0)
        self.colorTemperature = (stateJson["ct"]         as? Int)?.toFloat().divided(by: 1_000_000.0).inversed().toUInt()
    }

    internal func updateInternally(from light: PhilipsHueLight) {
        beginInternalUpdate()
        isReachable  = light.isReachable
        isOn         = light.isOn
        name         = light.name
        manufacturer = light.manufacturer
        model        = light.model
        endInternalUpdate()
    }

    internal func beginInternalUpdate() {
        isUpdatingInternally = true
    }

    internal func endInternalUpdate() {
        isUpdatingInternally = false
    }

    private func addParameterUpdate(name: String, value: AnyObject?) {
        guard !isUpdatingInternally, let value = value else { return }
        stateUpdateParameters[name] = value
        bridge?.enqueueLightUpdate(for: self)
    }
}

public enum PhilipsHueLightAlert {
    case none
    case select
    case longSelect

    fileprivate var jsonValue: String {
        switch self {
        case .none:       return "none"
        case .select:     return "select"
        case .longSelect: return "lselect"
        }
    }

    fileprivate init?(fromJsonValue jsonValue: String) {
        if      jsonValue == PhilipsHueLightAlert.none.jsonValue       { self = .none }
        else if jsonValue == PhilipsHueLightAlert.select.jsonValue     { self = .select }
        else if jsonValue == PhilipsHueLightAlert.longSelect.jsonValue { self = .longSelect }
        else { return nil }
    }
}
