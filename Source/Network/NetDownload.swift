//
//  NetDownload.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/23.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//

import Foundation

open class NetDownloadRequest : NetRequest {
    
    public var progress:Progress
    
    var _localURL:URL?
    
    public var localURL:URL {
        if let local = _localURL { return local }
        let fileName = url.lastPathComponent
        let encoder:NetEncoder = _encoder ?? Net.defaultEncoder
        let getURL = encoder.url(forRequest: self, withGetParams: _getParams)
        let bookmarkPath = Net.bookmarkPathFor(key: getURL.absoluteString)
        let bookmarkURL = URL(fileURLWithPath: bookmarkPath, isDirectory: true)
        let fileURL = bookmarkURL.appendingPathComponent(fileName, isDirectory: false)
        return fileURL
    }
    
    public init(request:NetRequest, local:URL? = nil) {
        progress = Progress(totalUnitCount: 0)//Progress(parent: request.group.progress)
        progress.totalUnitCount = 0
        progress.completedUnitCount = 0
        
        _localURL = local
        
        super.init(group: request.group!, url: request.url)
        progress.isCancellable = true
        progress.cancellationHandler = { [weak self] in self?.cancel() }
        progress.isPausable = true
        progress.pausingHandler = { [weak self] in self?.cancel() }
        
        _postParams = request._postParams
        _getParams = request._getParams
        _headers = request._headers
        _encoder = request._encoder
        _timeout = request._timeout
        _policy = request._policy
    }
    
    var _progress:((Progress) -> Void)?
    public func onProgressChanged(_ handler: @escaping (Progress) -> Void) -> Self {
        _progress = handler
        return self
    }
    func onProgress(totalSize:Int64, localSize:Int64) {
        progress.totalUnitCount = totalSize
        progress.completedUnitCount = localSize
        _progress?(progress)
        group?.setOverlaysProgress(progress)
    }

    override func resumeTask(session:URLSession, request:URLRequest, _ onComplete: @escaping (Data?, URLResponse?, Error?, Bool) -> Void) -> URLSessionTask {
                
        let getURL = request.url!.absoluteString
        
        // 用url绝对地址生成key 获得书签路径
        let bookmarkPath = Net.bookmarkPathFor(key: getURL) //_localURL?.relativePath ?? ""
        let cacheDataPath = bookmarkPath.stringByAppending(pathComponent: "download.data")
        
        let fileManager = FileManager.default
        
        // 文件不存在或不是目录 则创建
        var isDir:ObjCBool = false
        if !fileManager.fileExists(atPath: bookmarkPath, isDirectory: &isDir) || !isDir.boolValue {
            try! fileManager.createDirectory(atPath: bookmarkPath, withIntermediateDirectories: true, attributes: nil)
        }
        
        var task:URLSessionTask!
        // 如果文件存在 则 从断点续传 下载 否则 开始新的下载
        if fileManager.fileExists(atPath: cacheDataPath, isDirectory: &isDir) && !isDir.boolValue {
            let data = try! Data(contentsOf: URL(fileURLWithPath: cacheDataPath, isDirectory: false))
            
            try? fileManager.removeItem(atPath: cacheDataPath)
            
            task = session.downloadTask(withResumeData: data)
        } else {
            task = session.dataTask(with: request)
        }

        _complete = onComplete

        task.netRequest = self
        task.resume()
        return task
    }
    
    override func cancel(task: URLSessionTask) {
        guard let down = task as? URLSessionDownloadTask else { return super.cancel(task: task) }
        
        let getURL = self.getURL.absoluteString
        let bookmarkPath = Net.bookmarkPathFor(key: getURL) //_localURL?.relativePath ?? ""
        let cacheDataPath = bookmarkPath.stringByAppending(pathComponent: "download.data")
        let cacheDataURL = URL(fileURLWithPath: cacheDataPath, isDirectory: false)
        
        // 取消请求, 将恢复下载数据写入文件 以备断点续传使用
        down.cancel { ((try? $0?.write(to: cacheDataURL)) as ()??) }
    }
    
    func onComplete(_ data:Data?, _ response:URLResponse?, _ error:Error?) {
        _complete?(data, response, error, cancelContinue)
    }
    var cancelContinue:Bool = false
    var _complete:((Data?, URLResponse?, Error?, Bool) -> Void)?
}


private var KEY_NET_WEAK_REQUEST:String = "net.weak.request"
private var KEY_NET_WEAK_REQUEST_OBJ:String = "net.weak.request.obj"


private class WeakObject {
    weak var obj:NSObject?
    
    deinit {
        guard let item = obj else { return }
        objc_setAssociatedObject(item, &KEY_NET_WEAK_REQUEST, nil, .OBJC_ASSOCIATION_ASSIGN)
    }
}
internal extension URLSessionTask {
    
    /// netRequest is weak property
    var netRequest:NetRequest? {
        get {
            return objc_getAssociatedObject(self, &KEY_NET_WEAK_REQUEST) as? NetRequest
        }
        set {
            objc_setAssociatedObject(self, &KEY_NET_WEAK_REQUEST, newValue, .OBJC_ASSOCIATION_ASSIGN)
            // 定义一个跟随对象绑定到 目标, 当目标释放时 , 利用绑定对象的析构函数将属性设为nil
            if let v = newValue {
                let weakObj:WeakObject = objc_getAssociatedObject(v, &KEY_NET_WEAK_REQUEST_OBJ) as? WeakObject ?? WeakObject()
                weakObj.obj = self
                objc_setAssociatedObject(v, &KEY_NET_WEAK_REQUEST_OBJ, weakObj, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
}
