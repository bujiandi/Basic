//
//  NetUpload.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/23.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//
#if canImport(Basic)
import Basic
#endif
import Foundation

private let newLineCRLF = "\r\n".data(using: .utf8)!

open class NetUploadEncoder: NetEncoder {
    
    public init() {}

    open func sign(request: NetRequest, params: inout [(String, Any)]) {
        
    }
    
    open func encode(request: NetRequest) -> (URL, Data?) {
        let url = self.url(forRequest: request, withGetParams: request._getParams)
        
        var postParams = request._postParams.map { ($0.0, $0.1() ) }
        sign(request: request, params: &postParams)
        
        guard let upload = request as? NetUploadRequest else {
            return (url, nil)
        }
        
        var data = upload.form.data
        let boundary = upload.form.boundary
        
        #if DEBUG
        print("REQUEST:", url)
        var printData = Data()
        #endif
        
        if !postParams.isEmpty {
            
            for (key, value) in postParams {
                let val = unwrapOptionalToString(value)
                data.append("--\(boundary)")
                data.append(newLineCRLF)
                data.append("Content-Disposition: form-data; name=\"\(key)\"")
                data.append(newLineCRLF)
                data.append(newLineCRLF)
                data.append(val)
                data.append(newLineCRLF)
                #if DEBUG
                printData.append("--\(boundary)")
                printData.append(newLineCRLF)
                printData.append("Content-Disposition: form-data; name=\"\(key)\"")
                printData.append(newLineCRLF)
                printData.append(newLineCRLF)
                printData.append(val)
                printData.append(newLineCRLF)
                #endif
            }
        }
        data.append("--\(boundary)--")
        data.append(newLineCRLF)
        #if DEBUG
        printData.append("--\(boundary)--")
        printData.append(newLineCRLF)
        print("POST:", String(data: printData, encoding: .utf8)!)
        #endif

        return (url, data)
    }
    
}

open class NetUploadForm {
    
    //fenfen.boundary.%08x%08x
    //Boundary+%08X%08X
    fileprivate lazy var boundary:String = String(format: "fenfen.net.boundary.%08x%08x", arc4random(), arc4random())
    
    fileprivate lazy var data = Data()
    
    public func append(data:Data) {
        self.data.append("--\(boundary)")
        self.data.append(newLineCRLF)
        self.data.append("Content-Disposition: form-data")
        
        self.append(data)
    }
    
    public func append(data:Data, name:String) {
        self.data.append("--\(boundary)")
        self.data.append(newLineCRLF)
        self.data.append("Content-Disposition: form-data; name=\"\(name)\"")
        
        self.append(data)
    }
    
    public func append(data:Data, name:String, fileName:String, mimeType:String) {
        
        let mime = mimeType.isEmpty ? "application/octet-stream" : mimeType
        
        self.data.append("--\(boundary)")
        self.data.append(newLineCRLF)
        self.data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"")
        self.data.append(newLineCRLF)
        self.data.append("Content-Type: \(mime)")
        
        self.append(data)
    }
    
    internal func append(_ saveData:Data) {
        data.append(newLineCRLF)
        data.append("Content-Length:\(saveData.count)")
        data.append(newLineCRLF)    //正文前另起一行
        data.append(newLineCRLF)    //正文前另起二行
        data.append(saveData)
        data.append(newLineCRLF)    //结束另起一行
    }

}

open class NetUploadRequest : NetRequest {
    
    private var _form:NetUploadForm
    public var form:NetUploadForm { return _form }
    
    public var progress:Progress

    public init(request:NetRequest, form:NetUploadForm) {
        progress = Progress(totalUnitCount: 0)
        progress.totalUnitCount = 0
        progress.completedUnitCount = 0

        _form = form
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
    }
    
    public override var urlRequest: URLRequest {
        
        let encoder = _encoder ?? Net.defaultUploadEncoder
        
        let (url, postData) = encoder.encode(request: self)
        
        var request = URLRequest(url: url, cachePolicy: policy, timeoutInterval: timeout)
        
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
        
        // 如果有自定义 头信息
        for (key, value) in _headers where !key.isEmpty {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        if let data = postData {
            request.httpMethod = "POST"
            request.httpBody = data
            request.addValue("\(data.count)", forHTTPHeaderField: "Content-Length")
            request.addValue("multipart/form-data; boundary=\(_form.boundary)", forHTTPHeaderField: "Content-Type")
        } else {
            request.httpMethod = "GET"
        }
        
        return request
    }
    
    override func resumeTask(session: URLSession, request:URLRequest, _ onComplete: @escaping (Data?, URLResponse?, Error?, Bool) -> Void) -> URLSessionTask {
        
        let data = request.httpBody!
                
        let task = session.uploadTask(with: request, from: data) {
            (data:Data?, response:URLResponse?, error:Error?) in
            onComplete(data, response, error, false)
        }
        task.netRequest = self
        task.resume()
        return task

    }
    
}

//public func unwrapOptionalToString<T>(_ v:T?) -> String {
//    var val:String!
//    guard let value = v else { return "" }
//    
//    let mirror = Mirror(reflecting: value)
//    if mirror.displayStyle == .optional {
//        let children = mirror.children
//        if children.count == 0 {
//            val = ""
//        } else {
//            val = "\(children[children.startIndex].value)"
//        }
//    } else {
//        val = "\(value)"
//    }
//    
//    return val
//}

