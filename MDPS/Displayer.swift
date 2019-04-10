//
//  Displayer.swift
//  Basic
//
//  Created by 李招利 on 2018/11/19.
//


public protocol Viewer {
    
    
}


public protocol ViewBinder {
    
    associatedtype View
    associatedtype Data
    
    func update(_ view:View, by data:Data)
}

extension Viewer {
    
    public func display<VB:ViewBinder>(_ binder:VB, by data:VB.Data) where Self == VB.View {
        binder.update(self, by: data)
    }
    
}
