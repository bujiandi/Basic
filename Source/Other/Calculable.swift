//
//  Calculable.swift
//  Basic
//
//  Created by 慧趣小歪 on 2018/11/24.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif

public protocol Calculable: Comparable {
    
    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Self) -> Self
    static func / (lhs: Self, rhs: Self) -> Self
    
}

extension Int       : Calculable {}
extension Int8      : Calculable {}
extension Int16     : Calculable {}
extension Int32     : Calculable {}
extension Int64     : Calculable {}
extension UInt      : Calculable {}
extension UInt8     : Calculable {}
extension UInt16    : Calculable {}
extension UInt32    : Calculable {}
extension UInt64    : Calculable {}
extension Float     : Calculable {}
extension Double    : Calculable {}

#if canImport(CoreGraphics)

extension CGFloat   : Calculable {}
extension CGPoint   : Calculable {
    
    //@inline(__always)
    @inlinable public static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    @inlinable public static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    @inlinable public static func * (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x * rhs.x, y: lhs.y * rhs.y)
    }
    
    @inlinable public static func / (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x / rhs.x, y: lhs.y / rhs.y)
    }
    
    @inlinable public static func < (lhs: CGPoint, rhs: CGPoint) -> Bool {
        return lhs.x < rhs.x && lhs.y < rhs.y
    }
}
extension CGSize    : Calculable {
    
    @inlinable public static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    @inlinable public static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }
    
    @inlinable public static func * (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width * rhs.width, height: lhs.height * rhs.height)
    }
    
    @inlinable public static func / (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width / rhs.width, height: lhs.height / rhs.height)
    }
    
    @inlinable public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width < rhs.width && lhs.height < rhs.height
    }
}
extension CGRect    : Calculable {
    
    @inlinable public static func + (lhs: CGRect, rhs: CGRect) -> CGRect {
        return CGRect(origin: lhs.origin + rhs.origin, size: lhs.size + rhs.size)
    }
    
    @inlinable public static func - (lhs: CGRect, rhs: CGRect) -> CGRect {
        return CGRect(origin: lhs.origin - rhs.origin, size: lhs.size - rhs.size)
    }
    
    @inlinable public static func * (lhs: CGRect, rhs: CGRect) -> CGRect {
        return CGRect(origin: lhs.origin * rhs.origin, size: lhs.size * rhs.size)
    }
    
    @inlinable public static func / (lhs: CGRect, rhs: CGRect) -> CGRect {
        return CGRect(origin: lhs.origin / rhs.origin, size: lhs.size / rhs.size)
    }
    
    @inlinable public static func < (lhs: CGRect, rhs: CGRect) -> Bool {
        return lhs.origin < rhs.origin && lhs.size < rhs.size
    }
}
#endif
