//
//  TreeType.swift
//  QuestionLib
//
//  Created by 慧趣小歪 on 16/4/29.
//  Copyright © 2016年 小分队. All rights reserved.
//

import Foundation


public protocol TreeType {
    
    // 必须实现
    
    /// mast use weak
    var parent: Self? { get set }
    
    var childs:[Self] { get set }
    var isRoot: Bool  { get }
    
    // 已实现
    /// 遍历树结构所有节点
    func enumerate(_ body: (Self) -> Void)
    
    /// 按条件更新所有子项
    mutating func set(childs items:[Self], isChild: (_ parent:Self, _ child:Self) throws -> Bool) rethrows
    
    /// 从列表到树结构
    static func rootsFromList(items:[Self], isChild: (_ parent:Self, _ child:Self) throws -> Bool) rethrows -> [Self]
    
    /// 包涵子项
    var hasChild:Bool { get }
}

extension TreeType {
    
    /// 从列表到树结构
    public static func rootsFromList(items:[Self], isChild: (_ parent:Self, _ child:Self) throws -> Bool) rethrows -> [Self] {
        var result:[Self] = []
        for var item in items {
            try item.set(childs: items, isChild: isChild)
            if item.isRoot { result.append(item) }
        }
        return result
    }
    
    /// 按条件更新所有子项
    public mutating func set(childs items:[Self], isChild: (_ parent:Self, _ child:Self) throws -> Bool) rethrows {
        childs.removeAll()
        for var item in items {
            if try isChild(self, item) {
                childs.append(item)
                item.parent = self
            }
        }
    }
    
    /// 遍历树结构所有节点
    public func enumerate(_ body: (Self) -> Void) {
        body(self)
        childs.forEach { $0.enumerate(body) }
    }
    
    public var hasChild:Bool { return childs.count > 0 }
}

extension Collection where Iterator.Element : TreeType {
    
    public func enumerate(body: (Iterator.Element) -> Void) {
        forEach { $0.enumerate(body) }
    }
}
