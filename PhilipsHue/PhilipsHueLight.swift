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
    public private(set) var type:         LightType?

    public let identifier:       String
    public var isOn:             Bool   { didSet { addParameterUpdate(name: "on",    value: self.isOn) } }
    public var alert:            Alert? { didSet { addParameterUpdate(name: "alert", value: self.alert?.jsonValue) } }
    /// 0.0 (black) ... 1.0 (full brightness)
    public var brightness:       Float? { didSet { addParameterUpdate(name: "bri",   value: self.brightness?.toBrightness()) } }
    /// 0.0 (red) ... 1.0 (red)
    public var hue:              Float? { didSet { addParameterUpdate(name: "hue",   value: self.hue?.toHue()) } }
    /// 0.0 (white) ... 1.0 (full saturation)
    public var saturation:       Float? { didSet { addParameterUpdate(name: "sat",   value: self.saturation?.toSaturation()) } }
    /// 0.0 (coldest) ... 1.0 (warmest)
    public var colorTemperature: Float? { didSet { addParameterUpdate(name: "ct",    value: self.colorTemperature?.toMired()) } }

    internal var stateUpdateUrl: String { return "lights/\(self.identifier)/state" }
    internal var stateUpdateDuration: TimeInterval { return 0.1 }
    internal var stateUpdateParameters: [String : AnyObject] = [:]

    private var isRefreshing  = false
    private var defersUpdates = false

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
        self.alert            = Alert(fromJsonValue: stateJson["alert"] as? String ?? "")
        self.type             = LightType(fromJsonValue: json["type"] as? String ?? "")
        self.name             = json["name"]             as? String ?? ""
        self.manufacturer     = json["manufacturername"] as? String ?? ""
        self.model            = json["modelid"]          as? String ?? ""
        self.brightness       = (stateJson["bri"]        as? Int)?.toNormalizedBrightness()
        self.hue              = (stateJson["hue"]        as? Int)?.toNormalizedHue()
        self.saturation       = (stateJson["sat"]        as? Int)?.toNormalizedSaturation()
        self.colorTemperature = (stateJson["ct"]         as? Int)?.toNormalizedMired()
    }

    public func beginUpdates() {
        defersUpdates = true
    }

    public func endUpdates() {
        guard defersUpdates else { return }
        defersUpdates = false
        guard stateUpdateParameters.count > 0 else { return }
        bridge?.enqueueLightUpdate(for: self)
    }

    internal func refresh(from light: PhilipsHueLight) {
        beginRefreshing()
        name             = light.name
        manufacturer     = light.manufacturer
        model            = light.model
        type             = light.type
        isReachable      = light.isReachable
        isOn             = light.isOn
        brightness       = light.brightness
        hue              = light.hue
        saturation       = light.saturation
        colorTemperature = light.colorTemperature
        endRefreshing()
    }

    internal func beginRefreshing() {
        isRefreshing = true
    }

    internal func endRefreshing() {
        isRefreshing = false
    }

    private func addParameterUpdate<Value>(name: String, value: Value?) {
        guard !isRefreshing, let value = value else { return }
        stateUpdateParameters[name] = value as AnyObject
        guard !defersUpdates else { return }
        bridge?.enqueueLightUpdate(for: self)
    }

    public enum Alert: CustomStringConvertible {
        case none
        case select
        case longSelect

        public var description: String { return String(describing: self) }

        fileprivate var jsonValue: String {
            switch self {
            case .none:       return "none"
            case .select:     return "select"
            case .longSelect: return "lselect"
            }
        }

        fileprivate init?(fromJsonValue jsonValue: String) {
            if      jsonValue == Alert.none.jsonValue       { self = .none }
            else if jsonValue == Alert.select.jsonValue     { self = .select }
            else if jsonValue == Alert.longSelect.jsonValue { self = .longSelect }
            else { return nil }
        }
    }

    public enum LightType: CustomStringConvertible {
        case onOff
        case dimmable
        case colorTemperature
        case color
        case extendedColor

        public var description: String { return jsonValue }

        fileprivate var jsonValue: String {
            switch self {
            case .onOff:            return "On/off light"
            case .dimmable:         return "Dimmable light"
            case .colorTemperature: return "Color temperature light"
            case .color:            return "Color light"
            case .extendedColor:    return "Extended color light"
            }
        }

        fileprivate init?(fromJsonValue jsonValue: String) {
            if      jsonValue.caseInsensitiveCompare(LightType.onOff.jsonValue)            == .orderedSame { self = .onOff }
            else if jsonValue.caseInsensitiveCompare(LightType.dimmable.jsonValue)         == .orderedSame { self = .dimmable }
            else if jsonValue.caseInsensitiveCompare(LightType.colorTemperature.jsonValue) == .orderedSame { self = .colorTemperature}
            else if jsonValue.caseInsensitiveCompare(LightType.color.jsonValue)            == .orderedSame { self = .color }
            else if jsonValue.caseInsensitiveCompare(LightType.extendedColor.jsonValue)    == .orderedSame { self = .extendedColor }
            else { return nil }
        }
    }
}
