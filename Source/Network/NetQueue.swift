//
//  NetQueue.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/19.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//

import Foundation

open class NetQueue {
    
    private var _concurrently:Int
    
    public var threadQueue:DispatchQueue = DispatchQueue(label: "com.fenfen.net.queue", attributes: .concurrent)
    //DispatchQueue.global(qos: .utility)
    // 同时进行的任务数量
    public init(concurrentlyCount:Int) {
        _concurrently = concurrentlyCount
    }
    public init() {
        _concurrently = 1
    }
    
    public func cancelAll() {
        threadQueue.async(flags: .barrier) { [weak self] in
            guard let this = self else { return }
            let list = this.ongoingGroups
            this.ongoingGroups.removeAll(keepingCapacity: true)
            list.forEach { $0.0.invalidateAndCancel() }
        }
    }
    
    deinit {
        var sessions:[URLSession]! = ongoingGroups.map { $0.0 }
        threadQueue.async(flags: .barrier) {
            sessions.forEach { $0.invalidateAndCancel() }
            sessions = nil
        }
    }
    
    /// 请求正在进行的组
    lazy var ongoingGroups:[(URLSession, NetGroup)] = {
        var list = [(URLSession, NetGroup)]()
        list.reserveCapacity(_concurrently)
        return list
    }()
    
    /// 队列中等待执行的组
    internal var groups:[NetGroup] = [] 
}

// MARK: - 主要
extension NetQueue {
    
    /// 创建 HTTP 请求组
    open func http(_ createGroup: @escaping (NetGroup) -> Void) -> NetGroup {
        let group = NetGroup(queue: self, retry: createGroup)
        group.createRequests()
        return group
    }
    
//    // 创建单一请求的请求组
//    open func request(_ url:URL) -> NetDataRequest {
//        var request:NetDataRequest!
//        let group = NetGroup(queue: self) {
//            request = $0.request(url)
//        }
//        
//        return request
//    }

    func resume() {
        if Thread.isMainThread {
            _resume()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?._resume()
            }
        }
    }
    
    private func _resume() {
        while groups.count > 0, ongoingGroups.count < _concurrently {
            let group = groups.removeFirst()
            
            let session = sessionFactory(group)
            
            // 跳过数量为空的组
            if group.count == 0 { continue }
            
            // 将有任务的组添加到请求队列
            ongoingGroups.append((session, group))
            group.ongoingRequest = nil
            group.resume(session: session)
        }
    }
    
    func restart(group:NetGroup) {
        if let (task, request) = group.ongoingRequest {
            request.cancel(task: task)
            group.ongoingRequest = nil
        }
        for (session, ongoing) in ongoingGroups where ongoing === group {
            group.resume(session: session)
        }
    }
    
    func complete(group:NetGroup) {
        // 为了确保线程安全, 所以在统一线程队列中
        threadQueue.async(flags: .barrier) { [weak self] in
            guard let this = self else { return }
            if let index = this.ongoingGroups.firstIndex(where: { $0.1 === group }) {
                // 非默认shared URLSession 释放前如果不取消，会引发循环引用
                let (session, _) = this.ongoingGroups.remove(at: index)
                session.invalidateAndCancel()

                this.resume()
            }
        }
    }
    
    func sessionFactory(_ group:NetGroup) -> URLSession {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: group.sessionDelegate, delegateQueue: nil)
        
        return session
    }
}


// MARK: - 数量
extension NetQueue {
    
    public func cancel(where block:(NetGroup) -> Bool) {
        var needResume:Bool = false
        for (i, group) in groups.enumerated().reversed() where block(group) {
            groups.remove(at: i)
        }
        for (i, (session, group)) in ongoingGroups.enumerated().reversed() where block(group) {
            threadQueue.async(flags: .barrier) { [weak self] in
                self?.ongoingGroups.remove(at: i)
                session.invalidateAndCancel()
            }
            needResume = true
        }
        if needResume {
            threadQueue.async(flags: .barrier) { [weak self] in self?.resume() }
        }
    }
    
    /// 能同时进行的网络请求组数量 [>= 1]
    public var concurrentlyCount:Int {
        get { return _concurrently }
        set {
            // 如果设置的数量小于 1 则忽略
            if newValue < 1 { return }
            _concurrently = newValue
            // 移除多余正在进行的组，并取消组请求，重新加入队列顶部
            while ongoingGroups.count > newValue {
                let (_, last) = ongoingGroups.removeLast()
                last.cancel()
                groups.insert(last, at: 0)
            }
            ongoingGroups.reserveCapacity(newValue)
        }
    }
    
    /// 正在执行的组数量
    public var ongoingCount:Int {
        return ongoingGroups.count
    }
    
    /// 队列中 请求组数量
    public var count:Int {
        return groups.count + ongoingGroups.count
    }
    
    /// 队列中 所有组 总请求数量
    public var requestCount:Int {
        let list = groups + ongoingGroups.map { $0.1 }
        return list.reduce(0) { $0 + $1.count }
    }
    
}
