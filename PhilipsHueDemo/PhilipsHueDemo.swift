//
//  PhilipsHueDemo.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/16/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Foundation
import PhilipsHue

public class PhilipsHueDemo {
    public static let shared = PhilipsHueDemo()

    let bridge = PhilipsHueBridge(host: "192.168.1.83", username: "WuXoBjbkWhR4rxpmrLgkdEvAZ0JKPb7f6Rl0wV-D")

    public func runDemo() {
        guard let _ = bridge.username else {
            bridge.requestUsername(for: "HueDemo") { result in
                switch result {
                case .success(let username): print("Username: \(username)")
                case .failure(let error):    print("Requesting username failed: \(error)")
                }
            }
            return
        }

        bridge.refresh(completion: { result in
            switch result {
            case .failure(let error): print("Refresh error", error)
            case .success:            self.flashFirstLight()
            }
        })
    }

    public func flashFirstLight() {
        guard let light = bridge.lights.filter({$0.key == "5"}).first?.value else { return }
        light.isOn = false
        light.writeChanges()
    }
}
