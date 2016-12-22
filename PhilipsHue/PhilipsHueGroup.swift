//
//  PhilipsHueGroup.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/16/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Foundation

public class PhilipsHueGroup: PhilipsHueBridgeLightItem {
    public private(set) weak var bridge: PhilipsHueBridge?
    public let identifier: String

    public private(set) var name:             String
    public private(set) var lightIdentifiers: [String]
    public private(set) var type:             PhilipsHueGroupType

    public var lights:          [PhilipsHueLight] { return lightIdentifiers.flatMap{ bridge?.lights[$0] } }
    public var reachableLights: [PhilipsHueLight] { return lights.filter{ $0.isReachable } }

    internal var stateUpdateUrl: String { return "groups/\(identifier)/action" }
    internal var stateUpdateParameters: [String : AnyObject] = [:]

    public var isOn: Bool {
        get {
            let reachableLights = self.reachableLights
            return reachableLights.count > 0 && reachableLights.filter{ $0.isOn }.count == reachableLights.count
        }
        set {
            addParameterUpdate(name: "on", value: newValue as AnyObject, lightUpdate: { $0.isOn = newValue })
        }
    }
    public var brightness: Float? {
        get {
            let brightnesses = self.reachableLights.flatMap { $0.brightness }
            return brightnesses.count > 0 ? brightnesses.reduce(0.0) { $0.0 + $0.1 } / Float(brightnesses.count) : nil
        }
        set {
            addParameterUpdate(name: "bri", value: newValue?.clamped().multiplied(by: 254.0).toUInt() as AnyObject, lightFilter: { $0.brightness != nil }, lightUpdate: { $0.brightness = newValue })
        }
    }
    public var hue: Float? {
        get {
            let hues = self.reachableLights.flatMap { $0.hue }
            return hues.count > 0 ? hues.reduce(0.0) { $0.0 + $0.1 } / Float(hues.count) : nil
        }
        set {
            addParameterUpdate(name: "hue", value: newValue?.clamped().multiplied(by: 65535.0).toUInt() as AnyObject, lightFilter: { $0.hue != nil }, lightUpdate: { $0.hue = newValue })
        }
    }
    public var saturation: Float? {
        get {
            let saturations = self.reachableLights.flatMap { $0.saturation }
            return saturations.count > 0 ? saturations.reduce(0.0) { $0.0 + $0.1 } / Float(saturations.count) : nil
        }
        set {
            addParameterUpdate(name: "sat", value: newValue?.clamped().multiplied(by: 254.0).toUInt() as AnyObject, lightFilter: { $0.saturation != nil }, lightUpdate: { $0.saturation = newValue })
        }
    }
    public var colorTemperature: UInt? {
        get {
            let colorTemperatures = self.reachableLights.flatMap { $0.colorTemperature }
            return colorTemperatures.count > 0 ? UInt(Float(colorTemperatures.reduce(0) { $0.0 + $0.1 }) / Float(colorTemperatures.count)) : nil
        }
        set {
            addParameterUpdate(name: "ct", value: newValue?.divided(by: 1_000_000.0).inversed().toUInt() as AnyObject, lightFilter: { $0.colorTemperature != nil }, lightUpdate: { $0.colorTemperature = newValue })
        }
    }

    required convenience public init?(bridge: PhilipsHueBridge, identifier: String, json: [String : AnyObject]) {
        guard
            let name             = json["name"]   as? String,
            let lightIdentifiers = json["lights"] as? [String],
            let type             = PhilipsHueGroupType(jsonName: json["type"] as? String ?? "")
        else {
            return nil
        }

        self.init(bridge: bridge, identifier: identifier, name: name, lightIdentifiers: lightIdentifiers, type: type)
    }

    public init(bridge: PhilipsHueBridge, identifier: String, name: String, lightIdentifiers: [String], type: PhilipsHueGroupType) {
        self.bridge           = bridge
        self.identifier       = identifier
        self.name             = name
        self.lightIdentifiers = lightIdentifiers
        self.type             = type
    }

    public func setLights(_ lights: [PhilipsHueLight], completion: @escaping (PhilipsHueResult<Void>) -> Void) {
        let lightIdentifiers = Array(Set(lights.map{ $0.identifier }))
        bridge?.request("groups/\(identifier)", method: .put, parameters: ["lights" : lightIdentifiers as AnyObject]) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let jsonObjects):
                guard jsonObjects.flatMap({ $0["success"] as? [String : AnyObject] }).count > 0 else {
                    completion(.failure(.unexpectedResponse(jsonObjects)))
                    return
                }
                self?.lightIdentifiers = lightIdentifiers
                completion(.success())
            }
        }
    }

    internal func updateInternally(from group: PhilipsHueGroup) {
        name             = group.name
        lightIdentifiers = group.lightIdentifiers
        type             = group.type
    }

    private func addParameterUpdate(name: String, value: AnyObject?, lightFilter: (PhilipsHueLight) -> Bool = {_ in return true}, lightUpdate: (PhilipsHueLight) -> Void) {
        guard let value = value else { return }
        //TODO: Optionally update individual lights
        reachableLights.filter(lightFilter).forEach {
            $0.beginInternalUpdate()
            lightUpdate($0)
            $0.endInternalUpdate()
        }
        stateUpdateParameters[name] = value
        bridge?.enqueueLightUpdate(for: self)
    }
}

public enum PhilipsHueGroupType {
    case luminaire
    case lightsource
    case group
    case room

    init?(jsonName: String) {
        guard let type: PhilipsHueGroupType = {
            switch jsonName {
            case "Luminaire":   return .luminaire
            case "Lightsource": return .lightsource
            case "LightGroup":  return .group
            case "Room":        return .room
            default:            return nil
            }
        }() else {
            return nil
        }
        self = type
    }
}
