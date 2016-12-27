//
//  Math.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/21/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Foundation

internal extension Int {
    static let minMired = 153 // ~6500K (coldest color temperatur)
    static let maxMired = 500 // =2000K (warmest color temperature)

    func toNormalizedBrightness() -> Float { return (Float(self) / 254.0).clamped() }
    func toNormalizedHue()        -> Float { return (Float(self) / 65535.0).clamped() }
    func toNormalizedSaturation() -> Float { return (Float(self) / 254.0).clamped() }
    func toNormalizedMired()      -> Float { return ((Float(self - Int.minMired)) / Float(Int.maxMired - Int.minMired)).clamped() }
}

internal extension Float {
    func toBrightness() -> Int { return Int(self.clamped() * 254.0) }
    func toHue()        -> Int { return Int(self.clamped() * 65535.0) }
    func toSaturation() -> Int { return Int(self.clamped() * 254.0) }
    func toMired()      -> Int { return Int(self.clamped() * Float(Int.maxMired - Int.minMired)) + Int.minMired }

    func clamped(_ minimum: Float = 0.0, _ maximum: Float = 1.0) -> Float { return max(minimum, min(maximum, self)) }
}

internal extension Double {
    func clamped(_ minimum: Double = 0.0, _ maximum: Double = 1.0) -> Double { return max(minimum, min(maximum, self)) }
}
