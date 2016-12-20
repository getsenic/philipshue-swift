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

    public func requestUsername(for appName: String, completion: @escaping (Result<String>) -> Void) {
        let _ = Alamofire
            .request("http://\(host)/api", method: .post, parameters: ["devicetype": appName], encoding: JSONEncoding.default)
            .responseHueJSONArray { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let jsonObjects):
                    guard let username = jsonObjects.flatMap({($0["success"] as? [String : AnyObject])?["username"] as? String}).first else {
                        completion(.failure(NSError(domain: PhilipsHueErrorDomain, code: PhilipsHueUnexpectedServerResponseErrorCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected server response", NSLocalizedFailureReasonErrorKey: "Unexpected server response"])))
                        return
                    }
                    strongSelf.username = username
                    completion(.success(username))
                }
            }
    }

    public func refresh(completion: @escaping (Result<Void>) -> Void) {
        guard let username = username else {
            completion(.failure(NSError(domain: PhilipsHueErrorDomain, code: PhilipsHueUsernameNotAuthorizedErrorCode, userInfo: [NSLocalizedDescriptionKey: "Failed refreshing bridge", NSLocalizedFailureReasonErrorKey: "Username not set"])))
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
                        completion(.failure(NSError(domain: PhilipsHueErrorDomain, code: PhilipsHueUnexpectedServerResponseErrorCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected server response", NSLocalizedFailureReasonErrorKey: "Unexpected server response"])))
                        return
                    }
                    strongSelf.identifier = identifier
                    if let jsonLights = (json["lights"] as? [String : [String : AnyObject]]) { self?.updateBridgeItems(&strongSelf.lights, from: jsonLights) }
                    if let jsonGroups = (json["groups"] as? [String : [String : AnyObject]]) { self?.updateBridgeItems(&strongSelf.groups, from: jsonGroups) }
                    completion(.success())
                }
            }
    }

    public func getOrCreateGroup(for lights: [PhilipsHueLight], name: String, completion: @escaping (Result<PhilipsHueGroup>) -> Void) {
        guard lights.count > 0 else {
            completion(.failure(NSError(domain: PhilipsHueErrorDomain, code: PhilipsHueNoLightIdentifierSpecifiedErrorCode, userInfo: [NSLocalizedDescriptionKey: "Cannot create group", NSLocalizedFailureReasonErrorKey: "No lights specified"])))
            return
        }
        let lightIdentifiers = Array(Set(lights.map{ $0.identifier }))
        // Return an existing group if we know a group that contains exactly the same lights
        if let group = groups.values.filter({ group -> Bool in
            guard group.lightIdentifiers.count == lightIdentifiers.count else { return false }
            return group.lightIdentifiers.reduce(true) { (result, identifier) in return result && lightIdentifiers.contains(identifier) }
        }).first {
            completion(.success(group))
            return
        }
        // Create a new group
        enqueueRequest("groups", method: .post, parameters: ["lights" : lightIdentifiers as AnyObject, "name" : name as AnyObject, "type" : "LightGroup" as AnyObject]) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let jsonObjects):
                //TODO: Catch error responses and forward via .failure()
                guard let groupIdentifier = jsonObjects.flatMap({($0["success"] as? [String : AnyObject])?["id"] as? String}).first else {
                    completion(.failure(NSError(domain: PhilipsHueErrorDomain, code: PhilipsHueUnexpectedServerResponseErrorCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected server response", NSLocalizedFailureReasonErrorKey: "Unexpected server response"])))
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

    internal func enqueueRequest(_ urlPath: String, method: HTTPMethod, parameters: [String : AnyObject], completion: @escaping (Result<[[String : AnyObject]]>) -> ()) {
        guard let username = username else {
            completion(.failure(NSError(domain: PhilipsHueErrorDomain, code: PhilipsHueUsernameNotAuthorizedErrorCode, userInfo: [NSLocalizedDescriptionKey: "Failed updating state", NSLocalizedFailureReasonErrorKey: "Username not set"])))
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
    var identifier: String { get }
    var isOn: Bool { get set }
}

public let PhilipsHueErrorDomain = "PhilipsHueErrorDomain"
public let PhilipsHueUnexpectedServerResponseErrorCode = 1
public let PhilipsHueLinkButtonNotPressedErrorCode = 2
public let PhilipsHueUnknownFailureErrorCode = 3
public let PhilipsHueUsernameNotAuthorizedErrorCode = 4
public let PhilipsHueNoLightIdentifierSpecifiedErrorCode = 5

private struct HueErrorResponse {
    let type: Int?
    let description: String?
}

private extension DataResponse {
    var hueError: NSError? {
        guard let error = (result.value as? [[String : AnyObject]])?.flatMap({$0["error"] as? [String : AnyObject]}).first else { return nil }
        let (code, reason) = { () -> (Int, String) in
            switch (error["type"] as? Int) ?? -1 {
            case   1:  return (PhilipsHueUsernameNotAuthorizedErrorCode, "Username not authorized")
            case 101:  return (PhilipsHueLinkButtonNotPressedErrorCode,  "Link button not pressed")
            default:   return (PhilipsHueUnknownFailureErrorCode,        (error["description"] as? String) ?? "Unknown failure reason")
            }
        }()
        return NSError(domain: PhilipsHueErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: "Request failed", NSLocalizedFailureReasonErrorKey: reason])
    }
}

private extension DataRequest {
    func responseHueJSONObject(completion: @escaping (Result<[String : AnyObject]>) -> Void) -> Self {
        return responseJSON { dataResponse in
            if let error = dataResponse.result.error {
                completion(.failure(error))
                return
            }
            switch dataResponse.result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let value):
                if let error = dataResponse.hueError {
                    completion(.failure(error))
                    return
                }
                guard let genericJson = (value as? [String : AnyObject]) else {
                    completion(.failure(NSError(domain: PhilipsHueErrorDomain, code: PhilipsHueUnexpectedServerResponseErrorCode, userInfo: [NSLocalizedDescriptionKey: "Request failed", NSLocalizedFailureReasonErrorKey: "Unexpected server response"])))
                    return
                }
                completion(.success(genericJson))
            }
        }
    }

    func responseHueJSONArray(completion: @escaping (Result<[[String : AnyObject]]>) -> Void) -> Self {
        return responseJSON { dataResponse in
            if let error = dataResponse.result.error {
                completion(.failure(error))
                return
            }
            switch dataResponse.result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let value):
                if let error = dataResponse.hueError {
                    completion(.failure(error))
                    return
                }
                guard let jsonsObjects = (value as? [[String : AnyObject]]) else {
                    completion(.failure(NSError(domain: PhilipsHueErrorDomain, code: PhilipsHueUnexpectedServerResponseErrorCode, userInfo: [NSLocalizedDescriptionKey: "Request failed", NSLocalizedFailureReasonErrorKey: "Unexpected server response"])))
                    return
                }
                completion(.success(jsonsObjects))
            }
        }
    }
}
