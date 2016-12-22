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
    public var isOn:             Bool                  { didSet { addParameterUpdate(name: "on",    value: self.isOn                        as AnyObject) } }
    public var alert:            PhilipsHueLightAlert? { didSet { addParameterUpdate(name: "alert", value: self.alert?.jsonValue            as AnyObject) } }
    /// 0.0 (black) ... 1.0 (full brightness)
    public var brightness:       Float?                { didSet { addParameterUpdate(name: "bri",   value: self.brightness?.toBrightness()  as AnyObject) } }
    /// 0.0 (red) ... 1.0 (red)
    public var hue:              Float?                { didSet { addParameterUpdate(name: "hue",   value: self.hue?.toHue()                as AnyObject) } }
    /// 0.0 (white) ... 1.0 (full saturation)
    public var saturation:       Float?                { didSet { addParameterUpdate(name: "sat",   value: self.saturation?.toSaturation()  as AnyObject) } }
    /// 0.0 (coldest) ... 1.0 (warmest)
    public var colorTemperature: Float?                { didSet { addParameterUpdate(name: "ct",    value: self.colorTemperature?.toMired() as AnyObject) } }

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
        self.brightness       = (stateJson["bri"]        as? Int)?.toNormalizedBrightness()
        self.hue              = (stateJson["hue"]        as? Int)?.toNormalizedHue()
        self.saturation       = (stateJson["sat"]        as? Int)?.toNormalizedSaturation()
        self.colorTemperature = (stateJson["ct"]         as? Int)?.toNormalizedMired()
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
