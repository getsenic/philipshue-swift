//
//  AsynchronousOperation.swift
//  PhilipsHueDemo
//
//  Created by Lars Blumberg on 12/21/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Foundation

internal class AsynchronousOperation: Operation {
    override public var isAsynchronous: Bool { return true }

    private let stateLock = NSLock()

    private var _isExecuting: Bool = false
    override private(set) public var isExecuting: Bool {
        get {
            return stateLock.withCriticalScope { _isExecuting }
        }
        set {
            guard _isExecuting != newValue else { return }
            willChangeValue(forKey: "isExecuting")
            stateLock.withCriticalScope { _isExecuting = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _isFinished: Bool = false
    override private(set) public var isFinished: Bool {
        get {
            return stateLock.withCriticalScope { _isFinished }
        }
        set {
            guard _isFinished != newValue else { return }
            willChangeValue(forKey: "isFinished")
            stateLock.withCriticalScope { _isFinished = newValue }
            didChangeValue(forKey: "isFinished")
        }
    }

    override public func start() {
        guard !isCancelled else {
            isFinished = true
            return
        }
        isExecuting = true
        main()
    }

    override public func main() {
        fatalError("subclasses must override `main`")
    }

    public func complete() {
        isExecuting = false
        isFinished = true
    }
}

private extension NSLock {
    func withCriticalScope<T>(block: (Void) -> T) -> T {
        lock()
        let value = block()
        unlock()
        return value
    }
}
