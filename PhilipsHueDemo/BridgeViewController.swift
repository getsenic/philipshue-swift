//
//  BridgeViewController.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/19/16.
//  Copyright © 2016 senic. All rights reserved.
//

import PhilipsHue
import UIKit

class BridgeViewController: UIViewController {
    var bridge: PhilipsHueBridge!

    var groups: [PhilipsHueGroup] { return bridge.groups.values.sorted(by: { (lhs, rhs) -> Bool in return UInt(lhs.identifier)! < UInt(rhs.identifier)! }) }
    var lights: [PhilipsHueLight] { return bridge.lights.values.sorted(by: { (lhs, rhs) -> Bool in return UInt(lhs.identifier)! < UInt(rhs.identifier)! }) }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var lightAttributesButton: UIButton!
    @IBOutlet weak var lightAttributesActivitiyIndicator: UIActivityIndicatorView!

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
        guard let selectedIndexPaths = tableView.indexPathsForSelectedRows, selectedIndexPaths.count > 0 else { return }

        let selectedLights = selectedIndexPaths.flatMap{ ($0.section == 0) ? [lights[$0.row]] : groups[$0.row].lights }

        // If only one light is selected, present settings for this light
        if selectedLights.count == 1, let selectedLight = selectedLights.first {
            performSegue(withIdentifier: "light", sender: selectedLight)
            return
        }

        // Since more lights are selected, we need to first find a group that consists exactly of these lights or create a new group for them
        lightAttributesButton.isEnabled = false
        lightAttributesActivitiyIndicator.startAnimating()

        bridge.getOrCreateGroup(for: selectedLights, name: "PhilipsHueDemo", overwiteIfGroupTableIsFull: true) { [weak self] result in
            guard let strongSelf = self else { return }

            strongSelf.lightAttributesActivitiyIndicator.stopAnimating()
            strongSelf.lightAttributesButton.isEnabled = true

            switch result {
            case .failure(let error):
                let alertController = UIAlertController(title: "Failed getting or creating group", message: "\(error.localizedDescription)\n\((error as NSError).localizedFailureReason ?? "")", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                strongSelf.present(alertController, animated: true) {}
            case .success(let group):
                strongSelf.performSegue(withIdentifier: "light", sender: group)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        (segue.destination as! LightSettingsViewController).light = sender as! PhilipsHueLightItem
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
            cell.textLabel?.text = "[\(light.identifier)] \(light.name)"
            cell.detailTextLabel?.text = "\(light.manufacturer) \(light.model) (\(light.isReachable ? "Reachable" : "Not reachable"))"
            return cell
        }
        else {
            let group = groups[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "group", for: indexPath)
            cell.textLabel?.text = "[\(group.identifier)] \(group.name)"
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
