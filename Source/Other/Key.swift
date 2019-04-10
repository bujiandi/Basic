//
//  Key.swift
//  Tools
//
//  Created by 慧趣小歪 on 2017/10/17.
//

import Foundation

public struct Key : RawRepresentable {
    public typealias RawValue = String
    public let  rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension Key : CustomStringConvertible {
    public var description: String { return rawValue.description }
}

extension Key : Hashable {
    public var hashValue: Int { return rawValue.hashValue }
}

extension Key : ExpressibleByStringLiteral {
    public typealias StringLiteralType = StaticString
    public typealias UnicodeScalarLiteralType = UnicodeScalarType
    public typealias ExtendedGraphemeClusterLiteralType = String
    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        rawValue = value
    }
    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        rawValue = value.description
    }
    public init(stringLiteral value: StringLiteralType) {
        rawValue = value.description
    }
}
