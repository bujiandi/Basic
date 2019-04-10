//
//  NetSessionDelegate.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/24.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//

import Foundation


// MARK: - 私有
class NetSessionDelegate: NSObject, URLSessionDownloadDelegate, URLSessionDataDelegate {
    

    
    // 无论成功失败都会走这里, 用来做完成回调
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // 只处理下载
        guard let request = task.netRequest as? NetDownloadRequest else { return }
        
        // 构造响应数据
        var error:Error? = error
        var data:Data? = nil
        if error == nil {
            do {
                let downloadURL = request.localURL
                data = try downloadURL.bookmarkData() //try Data(contentsOf: downloadURL)
            } catch let err {
                error = err
            }
        }
        request.onComplete(data, task.response, error)
    }
    
    // 下载完成
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        guard let url = downloadTask.response?.url else { return }
        
        let bookmarkPath = Net.bookmarkPathFor(key: url.absoluteString)
        let bookmarkFile = bookmarkPath.stringByAppending(pathComponent: "download.mark")
        
        let fileManager = FileManager.default
        
        var isDir:ObjCBool = false
        
        // 获得下载请求
        guard let request = downloadTask.netRequest as? NetDownloadRequest else { return }
        
        let downloadURL:URL = request.localURL
        
        // 如果下载路径不存在则创建
        let parentPath = downloadURL.deletingLastPathComponent().relativePath
        if !fileManager.fileExists(atPath: parentPath, isDirectory: &isDir) || !isDir.boolValue {
            try? fileManager.createDirectory(atPath: parentPath, withIntermediateDirectories: true, attributes: nil)
        }
        
        // 删除旧的 已下载文件或书签 如果有的话.
        try? fileManager.removeItem(atPath: bookmarkFile)
        try? fileManager.removeItem(at: downloadURL)
        
        // 将新下载完成的文件移动到 文件路径
        try? fileManager.moveItem(at: location, to: downloadURL)
        
        // 保存书签数据
        if let data = try? downloadURL.bookmarkData() {
            try? data.write(to: URL(fileURLWithPath: bookmarkFile, isDirectory: false))
        }
        request._localURL = downloadURL
    }
    
    // 下载进度变化
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // 获得下载请求
        if let request = downloadTask.netRequest as? NetDownloadRequest {
            request.onProgress(totalSize: totalBytesExpectedToWrite, localSize: totalBytesWritten)
//            request.callProgress(totalSize: totalBytesExpectedToWrite, localSize: totalBytesWritten)
        }
    }
    
    // 上传进度变化
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let request = task.netRequest as? NetUploadRequest {
            request.onProgress(totalSize: totalBytesSent, localSize: bytesSent)
        }
    }
    
    // 断点续传开始
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        // 获得下载请求
        if let request = downloadTask.netRequest as? NetDownloadRequest {
            request.onProgress(totalSize: expectedTotalBytes, localSize: fileOffset)
//            request.callProgress(totalSize: expectedTotalBytes, localSize: fileOffset)
        }
    }
    
    // 下载请求转下载
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        guard let request = dataTask.netRequest else { return }
        
        downloadTask.netRequest = request
        request.group?.ongoingRequest = (downloadTask, request)
    }
    
    // 下载收到服务端响应
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // 获得下载请求
        guard let request = dataTask.netRequest as? NetDownloadRequest else {
            return completionHandler(.cancel)
        }
        
        // 如果不是HTTP请求则取消
        guard let response = dataTask.response as? HTTPURLResponse else {
            let info = ["message":"未知的下载请求响应:\(dataTask.response?.classNameForCoder ?? String.Empty)"]
            let error = NSError(domain: NSURLErrorDomain, code: -3001, userInfo: info)
            request.cancelContinue = false
            request.onComplete(nil, dataTask.response, error)
            return completionHandler(.cancel)
        }
        
        let dateText = response.allHeaderFields["Date"] as? String ?? "Thu, 01 Jan 1970 00:00:00 GMT"
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US")
        format.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        
        let date = format.date(from: dateText) ?? Date(timeIntervalSince1970: 0)
        Net.timeOffset = date.timeIntervalSince1970 - Date().timeIntervalSince1970
        
        // 如果不是下载的响应状态
        if response.statusCode != 200 && response.statusCode != 206 {
            let info = ["message":"非下载网络状态:\(response.statusCode)"]
            let error = NSError(domain: NSURLErrorDomain, code: response.statusCode, userInfo: info)
            request.cancelContinue = false
            request.onComplete(nil, dataTask.response, error)
            return completionHandler(.cancel)
        }
        
        
        // 如果未强制下载路径， 则优先使用 服务器返回的文件名
//            let downloadURL = request.localURLWith(fileName: response.suggestedFilename)
        
        // 输出下载路径
//            print("Content-Disposition:",downloadURL);
        
        let totalSize = Int64(response.allHeaderFields["Content-Length"] as? String ?? "0") ?? 0
        
        // 如果是断点续传则直接开始下载
        if response.statusCode != 200 {
            // TODO : 检测网络状态, 成功直接开始下载
            return willBegin(downloadRequest: request, totalSize: totalSize, localSize: 0, completionHandler: completionHandler)
        }
        
        let bookmarkFile = Net.bookmarkFileFor(key: request.url.absoluteString)
        
        let fileManager = FileManager.default
        var isDir:ObjCBool = false
        
        // 如果从未下载过则直接开始
        if !fileManager.fileExists(atPath: bookmarkFile, isDirectory: &isDir) || isDir.boolValue {
            // TODO : 检测网络状态, 成功直接开始下载
            return willBegin(downloadRequest: request, totalSize: totalSize, localSize: 0, completionHandler: completionHandler)
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: bookmarkFile)), data.count > 0 else {
            // TODO : 书签数据无效, 直接开始下载
            return willBegin(downloadRequest: request, totalSize: totalSize, localSize: 0, completionHandler: completionHandler)
        }
        
        var isStale:Bool = false
        guard let fileURL = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else {
            // TODO : 书签无效, 直接开始下载
            return willBegin(downloadRequest: request, totalSize: totalSize, localSize: 0, completionHandler: completionHandler)
        }
        
        
        let filePath = fileURL.relativePath
        if !fileManager.fileExists(atPath: filePath, isDirectory: &isDir) || isDir.boolValue {
            // TODO : 书签指向真实文件不存在, 删除书签, 直接开始下载
            try? fileManager.removeItem(atPath: bookmarkFile)
            return willBegin(downloadRequest: request, totalSize: totalSize, localSize: 0, completionHandler: completionHandler)
        }
        
        guard let fileAttr = try? fileManager.attributesOfItem(atPath: filePath) else {
            // TODO : 无法确定书签指向文件的大小, 直接开始下载
            return willBegin(downloadRequest: request, totalSize: totalSize, localSize: 0, completionHandler: completionHandler)
        }
        let localSize = fileAttr[.size] as? Int64 ?? 0
        
        if localSize != totalSize {
            // TODO : 已下载的文件大小和服务器端文件大小不一致 则重新下载
            return willBegin(downloadRequest: request, totalSize: totalSize, localSize: 0, completionHandler: completionHandler)
        }
        request.onProgress(totalSize: totalSize, localSize: localSize)
//        request.callProgress(totalSize: totalSize, localSize: localSize)
        // 如果大小一致则取消下载 返回成功
        // 调用成功回调
        request._localURL = fileURL //downloadURL
        request.cancelContinue = true
        urlSession(session, task: dataTask, didCompleteWithError: nil)
        dataTask.netRequest = nil
        completionHandler(.cancel)
    }
    
    
    func willBegin(downloadRequest:NetDownloadRequest, totalSize:Int64, localSize:Int64, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        guard let delegate = Net.delegate else {
            return completionHandler(.becomeDownload)
        }
        
        delegate.onWillBegin(downloadRequest: downloadRequest,
                             totalSize: totalSize,
                             localSize: localSize,
                             completionHandler: completionHandler)
    }
}
