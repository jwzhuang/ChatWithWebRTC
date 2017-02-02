//
//  SignalingMessage.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/10.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import WebRTC
import SwiftyJSON
import DateTools

let kDevice = "device"
let kType = "type"
let kContent = "content"

class SignalingMessage_bak:NSObject{
    
    
    fileprivate let maxSDPLength = 1000
    public var device:String = UIDevice.current.name
    public let messageType:SignalingMessageType
    public let messageContent:Any
    
    fileprivate init(_ sdp:RTCSessionDescription){
        switch sdp.type {
        case .answer:
            self.messageType = .Answer;
        case .offer:
            self.messageType = .Offer;
        case .prAnswer:
            self.messageType = .Unknow;
        }
        self.messageContent = sdp
        super.init()
    }
    
    fileprivate init(_ json:JSON){
        self.device = json[kDevice].stringValue
        self.messageType = SignalingMessageType(rawValue: json[kType].stringValue)!
        switch self.messageType {
        case .Offer, .Answer:
            let sdpString = json[kContent].stringValue
            let sdpJson = JSON(data: sdpString.data(using: .utf8)!)
            self.messageContent = RTCSessionDescription.init(fromJSONDictionary: sdpJson.dictionaryObject)
        case .Caller, .Callee:
            self.messageContent = json[kContent].stringValue
        default:
            self.messageContent = ""
            break
        }
        
        super.init()
    }
    
    fileprivate init(type:SignalingMessageType, content:String){
        self.messageType = type
        self.messageContent = content
        super.init()
    }
    
    public func data() -> Data?{
        var data:Data?
        var content:String = ""
        switch self.messageType {
        case .Answer, .Offer:
            let sdp = self.messageContent as! RTCSessionDescription
            content = String(data: sdp.jsonData(), encoding: .utf8)!
        case .Caller, .Callee:
            content = self.messageContent as! String
        default:
            break
        }
        
        let dict:[String:Any] = [kDevice:self.device, kType:self.messageType.rawValue, kContent:content]
        do{
            data = try JSON(dict).rawData()
        }catch{
            print(error)
        }
        return data
    }
    
    override var description: String{
        return "device:\n \(self.device)\n" +
            "messageType:\n \(self.messageType)\n" +
        "messageContent:\n \(self.messageContent)"
    }
    
    class func message(sdp description:RTCSessionDescription) -> SignalingMessage{
        let message = SignalingMessage(description)
        return message
    }
    
    class func message(receiveData jsonData:Data) -> SignalingMessage{
        let json = JSON(data: jsonData)
        let message = SignalingMessage(json)
        return message
    }
    
    class func message(type:SignalingMessageType, content:String) -> SignalingMessage{
        return SignalingMessage(type:type, content:content)
    }
}
