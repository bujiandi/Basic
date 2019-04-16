//
//  NetDecoder.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/20.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//


#if canImport(JSON)
import JSON
#endif

import Foundation

public enum NetResponseError : Error {
    
    case unknowCharSet(Data)
    case unknowJSONData(Data, DecodingError)
    case unknowBookmark(Data, isStale:Bool)
    case unknowImageURL(URL?, URL)
    case unknowJSONForm(JSON)
    case unknowfailJSON(JSON, String)
    
    public var localizedDescription: String {
        switch self {
        case .unknowCharSet:    return "未知的字符编码"
        case .unknowJSONData:   return "数据不是标准JSON格式"
        case .unknowBookmark:   return "无法从Bookmark恢复已下载数据"
        case .unknowImageURL:   return "无效的图片数据格式"
        case .unknowJSONForm:   return "缺少标准参数，数据未知来源"
        case .unknowfailJSON(_, let text): return text
        }
    }
}


public enum NetRequestError : Error {
    
    case failStatusCode(Int, String)
    case failureRequest(Error)
    case canceled
    
    public var localizedDescription: String {
        switch self {
        case .failureRequest(let error):    return error.localizedDescription
        case .failStatusCode(_, let text):  return text
        case .canceled:                     return "请求被取消"
        }
    }

}

public protocol NetDecoder {
    
    associatedtype Result
    
    func decode(request:URLRequest, response:HTTPURLResponse, data:Data) throws -> Result
    
}


open class NetHTMLDecoder : NetDecoder {
   
    public typealias Result = String
    
    public init() {}
    
    open func decode(request:URLRequest, response:HTTPURLResponse, data:Data) throws -> Result {
        guard let result = String(data: data, encoding: .utf8) else {
            throw NetResponseError.unknowCharSet(data)
        }
        return result
    }
}

open class NetJSONDecoder : NetDecoder {
    
    public typealias Result = JSON

    public init() {}
    
    open func decode(request:URLRequest, response:HTTPURLResponse, data:Data) throws -> Result {
        
        var result:JSON = .null
        do {
            result = try JSONDecoder().decode(JSON.self, from: data)
        } catch (let error as DecodingError) {
            throw NetResponseError.unknowJSONData(data, error)
        } catch (let error) {
            throw error
        }
        return result
    }
}

open class NetDownDecoder : NetDecoder {
    
    public typealias Result = URL
    
    public init() {}

    open func decode(request:URLRequest, response:HTTPURLResponse, data:Data) throws -> Result {
        var isStale:Bool = false
        guard let localURL = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else {
            throw NetResponseError.unknowBookmark(data, isStale: isStale)
        }
        return localURL
    }

}
