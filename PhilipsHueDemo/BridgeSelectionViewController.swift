//
//  BridgeSelectionViewController.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/19/16.
//  Copyright © 2016 senic. All rights reserved.
//

import PhilipsHue
import UIKit

class BridgeSelectionViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var bridges: [PhilipsHueBridge] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        discoverBridges()
    }

    @IBAction func discoverBridges() {
        //TODO: Implement discovery
        bridges = [PhilipsHueBridge(host: "192.168.1.83", username: "WuXoBjbkWhR4rxpmrLgkdEvAZ0JKPb7f6Rl0wV-D")]
        tableView.reloadData()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        (segue.destination as! BridgeViewController).bridge = sender as! PhilipsHueBridge
    }
}

extension BridgeSelectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bridges.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bridge", for: indexPath)
        cell.textLabel?.text = bridges[indexPath.row].host
        return cell
    }
}

extension BridgeSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "bridge", sender: bridges[indexPath.row])
    }
}
