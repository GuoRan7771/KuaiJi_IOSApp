//
//  Logging.swift
//  KuaiJi
//

import Foundation

@inlinable
public func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    Swift.print(message, terminator: terminator)
#endif
}


