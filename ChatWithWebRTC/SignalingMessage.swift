//
//  SignalingMessage.swift
//
//  Created by JingWen on 2017/1/17
//  Copyright (c) . All rights reserved.
//

import Foundation
import WebRTC


public enum SignalingMessageType:String{
    case Offer = "offer", Answer = "answer"
    case Candidate = "candidate" ,CandidateRemoval = "candidateremoval"
    case Bye = "bye"
}

public final class SignalingMessage {
    public let type:SignalingMessageType
    public var sdp:RTCSessionDescription!
    public var candidate:RTCIceCandidate!
    public var candicates:[RTCIceCandidate]!
    
    init(type:SignalingMessageType) {
        self.type = type
    }
}
