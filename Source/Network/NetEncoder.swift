//
//  NetEncoder.swift
//  NetworkTest
//
//  Created by 慧趣小歪 on 2018/4/25.
//  Copyright © 2018年 慧趣小歪. All rights reserved.
//


#if canImport(Basic)
import Basic
#endif
import Foundation


public protocol NetEncoder {
    
    func sign(request:NetRequest, params: inout [(String, Any)])
    
    func encode(request:NetRequest) -> (URL, Data?)
}

open class NetParamsEncoder : NetEncoder {
    
    public init() {}

    open func sign(request: NetRequest, params: inout [(String, Any)]) {
        
    }
    
    open func encode(request: NetRequest) -> (URL, Data?) {
        let url = self.url(forRequest: request, withGetParams: request._getParams)
        
        if  request._postParams.isEmpty {
            return (url, nil)
        }
        var postParams = request._postParams.map { ($0.0, $0.1() ) }
        sign(request: request, params: &postParams)
        let value:String = self.value(postParams).joined(separator: "&")
        
        return (url, value.data(using: .utf8))
    }
    
}

open class NetJSONArrayEncoder: NetEncoder {
    
    public init() {}
    
    open func sign(request: NetRequest, params: inout [(String, Any)]) {
        
    }
    
    open func encode(request: NetRequest) -> (URL, Data?) {
        let url = self.url(forRequest: request, withGetParams: request._getParams)
        
        var postParams = request._postParams.map { ($0.0, $0.1() ) }
        sign(request: request, params: &postParams)
        let array = NSMutableArray()
        for (_, value) in postParams {
            array.add(value)
        }
        request._headers["Content-Type"] = "application/json;charset=UTF-8"
        let data = try? JSONSerialization.data(withJSONObject: array, options: [])
        return (url, data)
    }

}

open class NetJSONObjectEncoder : NetEncoder {
    
    public init() {}
    
    open func sign(request: NetRequest, params: inout [(String, Any)]) {
        
    }
    
    open func encode(request: NetRequest) -> (URL, Data?) {
        let url = self.url(forRequest: request, withGetParams: request._getParams)
        
        var postParams = request._postParams.map { ($0.0, $0.1() ) }
        sign(request: request, params: &postParams)
        var obj:[String:AnyHashable] = [:]
        for (key, value) in postParams {
            // 如果有重复的key加入数组
            if let repeatedValue = obj[key] {
                switch repeatedValue {
                case let array as NSMutableArray:
                    array.add(value)
                    obj[key] = array
                case let object as NSDictionary:
                    obj[key] = NSMutableArray(array: [object, value])
                case let number as NSNumber:
                    obj[key] = NSMutableArray(array: [number, value])
                case let string as NSString:
                    obj[key] = NSMutableArray(array: [string, value])
                case let null as NSNull:
                    obj[key] = NSMutableArray(array: [null, value])
                default:
                    obj[key] = NSMutableArray(array: [repeatedValue, unwrapOptionalToString(value)])
                }
            } else {
                switch value {
                case let array as NSArray:
                    obj[key] = array
                case let object as NSDictionary:
                    obj[key] = object
                case let number as NSNumber:
                    obj[key] = number
                case let null as NSNull:
                    obj[key] = null
                default:
                    obj[key] = unwrapOptionalToString(value)
                }
            }
            
        }
        request._headers["Content-Type"] = "application/json;charset=UTF-8"

//        let json:String? = obj.isEmpty ? nil : JSON(obj).description
//        return (url, json?.data(using: .utf8))
        
        let data = try? JSONSerialization.data(withJSONObject: obj, options: [])
        return (url, data)
    }
    
}

extension NetEncoder {
    
    func value(_ params:[(String,Any)]) -> [String] {
        return params.compactMap {
            
            let key = $0.0
            
            if key.isEmpty { return nil }
            
            let val = unwrapOptionalToString($0.1)
            let k = key.encodeURL()
            let v = val.encodeURL()
            return "\(k)=\(v)"
        }
    }
    
    func url(forRequest request: NetRequest,
             withGetParams gets: [(String, () -> Any)]) -> URL {
        
        var params = gets.map { ($0.0, $0.1() ) }
        sign(request: request, params: &params)
        let text:String = value(params).joined(separator: "&")
        return text.isEmpty ? request.url : URL(string: "\(request.url)?\(text)")!
    }
    
}


//open class NetParamsEncoder {
//
//    func
//
//}
