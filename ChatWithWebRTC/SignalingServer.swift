//
//  SignalingServer.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/10.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation

#if DEBUG
    let ServerProtocol = "http://"
#else
    let ServerProtocol = "https://"
#endif
let ServerPoft = 3579
let SignalingChannel_Notify_UDP_Bind = NSNotification.Name(rawValue: "signalingChannel_udp_bind")



public enum SignalingServerPath:String{
    case Offer = "/offer", Answer = "/answer", Candidate = "/candidate", CandidateRemoval = "/candidateremoval"
    case Hello = "/hello", Bye = "/bye"
    
    static func rawValues() -> [String] {
        return[Offer.rawValue, Answer.rawValue, Candidate.rawValue, CandidateRemoval.rawValue, Hello.rawValue, Bye.rawValue]
    }
}

class SignalingServer:NSObject{
    fileprivate lazy var httpServer:HTTPServer = self.setupHttpServer()
    
    fileprivate func setupHttpServer() -> HTTPServer{
        let httpServer = HTTPServer()
        httpServer.setType("_http._tcp.")
        httpServer.setPort(UInt16(ServerPoft))
        httpServer.setConnectionClass(SignalingServerConnection.self)
        return httpServer
    }
}


extension SignalingServer{
    public func start(_ enable:Bool = true){
        
        if enable{
            do{
                try self.httpServer.start()
                print("SignalingServer start")
            }catch{
                print("SignalingServer start failed/n\(error)")
            }
            return
        }
        
        if self.httpServer.isRunning(){
            self.httpServer.stop()
        }
    }
}
