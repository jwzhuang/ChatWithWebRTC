//
//  BonjourService.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/19.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import UIKit

let Bonjour_SearchType = "_chat._tcp"

class BonjourService:NSObject{
    
    fileprivate var isRunning = false
    fileprivate lazy var bonjour:NetService = self.setupBonjour()
    
    fileprivate func setupBonjour() -> NetService{
        let bj = NetService(domain: "local.", type: Bonjour_SearchType, name: UIDevice.current.name)
        bj.delegate = self
        return bj
    }
    
    public func enable(_ enable:Bool = true){
        if enable{
            if !isRunning {
                self.bonjour.publish(options: .listenForConnections)
//                self.bonjour.publish()
            }
        }else{
            self.bonjour.stop()
        }
    }
}

extension BonjourService:NetServiceDelegate{
    func netServiceWillPublish(_ sender: NetService){
        isRunning = true;
    }
    
    func netServiceDidPublish(_ sender: NetService){
        print("Started Bonjour Service")
        isRunning = true;
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]){
        print(errorDict)
        isRunning = false;
        assert(sender == self.bonjour)
        assert(false)
    }
    
    func netServiceDidStop(_ sender: NetService){
        isRunning = false;
        print("Stoped Bonjour Service")
    }
}
