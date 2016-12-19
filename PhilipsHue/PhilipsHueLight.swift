//
//  PhilipsHueLight.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/16/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Alamofire

public class PhilipsHueLight: PhilipsHueBridgeItem {
    public private(set) weak var bridge: PhilipsHueBridge?
    public let identifier: String
    public var on: Bool { didSet { signalStateChange(for: .on) } }
    public var writeChangesImmediately = true

    private var pendingStates: Set<PhilipsHueLightState> = []

    public required init?(bridge: PhilipsHueBridge, identifier: String, json: [String : AnyObject]) {
        guard
            let stateJson = json["state"]   as? [String : AnyObject],
            let on        = stateJson["on"] as? Bool
        else {
            return nil
        }
        self.bridge         = bridge
        self.identifier     = identifier
        self.on             = on
    }

    internal func update(from light: PhilipsHueLight) {
        on = light.on
    }

    private func signalStateChange(for state: PhilipsHueLightState) {
        pendingStates.insert(state)
        if writeChangesImmediately { writeChanges() }
    }

    public func writeChanges() {
        guard pendingStates.count > 0 else { return }
        var parameters: [String : AnyObject] = [:]
        if pendingStates.contains(.on) {
            parameters["on"] = on as AnyObject
        }
        pendingStates = []
        bridge?.enqueueStateChangeRequest("lights/\(identifier)/state", parameters: parameters) { result in
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
}
