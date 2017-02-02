//
//  SignalingServerConnection.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/19.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import SwiftyJSON

let SignalingServer_NewPeer:Notification.Name = Notification.Name(rawValue: "signalingserver_newpeer")
let SignalingServer_ByePeer:Notification.Name = Notification.Name(rawValue: "signalingserver_byepeer")
let SignalingServer_ReceiveOffer:Notification.Name = Notification.Name(rawValue: "signalingserver_receiveoffer")

class SignalingServerConnection:BaseHTTPConnection{
    
    fileprivate var calleeId = ""
    fileprivate var receiveData:Data!
    fileprivate var sessionId:String{
        get{
            let dict = self.requestHeader() as! [String:String]
            return dict[Callee_HTTPHeader_Key.sessionId]!
        }
    }
    override func isSecureServer() -> Bool {
        #if DEBUG
            return false
        #else
            return true
        #endif
    }
    
//    override func isPasswordProtected(_ path: String!) -> Bool {
//        print(#function)
//        return true
//    }
//    
//    override func useDigestAccessAuthentication() -> Bool {
//        print(#function)
//        return false
//    }
//    
//    override func password(forUser username: String!) -> String! {
//        print(#function)
//        self.calleeId = username
//        print("calleeId:\(self.calleeId)")
//        return "1qazxsw2"
//    }
    
    override func sslIdentityAndCertificates() -> [Any]! {
        return super.sslIdentityAndCertificates()
    }
    
    override func supportsMethod(_ method: String!, atPath path: String!) -> Bool {
        if method.lowercased() == "post"{
            return SignalingServerPath.rawValues().contains(path)
        }
//        return super.supportsMethod(method, atPath: path)
        return false
    }
    
    override func expectsRequestBody(fromMethod method: String!, atPath path: String!) -> Bool {
        if method.lowercased() == "post"{
            return true
        }
        return super.expectsRequestBody(fromMethod: method, atPath: path)
    }
    
    override func httpResponse(forMethod method: String!, uri path: String!) -> (HTTPResponse & NSObjectProtocol)! {
       
        let serverPath = SignalingServerPath(rawValue: path.lowercased())
        var response:SignalingResponse!
        switch serverPath! {
        case .Hello:
            response = self.handleHello()
        case .Bye:
            response = self.handleBye()
        case .Offer, .Answer:
            response = self.handleSDP(serverPath!)
        case .Candidate:
            response = self.handleCandidate()
        case .CandidateRemoval:
            response = self.handleRemoveCandidates()
        }
        return response
//        if response != nil{
//            return response
//        }
//        
//        return nil
    }
    
    override func processBodyData(_ postDataChunk: Data!) {
        print(postDataChunk)
        self.receiveData = postDataChunk
    }
}

extension SignalingServerConnection{
    fileprivate func handleHello() -> SignalingResponse!{
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                guard var dict = JSON(data: self.receiveData).dictionaryObject else{
                    return
                }
                let sessionId = self.requestHeader()[Callee_HTTPHeader_Key.sessionId]
                dict[Callee_HTTPHeader_Key.sessionId] = sessionId
                NotificationCenter.default.post(name: SignalingServer_NewPeer, object: nil, userInfo: dict)
            }
        }
        let dict = [Callee_HTTPHeader_Key.device:UIDevice.current.name, Callee_HTTPHeader_Key.ip:SDPUtils.getWiFiAddress()!]
        let json = JSON(dict)
        do {
            let jsonData = try json.rawData()
            return SignalingResponse(data: jsonData)
        } catch {
            print(error)
        }
        
        return nil
    }
    
    fileprivate func handleBye() -> SignalingResponse!{
        var dict = [String:Any]()
        
        guard let byeDict = JSON(data: self.receiveData).dictionaryObject else{
            dict[SignalingResponse_Keys.Error] = "session description format worng"
            dict[SignalingResponse_Keys.Status] = -99
            return SignalingResponse(data:self.convertToData(dict))
        }
        
        guard let callee = CalleePool.sharedInstance().callee(fromSessoinId: self.sessionId) else {
            dict[SignalingResponse_Keys.Error] = "wrong sessionId"
            dict[SignalingResponse_Keys.Status] = -99
            return SignalingResponse(data:self.convertToData(dict))
        }
        callee.receiveByeJson(byeDict)
        dict[SignalingResponse_Keys.Status] = 200
        return SignalingResponse(data:self.convertToData(dict))
    }
    
    fileprivate func handleSDP(_ path:SignalingServerPath) -> SignalingResponse!{
        var dict = [String:Any]()
        guard let sdpDict = JSON(data: self.receiveData).dictionaryObject else{
            dict[SignalingResponse_Keys.Error] = "session description format worng"
            dict[SignalingResponse_Keys.Status] = -99
            return SignalingResponse(data:self.convertToData(dict))
        }
        
        guard let callee = CalleePool.sharedInstance().callee(fromSessoinId: self.sessionId) else {
            dict[SignalingResponse_Keys.Error] = "wrong sessionId"
            dict[SignalingResponse_Keys.Status] = -99
            return SignalingResponse(data:self.convertToData(dict))
        }
        
        switch path {
        case .Offer:
            NotificationCenter.default.post(name: SignalingServer_ReceiveOffer, object: self.sessionId)
            callee.receiveOfferJson(sdpDict)
        case .Answer:
            callee.receiveAnswerJson(sdpDict)
        default:
            break
        }
        
        
        dict[SignalingResponse_Keys.Status] = 200
        return SignalingResponse(data:self.convertToData(dict))
    }
    
    fileprivate func handleCandidate() -> SignalingResponse!{
        
        var dict = [String:Any]()
        guard let candidateDict = JSON(data: self.receiveData).dictionaryObject else{
            dict[SignalingResponse_Keys.Error] = "candidate format worng"
            dict[SignalingResponse_Keys.Status] = -99
            return SignalingResponse(data:self.convertToData(dict))
        }
        
        guard let callee = CalleePool.sharedInstance().callee(fromSessoinId: self.sessionId) else {
            dict[SignalingResponse_Keys.Error] = "wrong sessionId"
            dict[SignalingResponse_Keys.Status] = -99
            return SignalingResponse(data:self.convertToData(dict))
        }
        callee.receiveCandidate(candidateDict)
        dict[SignalingResponse_Keys.Status] = 200
        return SignalingResponse(data:self.convertToData(dict))
    }
    
    fileprivate func handleRemoveCandidates() -> SignalingResponse!{
        
        var dict = [String:Any]()
        guard let candidatesArray = JSON(data: self.receiveData).arrayObject else{
            dict[SignalingResponse_Keys.Error] = "candidates format worng"
            dict[SignalingResponse_Keys.Status] = -99
            return SignalingResponse(data:self.convertToData(dict))
        }
        
        guard let callee = CalleePool.sharedInstance().callee(fromSessoinId: self.sessionId) else {
            dict[SignalingResponse_Keys.Error] = "wrong sessionId"
            dict[SignalingResponse_Keys.Status] = -99
            return SignalingResponse(data:self.convertToData(dict))
        }
        
        callee.receiveRemoveCandidate(candidatesArray as! [[AnyHashable : Any]])
        
        dict[SignalingResponse_Keys.Status] = 200
        return SignalingResponse(data:self.convertToData(dict))
    }
    
    fileprivate func convertToData(_ jsonObject:[AnyHashable:Any]) -> Data?{
        let json = JSON(jsonObject)
        do {
            return try json.rawData()
        } catch {
            print(error)
        }
        return nil
    }
}
