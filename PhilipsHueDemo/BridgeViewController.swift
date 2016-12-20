//
//  BridgeViewController.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/19/16.
//  Copyright © 2016 senic. All rights reserved.
//

import UIKit

class BridgeViewController: UIViewController {
    var bridge: PhilipsHueBridge!

    var groups: [PhilipsHueGroup] { return bridge.groups.values.sorted(by: { (lhs, rhs) -> Bool in return UInt(lhs.identifier)! < UInt(rhs.identifier)! }) }
    var lights: [PhilipsHueLight] { return bridge.lights.values.sorted(by: { (lhs, rhs) -> Bool in return UInt(lhs.identifier)! < UInt(rhs.identifier)! }) }

    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = bridge.host

        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.indexPathsForSelectedRows?.forEach { tableView.deselectRow(at: $0, animated: false) }
    }

    @IBAction func refresh() {
        bridge.refresh { [weak self] (result) in
            switch result {
            case .failure(let error): print(error)
            case .success(): self?.tableView.reloadData()
            }
        }
    }

    @IBAction func presentSettingsForSelectedLights() {
        performSegue(withIdentifier: "lights", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        (segue.destination as! LightSettingsViewController).lights = tableView.indexPathsForSelectedRows?.map { (indexPath) -> PhilipsHueLightItem in
            return indexPath.section == 0
                ? lights[indexPath.row]
                : groups[indexPath.row]
        } ?? []
    }
}

extension BridgeViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? bridge.lights.count : bridge.groups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let light = lights[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "light", for: indexPath)
            cell.textLabel?.text = light.identifier
            cell.detailTextLabel?.text = light.isReachable ? "Reachable" : "Not reachable"
            return cell
        }
        else {
            let group = groups[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "group", for: indexPath)
            cell.textLabel?.text = group.identifier
            cell.detailTextLabel?.text = String(describing: group.type)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Lights" : "Groups"
    }
}

extension BridgeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let light = lights[indexPath.row]
            light.alert = .select
            light.writeChanges()
        }
    }
}
