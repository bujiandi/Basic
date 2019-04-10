//
//  Network.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/19.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//

import Foundation

// MARK: - Http Basic
public struct Net {
    
    public static var delegate:NetDelegate? = nil
    public static var defaultEncoder:NetEncoder = NetParamsEncoder()
    public static var defaultUploadEncoder:NetEncoder = NetUploadEncoder()

    public static var defaultQueue = NetQueue()
    
    public static var timeout:TimeInterval = 15
    
    public static func http(_ createGroup: @escaping (NetGroup) -> Void) -> NetGroup {
        return defaultQueue.http(createGroup)
    }
    
    /// 服务器时间 至少有一次网络请求成功才正确
    public static var serverDate:Date {
        return Date(timeIntervalSince1970: Date().timeIntervalSince1970 + timeOffset)
    }
    
    internal static var timeOffset:TimeInterval = 0

}

public protocol NetDelegate:class {
    
    /// 已收到服务器响应 即将开始一次下载
    func onWillBegin(downloadRequest:NetDownloadRequest, totalSize:Int64, localSize:Int64, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    
}


// MARK: - Http Headers
extension Net {
    
    public static var acceptLanguage = Locale
        .preferredLanguages
        .prefix(6)
        .enumerated()
        .map { "\($1);q=\(1.0 - (Double($0) * 0.1))" } // $1 = languageCode, $0 = index
        .joined(separator: ", ")
    
    
    public static var userAgent: String = {
        
        let netFrameworkVersion: String = {
            guard
                let afInfo = Bundle(for: NetQueue.self).infoDictionary,
                let build = afInfo["CFBundleShortVersionString"]
                else { return "Unknown" }
            
            return "fenfen/\(build)"
        }()
        
        if let info = Bundle.main.infoDictionary {
            let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
            let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
            let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
            let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"
            
            let osNameVersion: String = {
                let version = ProcessInfo.processInfo.operatingSystemVersion
                let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
                
                let osName: String = {
                    #if os(iOS)
                    return "iOS"
                    #elseif os(watchOS)
                    return "watchOS"
                    #elseif os(tvOS)
                    return "tvOS"
                    #elseif os(macOS)
                    return "OS X"
                    #elseif os(Linux)
                    return "Linux"
                    #else
                    return "Unknown"
                    #endif
                }()
                
                return "\(osName) \(versionString)"
            }()
            
            return "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) \(netFrameworkVersion)"
        }
        return netFrameworkVersion
    }()
}


// MARK: - Http download bookmark

extension Net {
    
    /// 下载文件路径 从文件标签获得
    public static func filePathBy(bookmark:String) -> String {
        let fileManager = FileManager.default
        
        // 文件不存在或不是目录 则创建
        var isDir:ObjCBool = false
        if !fileManager.fileExists(atPath: bookmark, isDirectory: &isDir) || isDir.boolValue {
            return String.Empty
        }
        
        // 如果 下载文件标签0字节 则直接开始下载
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: bookmark)), data.count > 0 else {
            return String.Empty
        }
        // 如果 下载文件标签无效 则直接开始下载
        var isStale = false
        guard let fileURL = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else {
            return String.Empty
        }
        
        // 如果书签数据不存在或者已删除 则 删除书签 并 重新下载
        let filePath = fileURL.relativePath
        if !fileManager.fileExists(atPath: filePath, isDirectory: &isDir) || isDir.boolValue {
            return String.Empty
        }
        
        return filePath
    }
    
    /// 文件标签对应下载文件的尺寸
    public static func fileSizeBy(bookmark:String) -> Int {
        let filePath = filePathBy(bookmark: bookmark)
        
        if filePath.length == 0 { return 0 }
        
        guard let fileAttr = try? FileManager.default.attributesOfItem(atPath: filePath) else {
            return 0
        }
        
        let size = "\(String(describing: fileAttr[FileAttributeKey.size]))" as NSString
        return size.integerValue
    }
    
    /// url对应已下载的尺寸
    public static func fileSizeBy(url:URL) -> Int {
        return fileSizeBy(bookmark: bookmarkFileFor(key: url.absoluteString))
    }
    
    /// 文件标签二进制路径
    public static func bookmarkFileFor(key:String) -> String {
        return bookmarkPathFor(key: key).stringByAppending(pathComponent: "download.mark")
        
    }
    
    /// 文件标签目录
    public static func bookmarkPathFor(key:String) -> String {
        let fileName = createFileNameFor(key: key)
        
        let identifier = Bundle.main.bundleIdentifier ?? "com.appfenfen.downloads"
        
        let downRoot = getDiskCachePathFor(nameSpace: identifier)
        let bookmark = downRoot.stringByAppending(pathComponent: "bookmarks")
        
        return bookmark.stringByAppending(pathComponent: fileName)
    }
    
    /// 用key的哈希值来生成文件名
    public static func createFileNameFor(key:String) -> String {
        return key.md5
    }
    
    /// 获取磁盘缓存路径 根据命名空间
    public static func getDiskCachePathFor(nameSpace:String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return paths[0].stringByAppending(pathComponent: nameSpace)
    }
}
