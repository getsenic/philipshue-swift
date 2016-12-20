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
    public var isOn:       Bool { didSet { signalStateChange(for: .on) } }
    public var alert:      PhilipsHueLightAlert? { didSet { signalStateChange(for: .alert) } }

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
        if pendingStates.contains(.on) { parameters["on"] = isOn as AnyObject }
        if pendingStates.contains(.alert), let alert = alert { parameters["alert"] = alert.jsonValue as AnyObject }
        pendingStates = []
        bridge?.enqueueRequest("lights/\(identifier)/state", method: .put, parameters: parameters) { result in
            print(result)
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
