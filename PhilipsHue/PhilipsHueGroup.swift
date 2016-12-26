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

    /// If `false` (default) parameter changes are sent to the group. If `true` light parameter changes are instead sent as inidividual requests to each reachable light of the group.
    public var updateLightsIndividually = false

    internal var stateUpdateUrl: String { return "groups/\(identifier)/action" }
    internal var stateUpdateDuration: TimeInterval { return 1.0 }
    internal var stateUpdateParameters: [String : AnyObject] = [:]

    private var defersUpdates = false

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
        get { return getLightValuesAverage { $0.brightness } }
        set { addParameterUpdate(name: "bri", value: newValue?.toBrightness(), lightFilter: { $0.brightness != nil }, lightUpdate: { $0.brightness = newValue }) }
    }
    public var hue: Float? {
        get { return getLightValuesAverage { $0.hue } }
        set { addParameterUpdate(name: "hue", value: newValue?.toHue(), lightFilter: { $0.hue != nil }, lightUpdate: { $0.hue = newValue }) }
    }
    public var saturation: Float? {
        get { return getLightValuesAverage { $0.saturation } }
        set { addParameterUpdate(name: "sat", value: newValue?.toSaturation(), lightFilter: { $0.saturation != nil }, lightUpdate: { $0.saturation = newValue }) }
    }
    public var colorTemperature: Float? {
        get { return getLightValuesAverage { $0.colorTemperature } }
        set { addParameterUpdate(name: "ct", value: newValue?.toMired(), lightFilter: { $0.colorTemperature != nil }, lightUpdate: { $0.colorTemperature = newValue }) }
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
        bridge?.requestJSONArray("groups/\(identifier)", method: .put, parameters: ["lights" : lightIdentifiers as AnyObject]) { [weak self] response in
            switch response.result {
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

    public func beginUpdates() {
        defersUpdates = true
    }

    public func endUpdates() {
        guard defersUpdates else { return }
        defersUpdates = false
        guard stateUpdateParameters.count > 0 else { return }
        bridge?.enqueueLightUpdate(for: self)
    }

    internal func refresh(from group: PhilipsHueGroup) {
        beginRefreshing()
        name             = group.name
        lightIdentifiers = group.lightIdentifiers
        type             = group.type
        endRefreshing()
    }

    func beginRefreshing() {
        // NOP – groups don't have states that affect light parameters
    }

    func endRefreshing() {
        // NOP – groups don't have states that affect light parameters
    }

    private func getLightValuesAverage(_ value: (PhilipsHueLight) -> Float?) -> Float? {
        let values = self.reachableLights.flatMap(value)
        return values.count > 0 ? Float(values.reduce(0) { $0.0 + $0.1 }) / Float(values.count) : nil
    }

    private func addParameterUpdate<Value>(name: String, value: Value?, lightFilter: (PhilipsHueLight) -> Bool = {_ in return true}, lightUpdate: (PhilipsHueLight) -> Void) {
        guard let value = value else { return }
        if updateLightsIndividually {
            reachableLights.filter(lightFilter).forEach {
                lightUpdate($0)
            }
        }
        else {
            reachableLights.filter(lightFilter).forEach {
                $0.beginRefreshing()
                lightUpdate($0)
                $0.endRefreshing()
            }
            stateUpdateParameters[name] = value as AnyObject
            guard !defersUpdates else { return }
            bridge?.enqueueLightUpdate(for: self)
        }
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
