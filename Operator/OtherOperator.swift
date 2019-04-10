//
//  Operator.swift
//  NetWork
//
//  Created by 慧趣小歪 on 16/3/25.
//  Copyright © 2016年 小分队. All rights reserved.
//
//  那些曾被Swift删除但是很有用的运算符
//

import CoreGraphics
import Foundation

precedencegroup NilWrapPrecedence {
    associativity: right
    higherThan: AssignmentPrecedence
    lowerThan: LogicalConjunctionPrecedence
}
/// 可选赋值运算符 有则赋值, 没有忽略
infix operator ??? : NilWrapPrecedence
infix operator =? : AssignmentPrecedence

@inline(__always)
public func ??(lhs:Bool, rhs: @autoclosure () -> Void) {
    if lhs { rhs() }
}

@inline(__always)
public func ??<T>(lhs:Bool, rhs: @autoclosure () -> T?) -> T? {
    return lhs ? rhs() : nil
}

@inline(__always)
public func ???<T>(lhs: @autoclosure () -> T?, rhs: Bool) -> T? {
    return rhs ? lhs() : nil
}

@inline(__always)
public func ???<T>(lhs: @autoclosure () -> T, rhs: Bool) -> T? {
    return rhs ? lhs() : nil
}

/// 可选赋值运算符 有则赋值, 没有忽略
@inline(__always)
public func =?(lhs: inout CGFloat, rhs: Double?) {
    if let v = rhs { lhs = CGFloat(v) }
}

/// 可选赋值运算符 有则赋值, 没有忽略
@inline(__always)
public func =?(lhs: inout CGFloat?, rhs: Double?) {
    if let v = rhs { lhs = CGFloat(v) }
}

/// 可选赋值运算符 有则赋值, 没有忽略
@inline(__always)
public func =?<T>(lhs: inout T, rhs: T?) {
    if let v = rhs { lhs = v }
}

/// 可选赋值运算符 有则赋值, 没有忽略
@inline(__always)
public func =?<T>(lhs: inout T?, rhs: T?) {
    if let v = rhs { lhs = v }
}

/// 可选值相乘
@inline(__always)
public func *<T>(lhs: T?, rhs: T) -> T? where T : FloatingPoint {
    if let v = lhs { return v * rhs }
    return nil
}
/*
这里给出常用类型对应的group

infix operator ||   : LogicalDisjunctionPrecedence
infix operator &&   : LogicalConjunctionPrecedence
infix operator <    : ComparisonPrecedence
infix operator <=   : ComparisonPrecedence
infix operator >    : ComparisonPrecedence
infix operator >=   : ComparisonPrecedence
infix operator ==   : ComparisonPrecedence
infix operator !=   : ComparisonPrecedence
infix operator ===  : ComparisonPrecedence
infix operator !==  : ComparisonPrecedence
infix operator ~=   : ComparisonPrecedence
infix operator ??   : NilCoalescingPrecedence
infix operator +    : AdditionPrecedence
infix operator -    : AdditionPrecedence
infix operator &+   : AdditionPrecedence
infix operator &-   : AdditionPrecedence
infix operator |    : AdditionPrecedence
infix operator ^    : AdditionPrecedence
infix operator *    : MultiplicationPrecedence
infix operator /    : MultiplicationPrecedence
infix operator %    : MultiplicationPrecedence
infix operator &*   : MultiplicationPrecedence
infix operator &    : MultiplicationPrecedence
infix operator <<   : BitwiseShiftPrecedence
infix operator >>   : BitwiseShiftPrecedence
infix operator ..<  : RangeFormationPrecedence
infix operator ...  : RangeFormationPrecedence
infix operator *=   : AssignmentPrecedence
infix operator /=   : AssignmentPrecedence
infix operator %=   : AssignmentPrecedence
infix operator +=   : AssignmentPrecedence
infix operator -=   : AssignmentPrecedence
infix operator <<=  : AssignmentPrecedence
infix operator >>=  : AssignmentPrecedence
infix operator &=   : AssignmentPrecedence
infix operator ^=   : AssignmentPrecedence
infix operator |=   : AssignmentPrecedence
 
infix operator ?=   : AssignmentPrecedence
infix operator <-   : AssignmentPrecedence

*/
