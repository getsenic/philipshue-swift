//
//  Math.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/21/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Foundation

internal extension Int {
    func toFloat() -> Float { return Float(self) }
}

internal extension UInt {
    static let minMired: UInt = 153 // ~6500K (coldest color temperatur)
    static let maxMired: UInt = 500 // =2000K (warmest color temperature)

    func divided(by divisor: Float) -> Float { return Float(self) / divisor }
    func toNormalizedMired() -> Float { return ((Float(self - UInt.minMired)) / Float(UInt.maxMired - UInt.minMired)).clamped() }
}

internal extension Float {
    func clamped(_ minimum: Float = 0.0, _ maximum: Float = 1.0) -> Float { return max(minimum, min(maximum, self)) }
    func toUInt() -> UInt { return UInt(self) }
    func toMired() -> UInt { return UInt.minMired + UInt(clamped() * Float(UInt.maxMired - UInt.minMired)) }
}
