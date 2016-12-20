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

    public let identifier: String
    public var isOn:       Bool                  { didSet { signalStateChange(for: .on) } }
    public var alert:      PhilipsHueLightAlert? { didSet { signalStateChange(for: .alert) } }
    public var brightness: Float?                { didSet { signalStateChange(for: .brightness) } }
    public var hue:        Float?                { didSet { signalStateChange(for: .hue) } }
    public var saturation: Float?                { didSet { signalStateChange(for: .saturation) } }

    public var writeChangesImmediately = true

    private var pendingStates: Set<PhilipsHueLightState> = []
    private var isUpdating = false

    public required init?(bridge: PhilipsHueBridge, identifier: String, json: [String : AnyObject]) {
        guard
            let stateJson   = json["state"]          as? [String : AnyObject],
            let isOn        = stateJson["on"]        as? Bool,
            let isReachable = stateJson["reachable"] as? Bool
        else {
            return nil
        }
        self.bridge         = bridge
        self.identifier     = identifier
        self.isReachable    = isReachable
        self.isOn           = isOn
        self.alert          = PhilipsHueLightAlert(fromJsonValue: stateJson["alert"] as? String ?? "")
        self.name           = json["name"]             as? String ?? ""
        self.manufacturer   = json["manufacturername"] as? String ?? ""
        self.model          = json["modelid"]          as? String ?? ""
        self.brightness     = (stateJson["bri"]        as? Int)?.divided(by: 254.0)
        self.hue            = (stateJson["hue"]        as? Int)?.divided(by: 65535.0)
        self.saturation     = (stateJson["sat"]        as? Int)?.divided(by: 254.0)
    }

    internal func update(from light: PhilipsHueLight) {
        beginUpdate()
        isReachable  = light.isReachable
        isOn         = light.isOn
        name         = light.name
        manufacturer = light.manufacturer
        model        = light.model
        endUpdate()
    }

    internal func beginUpdate() {
        isUpdating = true
    }

    internal func endUpdate() {
        isUpdating = false
    }

    private func signalStateChange(for state: PhilipsHueLightState) {
        guard !isUpdating else { return }
        pendingStates.insert(state)
        if writeChangesImmediately && !isUpdating { writeChanges() }
    }

    public func writeChanges() {
        guard pendingStates.count > 0 else { return }
        var parameters: [String : AnyObject] = [:]
        if pendingStates.contains(.on)                                      { parameters["on"]    = isOn                              as AnyObject }
        if pendingStates.contains(.alert),      let alert      = alert      { parameters["alert"] = alert.jsonValue                   as AnyObject }
        if pendingStates.contains(.brightness), let brightness = brightness { parameters["bri"]   = Int(brightness.clamped * 254.0)   as AnyObject }
        if pendingStates.contains(.hue),        let hue        = hue        { parameters["hue"]   = Int(hue.clamped        * 65535.0) as AnyObject }
        if pendingStates.contains(.saturation), let saturation = saturation { parameters["sat"]   = Int(saturation.clamped * 254.0)   as AnyObject }
        pendingStates = []
        bridge?.enqueueRequest("lights/\(identifier)/state", method: .put, parameters: parameters) { result in
            switch result {
            case .failure(let error): print(error)
            case .success(let jsonObjects): print(jsonObjects)
            }
        }
    }
}

private enum PhilipsHueLightState {
    case on
    case alert
    case brightness
    case hue
    case saturation
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
    func divided(by divisor: Float) -> Float {
        return Float(self) / divisor
    }
}

private extension Float {
    var clamped: Float { return max(0.0, min(1.0, self)) }
}
