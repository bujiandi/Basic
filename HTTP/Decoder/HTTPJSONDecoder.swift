//
//  HTTPJSONDecoder.swift
//  Basic
//
//  Created by 李招利 on 2018/9/30.
//

extension HTTP {
    
    open class JSONDecoder : HTTPResponeDecoder {
        
        public typealias Result = JSON
        
        public init() {}
        
        open func decode(request:URLRequest, response:HTTPURLResponse, data:Data) throws -> Result {
            
            var result:JSON = .null
            do {
                result = try Basic.JSONDecoder().decode(JSON.self, from: data)
            } catch (let error as DecodingError) {
                throw HTTP.ResponseError.unknowJSONData(data, error)
            } catch (let error) {
                throw error
            }
            return result
        }
    }

    public static var jsonDecoder = JSONDecoder()
}


extension HTTP.Request {
    
    public mutating func responseJSON(_ onSuccess: @escaping (JSON) throws -> Void) {
        response(decoder: HTTP.Decoder.json, onSuccess: onSuccess)
    }
    
}
