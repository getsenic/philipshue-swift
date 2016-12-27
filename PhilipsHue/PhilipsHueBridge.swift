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
    public var username: String?
    public private(set) var identifier: String?

    public private(set) var lights: [String : PhilipsHueLight] = [:]
    public private(set) var groups: [String : PhilipsHueGroup] = [:]

    private let alamofire: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 5.0
        return Alamofire.SessionManager(configuration: configuration)
    }()

    private let lightUpdateOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    public init(host: String, username: String? = nil) {
        self.host     = host
        self.username = username
    }

    public func requestUsername(for appName: String, completion: @escaping (PhilipsHueResult<String>) -> Void) {
        #if os(iOS) || os(tvOS)
        let deviceName = UIDevice.current.name
        #else
        //TODO: Implement device name for other platforms
        let deviceName = "unspecified"
        #endif
        requestJSONArray("/", needsAuthorization: false, method: .post, parameters: ["devicetype" : "\(appName)#\(deviceName)" as AnyObject]) { [weak self] response in
            guard let strongSelf = self else { return }
            switch response.result {
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
        requestJSONObject("/") { [weak self] response in
            guard let strongSelf = self else { return }
            switch response.result {
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
                if let jsonLights = (json["lights"] as? [String : [String : AnyObject]]) { self?.refreshBridgeItems(&strongSelf.lights, from: jsonLights) }
                if let jsonGroups = (json["groups"] as? [String : [String : AnyObject]]) { self?.refreshBridgeItems(&strongSelf.groups, from: jsonGroups) }
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
        requestJSONArray("groups", method: .post, parameters: ["lights" : lightIdentifiers as AnyObject, "name" : name as AnyObject, "type" : "LightGroup" as AnyObject]) { [weak self] response in
            guard let strongSelf = self else { return }
            switch response.result {
            case .failure(let error):
                // If group table is already full and `overwiteIfGroupTableIsFull` is `true`, we overwrite an existing group with the same name, if any
                if case .groupTableFull = error, overwiteIfGroupTableIsFull {
                    guard let group = strongSelf.groups.values.filter({ $0.name == name }).first else {
                        completion(.failure(.groupTableFull))
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

    private func refreshBridgeItems<T: PhilipsHueBridgeItem>(_ items: inout [String : T], from jsonItems: [String : [String : AnyObject]]) {
        items = jsonItems
            .flatMap { (identifier: String, json: [String : AnyObject]) -> T? in
                guard var item = T(bridge: self, identifier: identifier, json: json) else { return nil }
                if let existingItem = items[identifier] {
                    existingItem.refresh(from: item)
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

    internal func requestJSONObject(_ url: String, needsAuthorization: Bool = true, method: HTTPMethod = .get, parameters: [String : AnyObject]? = nil, completion: @escaping (PhilipsHueBridgeResponse<[String : AnyObject]>) -> ()) {
        return request(url, needsAuthorization: needsAuthorization, method: method, parameters: parameters, completion: completion)
    }

    internal func requestJSONArray(_ url: String, needsAuthorization: Bool = true, method: HTTPMethod = .get, parameters: [String : AnyObject]? = nil, completion: @escaping (PhilipsHueBridgeResponse<[[String : AnyObject]]>) -> ()) {
        return request(url, needsAuthorization: needsAuthorization, method: method, parameters: parameters, completion: completion)
    }

    private func request<Value>(_ url: String, needsAuthorization: Bool, method: HTTPMethod, parameters: [String : AnyObject]?, completion: @escaping (PhilipsHueBridgeResponse<Value>) -> ()) {
        var requestUrl = URL(string: "http://\(host)/api")!
        if needsAuthorization {
            guard let username = username else {
                completion(PhilipsHueBridgeResponse(result: .failure(.unauthorizedUser), duration: 0))
                return
            }
            requestUrl = requestUrl.appendingPathComponent(username)
        }
        requestUrl = requestUrl.appendingPathComponent(url)
        let _ = alamofire
            .request(requestUrl, method: method, parameters: parameters, encoding: JSONEncoding.default)
            .responseHueJSON { response in completion(response) }
    }

    internal func enqueueLightUpdate<T: PhilipsHueBridgeLightItem>(for light: T) {
        lightUpdateOperationQueue.addOperation(PhilipsHueLightUpdateOperation(light: light))
    }
}

internal protocol PhilipsHueBridgeItem: class {
    weak var bridge: PhilipsHueBridge? { get }
    var identifier: String { get }

    var stateUpdateUrl: String { get }
    /// Time interval needed by the bridge to properly apply the requested changes
    var stateUpdateDuration: TimeInterval { get }
    var stateUpdateParameters: [String : AnyObject] { get set }

    init?(bridge: PhilipsHueBridge, identifier: String, json: [String : AnyObject])

    func refresh(from: Self)
    func beginRefreshing()
    func endRefreshing()
}

public protocol PhilipsHueLightItem: class {
    var identifier:         String       { get }
    var transitionInterval: TimeInterval { get set }
    var isOn:               Bool         { get set }
    var brightness:         Float?       { get set }
    var hue:                Float?       { get set }
    var saturation:         Float?       { get set }
    var colorTemperature:   Float?       { get set }

    /// Any changes to light parameters won't be sent to the light until `endUpdates()` is called
    func beginUpdates()
    /// Sends all batched light parameter changes since the previous call to `beginUpdates()`
    func endUpdates()
}

internal typealias PhilipsHueBridgeLightItem = PhilipsHueBridgeItem & PhilipsHueLightItem

private class PhilipsHueLightUpdateOperation<T: PhilipsHueBridgeLightItem>: AsynchronousOperation {
    private weak var light: T?

    init(light: T) {
        self.light = light
        super.init()
    }

    fileprivate override func main() {
        guard
            var stateUpdateParameters = self.light?.stateUpdateParameters,
            let light = light,
            let bridge = light.bridge,
            stateUpdateParameters.count > 0
        else {
            complete()
            return
        }
        light.stateUpdateParameters = [:]
        stateUpdateParameters["transitiontime"] = Int((light.transitionInterval * 10.0).rounded().clamped(0, Double(UInt16.max))) as AnyObject
        print("write", light.stateUpdateUrl, stateUpdateParameters)
        bridge.requestJSONArray(light.stateUpdateUrl, method: .put, parameters: stateUpdateParameters) { [weak self] response in
            guard let strongSelf = self else { return }
            guard let light = strongSelf.light else {
                strongSelf.complete()
                return
            }
            switch response.result {
            case .failure(let error):
                print(error)
                if case .lightIsOff = error {
                    // Bridge tells us that the light is off, we update our `isOn` property as it might have the wrong state by now
                    light.beginRefreshing()
                    light.isOn = false
                    light.endRefreshing()
                }
                strongSelf.complete()
            case .success(let jsonObjects):
                print(jsonObjects)
                // To avoid light udates being queued on the Hue bridge, we delay subsequent light updates as specified by Philips Hue, i.e. 100msec per light and 1,000msec per group
                let remainingUpdateTime = light.stateUpdateDuration - response.duration
                if remainingUpdateTime > 0.01 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingUpdateTime) { strongSelf.complete() }
                }
                else {
                    strongSelf.complete()
                }
            }
        }
    }
}

private extension DataRequest {
    func responseHueJSON<Value>(completion: @escaping (PhilipsHueBridgeResponse<Value>) -> Void) -> Self {
        return responseJSON { dataResponse in
            switch dataResponse.result {
            case .failure(let error):
                completion(PhilipsHueBridgeResponse(result: .failure(.networkError(error)), duration: dataResponse.timeline.totalDuration))
            case .success(let value):
                if let error = dataResponse.hueError {
                    completion(PhilipsHueBridgeResponse(result: .failure(error), duration: dataResponse.timeline.totalDuration))
                    return
                }
                guard let json = value as? Value else {
                    completion(PhilipsHueBridgeResponse(result: .failure(.unexpectedResponse(value)), duration: dataResponse.timeline.totalDuration))
                    return
                }
                completion(PhilipsHueBridgeResponse(result: .success(json), duration: dataResponse.timeline.totalDuration))
            }
        }
    }
}

private extension DataResponse {
    var hueError: PhilipsHueError? {
        guard let error = (result.value as? [[String : AnyObject]])?.flatMap({$0["error"] as? [String : AnyObject]}).first else { return nil }
        return PhilipsHueError(code: error["type"] as? Int ?? -1)
    }
}

internal struct PhilipsHueBridgeResponse<Value> {
    let result: PhilipsHueResult<Value>
    /// The time interval in seconds from the time the request started to the time response serialization completed.
    let duration: TimeInterval
}
