//
//  NetGroup.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/19.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//

import Foundation

fileprivate final class WeakNetGroup {
    weak var group:NetGroup?
    
    init(_ group:NetGroup) {
        self.group = group
    }
    
    deinit {
        group?._observation = nil
        group?.cancel()
    }
}

fileprivate final class WeakOverlay {
    weak var overlay:NetOverlay?
    
    init(_ overlay:NetOverlay) {
        self.overlay = overlay
    }
}

@objc public protocol Resumable {
    func resume()
}

private var kAutoCancelNetGroup = "auto.cancel.net.group"
open class NetGroup: Resumable {
    
    public var progress:Progress = Progress(totalUnitCount: 0)
    
    public static let ErrorUserInfoKey = "key.net.group.userinfo"
    
    public func request(_ url:URL) -> NetDataRequest {
        let request = NetDataRequest(group: self, url: url)
        return request
    }
    
    var ongoingRequest:(URLSessionTask, NetRequest)? = nil
    var requests:[NetRequest] = []
    fileprivate var _overlays:[WeakOverlay] = []
    fileprivate var _states:[WeakContainer<Listener<NetGroup.State>>] = []
//    private var overlayStarts:[()->Void] = []
//    private var overlayStops:[()->Void] = []
//    private var overlayProgress:[(Progress)->Void] = []

    public var isInQueue:Bool { return _isInQueue }
    public var isLoading:Bool { return _isLoading }
    private var _isLoading:Bool = false
    func startOverlays() {
        
        _states = _states.filter {
            guard let state = $0.obj else { return false }
            state.value = .loading
            return true
        }
        
        // compactMap return $0
        _overlays = _overlays.filter {
            guard let overlay = $0.overlay else { return false }
            DispatchQueue.main.async { overlay.startNetOverlay() }
            return true
        }
        _isLoading = true
    }
    
    func setOverlaysProgress(_ request:Progress) {
        let current = progress.totalUnitCount == 0 ? 0 : 1 / Double(progress.totalUnitCount) * request.fractionCompleted
        let percent = progress.fractionCompleted + current

        _overlays = _overlays.filter {
            guard let overlay = $0.overlay else { return false }
            overlay.progressPercentChanged(percent)
            return true
        }
    }
    
    public func syncStates(from group:NetGroup) {
        _states = group._states.filter { $0.obj != nil }
    }
    public func syncOverlays(form group:NetGroup) {
        _overlays = group._overlays.filter { $0.overlay != nil }
    }
    
    public weak var retryOverlay:NetFailureRetryOverlay?
    public func failure(showRetryOn overlay:NetFailureRetryOverlay) -> Self {
        retryOverlay = overlay
        return self
    }
    
    public func change(state:Listener<State>) -> Self {
        
        _states <- WeakContainer<Listener<State>>(state)
        state.value = _isLoading ? .loading : .waiting
        
        return self
    }
    
    public var overlays:[NetOverlay] {
        return _overlays.compactMap { $0.overlay }
    }
    public var states:[Listener<NetGroup.State>] {
        return _states.compactMap { $0.obj }
    }
    
    fileprivate var _observation:NSKeyValueObservation?
    public func autoCancel<T:NSObject,Value>(onRelease target:T, andChanged keyPath:KeyPath<T,Value>) -> Self {
        _observation = target.observe(keyPath) {
            [weak self] _,_ in self?.cancel()
        }
        return autoCancel(onRelease: target)
    }
    public func autoCancel(onRelease target:AnyObject) -> Self {
        var list = objc_getAssociatedObject(target, &kAutoCancelNetGroup) as? [WeakNetGroup]
        if list == nil {
            list = [WeakNetGroup(self)]
        } else {
            list!.append(WeakNetGroup(self))
        }
        objc_setAssociatedObject(target, &kAutoCancelNetGroup, list, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return self
    }

    
    public func overlay(_ view:NetOverlay) -> Self {
        
        _overlays <- WeakOverlay(view)
        if _isLoading { view.startNetOverlay() }

        return self
    }
    
    public func append(_ request:NetRequest) {
        requests.append(request)
        progress.totalUnitCount += 1
    }
    
    public var count:Int {
        return requests.count + (ongoingRequest == nil ? 0 : 1)
    }
    
    public weak var queue:NetQueue?
    let retry:(NetGroup) -> Void
    
    public init(queue:NetQueue, retry: @escaping (NetGroup) -> Void) {
        self.queue = queue
        self.retry = retry
    }
    
    func createRequests() {
        requests.removeAll(keepingCapacity: true)
        progress.totalUnitCount = 0
        progress.completedUnitCount = 0
        retry(self)
    }
    
    public func resume() {
        startOverlays()
        createRequests()
        if !_isInQueue {
            queue?.groups.append(self)
            queue?.resume()
        } else {
            queue?.restart(group: self)
        }
    }
    
    func resume(session:URLSession) {
        if ongoingRequest != nil { return }
        if requests.count == 0 {
            _complete(with: nil)
            queue?.complete(group: self)
            return
        }
        let request = requests.removeFirst()
        let urlRequest = request.urlRequest
        let task = request.resumeTask(session: session, request: urlRequest) {
            [unowned session, weak request]
            (data, response, error, cancelContinue) in
            
            if  case .failureRequest(let err)? = error as? NetRequestError,
                (err as NSError?)?.code == -999,
                !cancelContinue{
                return
            }
//            if (error as NSError?)?.code == -999, !cancelContinue { return }
            
            guard let request = request else { return }
            guard let this = request.group else { return }
            
            // 如果上面没有 request的临时引用, 这句会将request释放掉,
            this.ongoingRequest = nil
            
            // 如果 解析 响应结果 成功 则继续进行组内下一条任务
            if request._decodeResponse?(this, urlRequest, response, data, error) ?? true {
                this.resume(session: session)
            } else {
                this.requests.removeAll(keepingCapacity: true)
            }
        }
        ongoingRequest = (task, request)
    }
    
    private func _complete(with error:Error?) {
        
        
        var this:NetGroup! = self
        if Thread.isMainThread {
            _completeHandle?(error)
            _overlays.forEach { $0.overlay?.stopNetOverlay() }
            _states.forEach { $0.obj?.value = error == nil ? .success : .failure }
            _isLoading = false
        } else {
            DispatchQueue.main.async {
                this._completeHandle?(error)
                this._overlays.forEach { $0.overlay?.stopNetOverlay() }
                this._states.forEach { $0.obj?.value = error == nil ? .success : .failure }
                this._isLoading = false
                this = nil
            }
        }

    }

    func failureCancel(with error:Error) {
        let group = self
        queue?.complete(group: self)
        group._isInQueue = false
        group._complete(with: error)
    }
    
    public func cancel() {
        
        var url:URL?
        if let (task, request) = ongoingRequest {
            url = request.url
            request.cancel(task: task)
            ongoingRequest = nil
        } else if requests.count == 0 {
            // 所有请求都已完成，不必取消
            queue?.complete(group: self)
            _isInQueue = false
            return
        }
        
        if url == nil { url = requests.first?.url }
        
        requests.removeAll(keepingCapacity: true)
        
        failureCancel(with: NetRequestError.canceled)
    }
    
    private var _isInQueue:Bool = false
    private var _completeHandle:((Error?) -> Void)?
    public func onComplete(_ callback: @escaping (Error?) -> Void) {
        _completeHandle = callback
        _isInQueue = true
        startOverlays()
        queue?.groups.append(self)
        queue?.resume()
    }
    
    lazy var sessionDelegate = NetSessionDelegate()
    
    deinit {
        if _isLoading {
            if Thread.isMainThread {
                _overlays.forEach { $0.overlay?.stopNetOverlay() }
                _states.forEach { $0.obj?.value = .failure }
            } else {
                let overlays = _overlays
                let states = _states
                DispatchQueue.main.async {
                    overlays.forEach { $0.overlay?.stopNetOverlay() }
                    states.forEach { $0.obj?.value = .failure }
                }
            }
        }
//        print("组释放",_isLoading)
    }
}
