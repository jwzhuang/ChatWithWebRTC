//
//  ConstraintsFactory.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/9.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import WebRTC

class ConstraintsFactory{
    
    public lazy var peerConnectionConstraints:RTCMediaConstraints = self.setupPeerConnectionConstraints()
    public lazy var cameraConstraints:RTCMediaConstraints = self.setupCameraConstraints()
    public lazy var audioConstraints:RTCMediaConstraints = self.setupAudioConstraints()
    public lazy var offerConstraints:RTCMediaConstraints = self.setupOfferConstraints()
    public lazy var answerConstraints:RTCMediaConstraints = self.setupAnswerConstraints()
    
    fileprivate func setupPeerConnectionConstraints(isLoopback loopback:Bool = false) -> RTCMediaConstraints{
        let value = loopback ? "true" : "false"
        let optionalConstraints = ["DtlsSrtpKeyAgreement":value]
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: optionalConstraints)
        return constraints
    }
    
    fileprivate func setupCameraConstraints() -> RTCMediaConstraints{
        let optionalConstraints = SettingsModel().currentMediaConstraintFromStoreAsRTCDictionary()
        let constraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: optionalConstraints)
        return constraints
    }
    
    fileprivate func setupAudioConstraints() -> RTCMediaConstraints{
        let shouldUseLevelControl = true;
        let valueLevelControl = shouldUseLevelControl ? kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse
        let mandatoryConstraints = [kRTCMediaConstraintsLevelControl : valueLevelControl]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: [:])
        return constraints
    }
    
    fileprivate func setupOfferConstraints() -> RTCMediaConstraints{
        let mandatoryConstraints = ["OfferToReceiveAudio" : kRTCMediaConstraintsValueTrue, "OfferToReceiveVideo" : kRTCMediaConstraintsValueTrue]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: [:])
        return constraints
    }
    
    fileprivate func setupAnswerConstraints() -> RTCMediaConstraints{
        return self.setupOfferConstraints()
    }
}
