//
//  PhilipsHueLight.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/16/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Alamofire

public class PhilipsHueLight: PhilipsHueBridgeItem, PhilipsHueLightItem {
    public private(set) weak var bridge: PhilipsHueBridge?

    public private(set) var isReachable:  Bool
    public private(set) var name:         String
    public private(set) var manufacturer: String
    public private(set) var model:        String

    public let identifier:       String
    public var isOn:             Bool                  { didSet { signalParameterChange(for: .on) } }
    public var alert:            PhilipsHueLightAlert? { didSet { signalParameterChange(for: .alert) } }
    public var brightness:       Float?                { didSet { signalParameterChange(for: .brightness) } }
    public var hue:              Float?                { didSet { signalParameterChange(for: .hue) } }
    public var saturation:       Float?                { didSet { signalParameterChange(for: .saturation) } }
    /// Color temperature in Kelvin: 2000..6500
    public var colorTemperature: UInt?                 { didSet { signalParameterChange(for: .colorTemperature) } }

    public var writeChangesImmediately = true

    private var pendingParameters: Set<PhilipsHueLightParameter> = []
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

    private func signalParameterChange(for parameter: PhilipsHueLightParameter) {
        guard !isUpdatingInternally else { return }
        pendingParameters.insert(parameter)
        if writeChangesImmediately { writeChanges() }
    }

    public func writeChanges() {
        guard pendingParameters.count > 0 else { return }
        var parameters: [String : AnyObject] = [:]
        if pendingParameters.contains(.on)                                                  { parameters["on"]    = isOn                                as AnyObject }
        if pendingParameters.contains(.alert),            let alert      = alert            { parameters["alert"] = alert.jsonValue                     as AnyObject }
        if pendingParameters.contains(.brightness),       let brightness = brightness       { parameters["bri"]   = Int(brightness.clamped() * 254.0)   as AnyObject }
        if pendingParameters.contains(.hue),              let hue        = hue              { parameters["hue"]   = Int(hue.clamped()        * 65535.0) as AnyObject }
        if pendingParameters.contains(.saturation),       let saturation = saturation       { parameters["sat"]   = Int(saturation.clamped() * 254.0)   as AnyObject }
        if pendingParameters.contains(.colorTemperature), let colorTemp  = colorTemperature { parameters["ct"]    = 1_000_000 / colorTemp               as AnyObject }
        pendingParameters = []
        bridge?.enqueueRequest("lights/\(identifier)/state", method: .put, parameters: parameters) { result in
            switch result {
            case .failure(let error): print(error)
            case .success(let jsonObjects): print(jsonObjects)
            }
        }
    }
}

private enum PhilipsHueLightParameter {
    case on
    case alert
    case brightness
    case hue
    case saturation
    case colorTemperature
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

private extension Int {
    func toFloat() -> Float { return Float(self) }
}

private extension Float {
    func clamped() -> Float { return max(0.0, min(1.0, self)) }
    func inversed() -> Float { return 1.0 / self }
    func toUInt() -> UInt { return UInt(self) }
}
