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

internal extension Float {
    func clamped() -> Float { return max(0.0, min(1.0, self)) }
    func inversed() -> Float { return 1.0 / self }
    func toUInt() -> UInt { return UInt(self) }
}
