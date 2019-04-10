//
//  NetGroupState.swift
//  Basic
//
//  Created by 小歪 on 2018/7/16.
//

import Foundation

extension NetGroup {
    
    public enum State : Int {
        case waiting
        case loading
        case success
        case failure
    }
}
