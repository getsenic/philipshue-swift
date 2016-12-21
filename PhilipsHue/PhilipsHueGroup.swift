//
//  PhilipsHueGroup.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/16/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Foundation

public class PhilipsHueGroup: PhilipsHueBridgeItem, PhilipsHueLightItem {
    public private(set) weak var bridge: PhilipsHueBridge?
    public let identifier: String

    public private(set) var name:             String
    public private(set) var lightIdentifiers: [String]
    public private(set) var type:             PhilipsHueGroupType

    public var lights:          [PhilipsHueLight] { return lightIdentifiers.flatMap{ bridge?.lights[$0] } }
    public var reachableLights: [PhilipsHueLight] { return lights.filter{ $0.isReachable } }

    public var isOn: Bool {
        get {
            let reachableLights = self.reachableLights
            return reachableLights.count > 0 && reachableLights.filter{ $0.isOn }.count == reachableLights.count
        }
        set {
            //TODO: Optionally update individual lights
            reachableLights.forEach {
                $0.beginInternalUpdate()
                $0.isOn = newValue
                $0.endInternalUpdate()
            }
            bridge?.enqueueRequest("groups/\(identifier)/action", method: .put, parameters: ["on" : newValue as AnyObject]) { result in
                print(result)
                switch result {
                case .failure(let error): print(error)
                case .success(let jsonObjects): print(jsonObjects)
                }
            }
        }
    }
    public var brightness: Float? {
        get {
            let brightnesses = self.reachableLights.flatMap { $0.brightness }
            return brightnesses.count > 0 ? brightnesses.reduce(0.0) { $0.0 + $0.1 } / Float(brightnesses.count) : nil
        }
        set {
            guard let newValue = newValue else { return }
            //TODO: Optionally update individual lights
            reachableLights.filter{ $0.brightness != nil }.forEach {
                $0.beginInternalUpdate()
                $0.brightness = newValue
                $0.endInternalUpdate()
            }
            bridge?.enqueueRequest("groups/\(identifier)/action", method: .put, parameters: ["bri" : Int(newValue.clamped() * 254.0) as AnyObject]) { result in
                switch result {
                case .failure(let error): print(error)
                case .success(let jsonObjects): print(jsonObjects)
                }
            }
        }
    }
    public var hue: Float?
    public var saturation: Float?
    public var colorTemperature: UInt?

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
        bridge?.enqueueRequest("groups/\(identifier)", method: .put, parameters: ["lights" : lightIdentifiers as AnyObject]) { [weak self] result in
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
