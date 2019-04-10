//
//  ToDictionary.swift
//  Tools
//
//  Created by 慧趣小歪 on 2017/8/9.
//
//

import Foundation

extension Data {
    public func string(encoding: String.Encoding = .utf8) -> String? {
        return String(data: self, encoding: encoding)
    }
}

extension Encodable {
//    var dictionary:[String:Any] {
//        guard let data = try? JSONEncoder().encode(self) else { return [:] }
//        let result = try? JSONDecoder().decode([String:Any].self, from: data)
//        return result ?? [:]
//    }
}

