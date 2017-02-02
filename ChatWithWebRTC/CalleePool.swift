//
//  CalleePool.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/21.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation

class CalleePool {
    public var callees = [Callee]()
    
    fileprivate static var instance:CalleePool?
    public static func sharedInstance() -> CalleePool {
        if instance == nil {
            instance = CalleePool()
        }
        return instance!
    }
    
    fileprivate init(){
        
    }
    
    public func index(_ sessionId:String) -> Int?{
        return self.callees.index() {$0.uid == sessionId}
    }
    
    public func index(_ callee:Callee) -> Int?{
        return callees.index(of: callee)
    }
    
    public func updateCalles(_ byCallee:Callee, complete:()->()){
        let storeds = self.callees.filter(){$0.ip == byCallee.ip}
        
        for stored in storeds{
            if let index = self.callees.index(of: stored){
                self.callees.remove(at: index)
            }
        }
        self.callees.append(byCallee)
        complete()
    }
    
    public func callee(fromIndex:Int) -> Callee{
        return self.callees[fromIndex]
    }
    
    public func callee(fromSessoinId:String) -> Callee?{
    
        let targets = self.callees.filter(){$0.uid == fromSessoinId}
        if targets.count == 0{
            return nil
        }
        return targets.first
    }
    
    public func totalCallees() -> Int{
        return self.callees.count
    }
}
