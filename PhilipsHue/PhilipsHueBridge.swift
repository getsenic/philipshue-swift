//
//  PhilipsHueBridge.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/16/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Alamofire

public class PhilipsHueBridge {
    public let host: String
    public private(set) var username: String?
    public private(set) var identifier: String?

    public private(set) var lights: [String : PhilipsHueLight] = [:]
    public private(set) var groups: [String : PhilipsHueGroup] = [:]

    public init(host: String, username: String? = nil) {
        self.host       = host
        self.username   = username
    }

    public func requestUsername(for appName: String, completion: @escaping (PhilipsHueResult<String>) -> Void) {
        let _ = Alamofire
            .request("http://\(host)/api", method: .post, parameters: ["devicetype": appName], encoding: JSONEncoding.default)
            .responseHueJSONArray { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let jsonObjects):
                    guard let username = jsonObjects.flatMap({($0["success"] as? [String : AnyObject])?["username"] as? String}).first else {
                        completion(.failure(.unexpectedResponse(jsonObjects)))
                        return
                    }
                    strongSelf.username = username
                    completion(.success(username))
                }
            }
    }

    public func refresh(completion: @escaping (PhilipsHueResult<Void>) -> Void) {
        guard let username = username else {
            completion(.failure(.usernameNotSet))
            return
        }
        let _ = Alamofire
            .request("http://\(host)/api/\(username)")
            .responseHueJSONObject { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let json):
                    guard
                        let config     = json["config"]     as? [String : AnyObject],
                        let identifier = config["bridgeid"] as? String
                    else {
                        completion(.failure(.unexpectedResponse(json)))
                        return
                    }
                    strongSelf.identifier = identifier
                    if let jsonLights = (json["lights"] as? [String : [String : AnyObject]]) { self?.updateBridgeItems(&strongSelf.lights, from: jsonLights) }
                    if let jsonGroups = (json["groups"] as? [String : [String : AnyObject]]) { self?.updateBridgeItems(&strongSelf.groups, from: jsonGroups) }
                    completion(.success())
                }
            }
    }

    public func getOrCreateGroup(for lights: [PhilipsHueLight], name: String, overwiteIfGroupTableIsFull: Bool = false, completion: @escaping (PhilipsHueResult<PhilipsHueGroup>) -> Void) {
        let lightIdentifiers = Array(Set(lights.map{ $0.identifier }))
        // Return an existing group if we know a group that contains exactly the same lights
        if let group = groups.values.filter({ group -> Bool in
            guard group.lightIdentifiers.count == lightIdentifiers.count else { return false }
            return group.lightIdentifiers.reduce(true) { (result, identifier) in return result && lightIdentifiers.contains(identifier) }
        }).first {
            completion(.success(group))
            return
        }
        // Create a new group (or overwrite existing group if group table is full)
        enqueueRequest("groups", method: .post, parameters: ["lights" : lightIdentifiers as AnyObject, "name" : name as AnyObject, "type" : "LightGroup" as AnyObject]) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .failure(let error):
                // If group table is already full and `overwiteIfGroupTableIsFull` is `true`, we overwrite an existing group with the same name, if any
                if case .groupTableFull = error, overwiteIfGroupTableIsFull {
                    guard let group = strongSelf.groups.values.filter({ $0.name == name }).first else {
                        completion(.failure(error))
                        return
                    }
                    group.setLights(lights) { result in
                        switch result {
                        case .failure(let error): completion(.failure(error))
                        case .success():          completion(.success(group))
                        }
                    }
                    return
                }
                completion(.failure(error))
            case .success(let jsonObjects):
                guard let groupIdentifier = jsonObjects.flatMap({($0["success"] as? [String : AnyObject])?["id"] as? String}).first else {
                    completion(.failure(.unexpectedResponse(jsonObjects)))
                    return
                }
                let group = PhilipsHueGroup(bridge: strongSelf, identifier: groupIdentifier, name: name, lightIdentifiers: lightIdentifiers, type: .group)
                strongSelf.groups[groupIdentifier] = group
                completion(.success(group))
            }
        }
    }

    private func updateBridgeItems<T: PhilipsHueBridgeItem>(_ items: inout [String : T], from jsonItems: [String : [String : AnyObject]]) {
        items = jsonItems
            .flatMap { (identifier: String, json: [String : AnyObject]) -> T? in
                guard var item = T(bridge: self, identifier: identifier, json: json) else { return nil }
                if let existingItem = items[identifier] {
                    existingItem.update(from: item)
                    item = existingItem
                }
                return item
            }
            .reduce([String : T](), { (items, item) in
                var items = items
                items[item.identifier] = item
                return items
            })
    }

    internal func enqueueRequest(_ urlPath: String, method: HTTPMethod, parameters: [String : AnyObject], completion: @escaping (PhilipsHueResult<[[String : AnyObject]]>) -> ()) {
        guard let username = username else {
            completion(.failure(.usernameNotSet))
            return
        }
        let _ = Alamofire
            .request("http://\(host)/api/\(username)/\(urlPath)", method: method, parameters: parameters, encoding: JSONEncoding.default)
            .responseHueJSONArray { result in completion(result) }
    }
}

internal protocol PhilipsHueBridgeItem {
    var identifier: String { get }

    init?(bridge: PhilipsHueBridge, identifier: String, json: [String : AnyObject])

    func update(from: Self)
}

public protocol PhilipsHueLightItem: class {
    var identifier: String  { get }
    var isOn:       Bool    { get set }
    var brightness: Float?  { get set }
    var hue:        Float?  { get set }
    var saturation: Float?  { get set }
}

public enum PhilipsHueError: Error {
    case usernameNotSet
    case unauthorizedUser
    case resourceNotAvailable
    case linkButtonNotPressed
    case lightIsOff
    case groupTableFull
    case unexpectedErrorCode(Int)
    case unexpectedResponse(Any)
    case networkError(Error)

    init(code: Int) {
        switch code {
        case   1: self = .unauthorizedUser
        case   3: self = .resourceNotAvailable
        case 101: self = .linkButtonNotPressed
        case 201: self = .lightIsOff
        case 301: self = .groupTableFull
        default:  self = .unexpectedErrorCode(code)
        }
    }
}

extension PhilipsHueError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .usernameNotSet:                   return "Username not set"
        case .unauthorizedUser:                 return "User not authorized"
        case .resourceNotAvailable:             return "Resource not available"
        case .linkButtonNotPressed:             return "Link Button not pressed"
        case .lightIsOff:                       return "Light is off"
        case .groupTableFull:                   return "Cannot create group, group table already full"
        case .unexpectedErrorCode(let code):    return "Unexpected error code: \(code)"
        case .unexpectedResponse(let response): return "Unexpected response: \(response)"
        case .networkError(let error):          return "Network error: \(error)"
        }
    }
}

public enum PhilipsHueResult<Value> {
    case success(Value)
    case failure(PhilipsHueError)
}

private struct HueErrorResponse {
    let type: Int?
    let description: String?
}

private extension DataResponse {
    var hueError: PhilipsHueError? {
        guard let error = (result.value as? [[String : AnyObject]])?.flatMap({$0["error"] as? [String : AnyObject]}).first else { return nil }
        return PhilipsHueError(code: error["type"] as? Int ?? -1)
    }
}

private extension DataRequest {
    func responseHueJSONObject(completion: @escaping (PhilipsHueResult<[String : AnyObject]>) -> Void) -> Self {
        return responseJSON { dataResponse in
            switch dataResponse.result {
            case .failure(let error):
                completion(.failure(.networkError(error)))
            case .success(let value):
                if let error = dataResponse.hueError {
                    completion(.failure(error))
                    return
                }
                guard let genericJson = (value as? [String : AnyObject]) else {
                    completion(.failure(.unexpectedResponse(value)))
                    return
                }
                completion(.success(genericJson))
            }
        }
    }

    func responseHueJSONArray(completion: @escaping (PhilipsHueResult<[[String : AnyObject]]>) -> Void) -> Self {
        return responseJSON { dataResponse in
            switch dataResponse.result {
            case .failure(let error):
                completion(.failure(.networkError(error)))
            case .success(let value):
                if let error = dataResponse.hueError {
                    completion(.failure(error))
                    return
                }
                guard let jsonsObjects = (value as? [[String : AnyObject]]) else {
                    completion(.failure(.unexpectedResponse(value)))
                    return
                }
                completion(.success(jsonsObjects))
            }
        }
    }
}
