//
//  PhilipsHueResult.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/21/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Foundation

public enum PhilipsHueError: Error {
    case usernameNotSet
    case unauthorizedUser
    case resourceNotAvailable
    case parameterNotAvailable
    case linkButtonNotPressed
    case lightIsOff
    case groupTableFull
    case unexpectedErrorCode(Int)
    case unexpectedResponse(Any)
    case networkError(Error)

    init(code: Int) {
        switch code {
        case   1: self = .unauthorizedUser
        case   3: self = .resourceNotAvailable
        case   6: self = .parameterNotAvailable
        case 101: self = .linkButtonNotPressed
        case 201: self = .lightIsOff
        case 301: self = .groupTableFull
        default:  self = .unexpectedErrorCode(code)
        }
    }
}

extension PhilipsHueError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .usernameNotSet:                   return "Username not set"
        case .unauthorizedUser:                 return "User not authorized"
        case .resourceNotAvailable:             return "Resource not available"
        case .parameterNotAvailable:            return "Parameter not available"
        case .linkButtonNotPressed:             return "Link Button not pressed"
        case .lightIsOff:                       return "Light is off"
        case .groupTableFull:                   return "Cannot create group, group table already full"
        case .unexpectedErrorCode(let code):    return "Unexpected error code: \(code)"
        case .unexpectedResponse(let response): return "Unexpected response: \(response)"
        case .networkError(let error):          return "Network error: \(error)"
        }
    }
}

public enum PhilipsHueResult<Value> {
    case success(Value)
    case failure(PhilipsHueError)
}
