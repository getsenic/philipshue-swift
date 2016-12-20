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

    public var reachableLights: [PhilipsHueLight] { return lightIdentifiers.flatMap{ bridge?.lights[$0] }.filter{ $0.isReachable } }

    public var isOn: Bool {
        get {
            let reachableLights = self.reachableLights
            return reachableLights.count > 0 && reachableLights.filter{ $0.isOn }.count == reachableLights.count
        }
        set {
            reachableLights.forEach {
                $0.beginUpdate()
                $0.isOn = newValue
                $0.endUpdate()
            }
            bridge?.enqueueStateChangeRequest("groups/\(identifier)/action", parameters: ["on" : newValue as AnyObject]) { result in
                print(result)
                switch result {
                case .failure(let error): print(error)
                case .success(let jsonObjects): print(jsonObjects)
                }
            }
        }
    }

    required public init?(bridge: PhilipsHueBridge, identifier: String, json: [String : AnyObject]) {
        guard
            let name             = json["name"]   as? String,
            let lightIdentifiers = json["lights"] as? [String],
            let type             = PhilipsHueGroupType(jsonName: json["type"] as? String ?? "")
        else {
            return nil
        }
            
        self.bridge           = bridge
        self.identifier       = identifier
        self.name             = name
        self.lightIdentifiers = lightIdentifiers
        self.type             = type
    }

    internal func update(from group: PhilipsHueGroup) {
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
