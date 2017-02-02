//
//  BonjourClient.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/19.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

let BonjourClient_NewPeer:Notification.Name = Notification.Name(rawValue: "bonjorclient_newpeer")
let BonjourClient_NewCallee = (device: "device", ip:"ip", sessionId:"sessionId")

class BonjourClient:NSObject{
    
    fileprivate var services = [NetService]()
    fileprivate var searching = false
    fileprivate lazy var bonjour:NetServiceBrowser = self.setupBonjour()
    fileprivate var resolveCount = 0
    
    fileprivate func setupBonjour() -> NetServiceBrowser{
        let bj = NetServiceBrowser()
        bj.delegate = self
        return bj
    }

    fileprivate func removeService(_ service:NetService){

        if let index = self.services.index(of: service){
            self.services.remove(at: index)
        }
        
        self.searching = (self.services.count > 0)
        if !self.searching {
            self.bonjour.stop()
        }
    }
    
    public func search(_ search:Bool = true){
        if search {
            if !self.searching{
//                self.bonjour.searchForBrowsableDomains()
                self.bonjour.searchForServices(ofType: Bonjour_SearchType, inDomain: "local.")
                //                self.bonjour.searchForServices(ofType: "_services._dns-sd._udp.", inDomain: "local.")
            }else{
                self.bonjour.stop()
            }
        }else{
            self.bonjour.stop()
        }
    }
}

extension BonjourClient:NetServiceBrowserDelegate{
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        self.searching = true
        print("Start search Bonjour service")
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        self.searching = false
        print("Stop search Bonjour service")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("\(#function) \(errorDict)")
        self.searching = false
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool){
        if service.name != UIDevice.current.name{
            service.delegate = self
            service.resolve(withTimeout: 1)
            resolveCount = resolveCount + 1
        }
    }
}

extension BonjourClient:NetServiceDelegate{
    
    func netServiceWillResolve(_ sender: NetService) {
        self.services.append(sender)
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        if let addresses = sender.addresses{
            for address in addresses where GCDAsyncSocket.isIPv4Address(address){
                if let ip = GCDAsyncSocket.host(fromAddress: address){
                    let device = sender.name
                    let dict = [BonjourClient_NewCallee.device:device, BonjourClient_NewCallee.ip:ip]
                    NotificationCenter.default.post(name: BonjourClient_NewPeer, object: nil, userInfo: dict)
                }
            }
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        self.removeService(sender)
    }
    
    func netServiceDidStop(_ sender: NetService) {
        self.removeService(sender)
//        self.netServiceBrowser(self.bonjour, didFind: sender, moreComing: false)
    }
}
