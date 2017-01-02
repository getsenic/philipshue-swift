//
//  PhilipsHueDiscoveryManager.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/27/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Alamofire
import CocoaSSDP

public class PhilipsHueDiscoveryManager {
    public weak var delegate: PhilipsHueDiscoveryManagerDelegate?

    private var apiDataRequest: DataRequest?
    private lazy var ssdpServiceBrowser: SSDPServiceBrowser = { let b = SSDPServiceBrowser(); b.delegate = self; return b }()
    private var ssdpDiscoveryTimeoutTimer: Timer?
    private var foundHosts: [String] = []

    public init(delegate: PhilipsHueDiscoveryManagerDelegate? = nil) {
        self.delegate = delegate
    }

    public func startDiscovery(timeoutInterval: TimeInterval = 10.0) {
        cancelDiscovery()
        foundHosts = []
        startNUPnPDiscovery(timeoutInterval: timeoutInterval)
        startSSDPDiscovery(timeoutInterval: timeoutInterval)
    }

    private func startNUPnPDiscovery(timeoutInterval: TimeInterval) {
        apiDataRequest = Alamofire
            .request(URLRequest(url: URL(string: "https://www.meethue.com/api/nupnp")!, timeoutInterval: timeoutInterval))
            .responseJSON { [weak self] response in
                guard let strongSelf = self else { return }
                switch response.result {
                case .failure(let error):
                    strongSelf.delegate?.philipsHueDiscoveryManager(strongSelf, didEncounterError: .networkError(error))
                case .success(let jsonResponse):
                    guard let hosts = (jsonResponse as? [[String : String]]) else {
                        strongSelf.delegate?.philipsHueDiscoveryManager(strongSelf, didEncounterError: .unexpectedResponse(jsonResponse))
                        return
                    }
                    hosts.flatMap { $0["internalipaddress"] }.forEach { strongSelf.didFindHost($0) }
                }
        }
    }

    private func startSSDPDiscovery(timeoutInterval: TimeInterval) {
        ssdpServiceBrowser.startBrowsing(forServices: "urn:schemas-upnp-org:device:basic:1")
        ssdpDiscoveryTimeoutTimer = Timer.scheduledTimer(timeInterval: timeoutInterval, target: ssdpServiceBrowser, selector: #selector(ssdpServiceBrowser.stopBrowsingForServices), userInfo: nil, repeats: false)
    }

    fileprivate func didFindHost(_ host: String) {
        guard !foundHosts.contains(host) else { return }
        foundHosts += [host]
        delegate?.philipsHueDiscoveryManager(self, didDiscoverBridge: PhilipsHueBridge(host: host))
    }

    public func cancelDiscovery() {
        apiDataRequest?.cancel()
        ssdpServiceBrowser.stopBrowsingForServices()
        ssdpDiscoveryTimeoutTimer?.invalidate()
    }
}

public enum PhilipsHueDiscoveryManagerError: Error {
    case networkError(Error)
    case unexpectedResponse(Any)
}

extension PhilipsHueDiscoveryManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkError(let error):          return "Network error: \(error.localizedDescription)"
        case .unexpectedResponse(let response): return "Unexpected response: \(response)"
        }
    }
}

extension PhilipsHueDiscoveryManager: SSDPServiceBrowserDelegate {
    @objc public func ssdpBrowser(_ browser: SSDPServiceBrowser!, didFind service: SSDPService!) {
        guard
            service.server?.contains("IpBridge") ?? false,
            let host = service.location?.host
        else {
            return
        }
        didFindHost(host)
    }

    @objc public func ssdpBrowser(_ browser: SSDPServiceBrowser!, didRemove service: SSDPService!) {
        // NOP
    }

    @objc public func ssdpBrowser(_ browser: SSDPServiceBrowser!, didNotStartBrowsingForServices error: Error!) {
        delegate?.philipsHueDiscoveryManager(self, didEncounterError: .networkError(error))
    }
}

public protocol PhilipsHueDiscoveryManagerDelegate: class {
    func philipsHueDiscoveryManager(_ manager: PhilipsHueDiscoveryManager, didDiscoverBridge bridge: PhilipsHueBridge)
    func philipsHueDiscoveryManager(_ manager: PhilipsHueDiscoveryManager, didEncounterError error: PhilipsHueDiscoveryManagerError)
}
