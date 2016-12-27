//
//  DiscoveryViewController.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/19/16.
//  Copyright © 2016 senic. All rights reserved.
//

import PhilipsHue
import UIKit

class DiscoveryViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    lazy var discoveryManager: PhilipsHueDiscoveryManager = PhilipsHueDiscoveryManager(delegate: self)

    var bridges: [String : PhilipsHueBridge] = [:]
    var sortedBridges: [PhilipsHueBridge] { return bridges.values.sorted { $0.0.host < $0.1.host } }

    override func viewDidLoad() {
        super.viewDidLoad()
        discoverBridges()
    }

    @IBAction func discoverBridges() {
        discoveryManager.startDiscovery()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        (segue.destination as! BridgeViewController).bridge = sender as! PhilipsHueBridge
    }
}

extension DiscoveryViewController: PhilipsHueDiscoveryManagerDelegate {
    func philipsHueDiscoveryManager(_ manager: PhilipsHueDiscoveryManager, didDiscoveryBridge bridge: PhilipsHueBridge) {
        bridges[bridge.host] = bridge
        tableView.reloadData()
    }
}

extension DiscoveryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bridges.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bridge", for: indexPath)
        cell.textLabel?.text = sortedBridges[indexPath.row].host
        return cell
    }
}

extension DiscoveryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "bridge", sender: sortedBridges[indexPath.row])
    }
}
