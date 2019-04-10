//
//  NetOverlay.swift
//  Basic
//
//  Created by 慧趣小歪 on 2018/5/16.
//

import Foundation


public protocol NetOverlay : class {
    
    func startNetOverlay()
    func stopNetOverlay()
    func progressPercentChanged(_ percent:Double)
    
}

public protocol NetFailureRetryOverlay : class {
    
    func showRetryOverlay(_ resumeWork:Resumable, _ message:String)
    
}
