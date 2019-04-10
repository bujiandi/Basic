//
//  NetRequest.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/19.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//

import Foundation

public protocol NetSuccessable {}


open class NetRequest {
    
//    deinit {
//        print("请求释放:\(url)")
//    }
 
    public weak var group:NetGroup?
    public let url:URL
    
    var _policy:URLRequest.CachePolicy = .reloadIgnoringLocalCacheData
    public var policy:URLRequest.CachePolicy { return _policy }
    
    var _timeout:TimeInterval? = nil
    public var timeout:TimeInterval { return _timeout ?? Net.timeout }

    public var queue:NetQueue? { return group?.queue }

    public init(group:NetGroup, url:URL) {
        self.group = group
        self.url = url
    }
    
    var _postParams:[(String, () -> Any)] = []
    var _getParams:[(String, () -> Any)] = []
    var _headers:[String:String] = [:]
    var _encoder:NetEncoder?
    
    public func params(encoder:NetEncoder) -> Self {
        _encoder = encoder
        return self
    }
    
    public func param(post key:String, values: [Any]) -> Self {
        for value in values {
            _ = param(post: key, closure: { value })
        }
        return self
    }
    
    public func param(post key:String, more: Any ...) -> Self {
        return param(post: key, values: more)
    }
    
    public func param<T:RawRepresentable>(post key:String, value closure: @autoclosure () -> T) -> Self {
        let value = closure()
        return param(post: key, closure: { value.rawValue })
    }
    
    public func param(post key:String, value closure: @autoclosure () -> Any) -> Self {
        let value = closure()
        return param(post: key, closure: { value })
    }
    
    public func param(post key:String, closure: @escaping () -> Any) -> Self {
        _postParams.append((key, closure))
        return self
    }
    
    public func param(get key:String, values: [Any]) -> Self {
        for value in values {
            _ = param(get: key, closure: { value })
        }
        return self
    }
    
    public func param(get key:String, more: Any ...) -> Self {
        return param(get: key, values: more)
    }
    
    public func param(get key:String, value closure: @autoclosure () -> Any) -> Self {
        let value = closure()
        return param(get: key, closure: { value })
    }
    
    public func param(get key:String, closure: @escaping () -> Any) -> Self {
        _getParams.append((key, closure))
        return self
    }
    
    public func header(key:String, value closure: @autoclosure () -> String) -> Self {
        _headers[key] = closure()
        return self
    }
    
    public func cachePolicy(_ policy:URLRequest.CachePolicy) -> Self {
        _policy = policy
        return self
    }
    
    public func autoFailureAfter(timeout:TimeInterval) -> Self {
        if timeout > 0 { _timeout = timeout }
        return self
    }
    
    public func cancel() {
        group?.cancel()
    }
    
    public var getURL:URL {
        let encoder:NetEncoder = _encoder ?? Net.defaultEncoder
        var url = self.url
        
        if _getParams.count > 0 {
            url = encoder.url(forRequest: self, withGetParams: _getParams)
        }
        
        return url
    }
    
    public var urlRequest:URLRequest {
        
        let encoder:NetEncoder = _encoder ?? Net.defaultEncoder
        
        let (url, postData) = encoder.encode(request: self)

//        let url = getURL
        
        var request = URLRequest(url: url, cachePolicy: policy, timeoutInterval: timeout)

        if let data = postData {
            
            #if DEBUG
            print("REQUEST:", url)
            print("POST:", data.string(encoding: .utf8) ?? "data unknow charset")
            #endif

            request.httpMethod = "POST"
            request.httpBody = data
            request.addValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        } else {
            
            request.httpMethod = "GET"
        }
        
        // 如果有自定义 头信息
        for (key, value) in _headers where !key.isEmpty {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Accept-Encoding HTTP Header; see https://tools.ietf.org/html/rfc7230#section-4.2.3
        if _headers["Accept-Encoding"] == nil {
            request.addValue("gzip;q=1.0, compress;q=0.5", forHTTPHeaderField: "Accept-Encoding")
        }
        
        // Accept-Language HTTP Header; see https://tools.ietf.org/html/rfc7231#section-5.3.5
        if _headers["Accept-Language"] == nil {
            request.addValue(Net.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        }
        
        if _headers["User-Agent"] == nil {
            request.addValue(Net.userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        return request
    }
    
    // 最后一个bool值是给下载使用, 如果发现服务端和客户端一样, 取消下载但仍然成功
    func resumeTask(session:URLSession, request:URLRequest, _ onComplete: @escaping (Data?, URLResponse?, Error?, Bool) -> Void) -> URLSessionTask {
        
        let task = session.dataTask(with: request) {
            (data:Data?, response:URLResponse?, error:Error?) in
            onComplete(data, response, error, false)
        }
        task.netRequest = self
        task.resume()
        return task
    }
    
    func cancel(task:URLSessionTask) {
        task.cancel()
    }
    
    var _decodeResponse:((NetGroup, URLRequest, URLResponse?, Data?, Error?) -> Bool)?
}

open class NetDataRequest : NetRequest {
    
    /// 转为上传请求
    public func upload(_ formClosure: (NetUploadForm) -> Void) -> NetUploadRequest {
        let form = NetUploadForm()
        let request = NetUploadRequest(request: self, form: form)
        formClosure(form)
        return request
    }
    
    /// 转为下载请求
    public func download(toURL localURL:URL) -> NetDownloadRequest {
        return NetDownloadRequest(request: self, local: localURL)
    }
    
    /// 转为下载请求
    public func download(toPath localPath:String) -> NetDownloadRequest {
        return download(toURL: URL(fileURLWithPath: localPath))
    }
    
    /// 转为下载请求
    public func downloadToCache() -> NetDownloadRequest {
        return NetDownloadRequest(request: self)
    }
}


extension NetSuccessable where Self : NetRequest {
    
    @discardableResult
    public func responseData<T:NetDecoder>(decoder:T, onSuccess: @escaping (T.Result) throws -> Void) -> Self {
        
        _decodeResponse = { //[unowned self]
            (group:NetGroup, request:URLRequest, response:URLResponse?, data:Data?, netErr:Error?) in
            
            // 如果不是HTTP响应
            guard let httpRes  = response as? HTTPURLResponse else {
                
                if (netErr as NSError?)?.code == -999 {
                    group.failureCancel(with: NetRequestError.canceled)
                } else {
                    group.failureCancel(with: NetRequestError.failureRequest(netErr!))
                }
                return false
            }
            
            let statusCode = httpRes.statusCode
            // 如果状态码异常
            guard (200..<300).contains(statusCode), let httpData = data else {
                let code = httpRes.statusCode
                let domain = (netErr as NSError?)?.domain ?? NSURLErrorDomain
                let text = domain == NSURLErrorDomain ? HTTPURLResponse.localizedString(forStatusCode: code) : domain
                group.failureCancel(with: NetRequestError.failStatusCode(code, text))
                return false
            }
            
//            DispatchQueue.main.sync {
//                do {
//                    try onSuccess(try decoder.decode(response: httpRes, data: httpData))
//                } catch {
//                    group.failureCancel(with: error)
//                    decodeSuccess = false
//                }
//            }
            
            var result:T.Result! = nil
            do {
                result = try decoder.decode(request: request, response: httpRes, data: httpData)
            } catch {
                group.failureCancel(with: error)
                return false
            }
            
            // 如果如果成功解析
            var decodeSuccess:Bool = true

            let callSuccess = {
                do {
                    try onSuccess(result)
                } catch {
                    group.failureCancel(with: error)
                    decodeSuccess = false
                }
            }
            // 减少主线程性能消耗, 只将最后一步给主线程
            if Thread.isMainThread {
                callSuccess()
            } else {
                DispatchQueue.main.sync(execute: callSuccess)
            }
            
            return decodeSuccess
        }
        group?.append(self)
        return self
    }
}

extension NetRequest : NetSuccessable {}
