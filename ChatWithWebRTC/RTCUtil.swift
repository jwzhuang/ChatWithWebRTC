//
//  RTCUtil.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/7.
//  Copyright © 2017年 JingWen. All rights reserved.
//
import Foundation
import WebRTC

public protocol RTCUtilDelegate: class {
    func didError(_ rtcUtil:RTCUtil, error:Error)
}

let kVideoTrackKind = "video"
let kKbpsMultiplier  = 1000;
public class RTCUtil{
    fileprivate static var instance:RTCUtil?
    public static func sharedInstance() -> RTCUtil {
        if instance == nil {
            instance = RTCUtil()
        }
        return instance!
    }
    
    fileprivate init(){
        
    }
    
    fileprivate let kMediaStreamId = "ARDAMS"
    fileprivate let kAudioTrackId = "ARDAMSa0"
    fileprivate let kVideoTrackId = "ARDAMSv0"
    fileprivate let constraintsFactory = ConstraintsFactory()
    
    public weak var delegate:RTCUtilDelegate?
    //MARK: - Private Method - PeerConnect
    fileprivate let factory = RTCPeerConnectionFactory()

    //MARK: - Private Method - LocalView
//    public weak var localView: RTCCameraPreviewView!
//    fileprivate lazy var localVideoTrack:RTCVideoTrack = self.setupLocalVideoTrack()
//    fileprivate lazy var localAudioTrack:RTCAudioTrack = self.setupLocalAudioTrack()
    fileprivate func setupLocalVideoTrack() -> RTCVideoTrack{
        
        let source = self.factory.avFoundationVideoSource(with: self.constraintsFactory.cameraConstraints)
        let track = self.factory.videoTrack(with: source, trackId: kVideoTrackId)
        return track
    }
    
    fileprivate func setupLocalAudioTrack() -> RTCAudioTrack{
        let constraints = self.constraintsFactory.audioConstraints
        let source = self.factory.audioSource(with: constraints)
        let track = self.factory.audioTrack(with: source, trackId: kAudioTrackId)
        return track
    }
    
    //MARK: - Public Method Get User Media
    public func previewLocalCamera(_ peerConnection:RTCPeerConnection, localView: RTCCameraPreviewView!, complete:(_ videoTrack:RTCVideoTrack, _ audioTrack:RTCAudioTrack)->()){
        guard localView != nil else {
            print("Need localView")
            return
        }
        let localVideoTrack = self.setupLocalVideoTrack()
        let localAudioTrack = self.setupLocalAudioTrack()
        localView.captureSession = (localVideoTrack.source as! RTCAVFoundationVideoSource).captureSession
        localView.captureSession.sessionPreset = AVCaptureSessionPresetMedium
        //        source.useBackCamera = true
        
        let stream = self.factory.mediaStream(withStreamId: kMediaStreamId)
        stream.addVideoTrack(localVideoTrack)
        stream.addAudioTrack(localAudioTrack)
        peerConnection.add(stream)
        complete(localVideoTrack, localAudioTrack)
//        let videoSender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindVideo, streamId: kMediaStreamId)
//        videoSender.track = self.localVideoTrack
//        let audioSender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindAudio, streamId: kMediaStreamId)
//        audioSender.track = self.localAudioTrack
    }
    
    //MARK: - Public Method Chat
    public func createOffer(_ peerConnection:RTCPeerConnection, complete:@escaping (_ sdp:RTCSessionDescription?, _ error:Error?)->Void){
        peerConnection.offer(for: self.constraintsFactory.offerConstraints) {(offer, error) in
            self.didCreateSessionDescription(peerConnection, sessionDescription: offer, error: error, complete: { (offer, error) in
                complete(offer, error)
            })
        }
    }
    
    public func createAnswer(_ peerConnection:RTCPeerConnection, complete:@escaping (_ sdp:RTCSessionDescription?, _ error:Error?)->Void){
        peerConnection.answer(for: self.constraintsFactory.answerConstraints) { (answer, error) in
            self.didCreateSessionDescription(peerConnection, sessionDescription: answer, error: error, complete: { (answer, error) in
                complete(answer, error)
            })
        }
    }
    
    public func setRemoteDescription(_ peerConnection:RTCPeerConnection,description:RTCSessionDescription? , complete:@escaping (_ error:Error?)->()){
        peerConnection.setRemoteDescription(description!) { (error) in
            self.didSetSessionDescription(peerConnection, error: error, complete: { (error) in
                complete(error)
            })
        }
    }
}

extension RTCUtil{
//     Callbacks for this delegate occur on non-main thread and need to be
//     dispatched back to main queue as needed.
    fileprivate func didCreateSessionDescription(_ peerConnection:RTCPeerConnection, sessionDescription sdp:RTCSessionDescription?, error:Error?, complete:((_ sdpData:RTCSessionDescription?, _ error:Error?)->Void)?){
        guard error == nil else {
            let error = SDPUtils.error(reflecting: RTCUtil.self, info: "Failed to create session description.", errorCode: .ErrorCreateSDP)
            complete?(nil, error)
            return
        }
        
        if let sdp = sdp{
            // Prefer H264 if available.
            let sdpPreferringH264 = SDPUtils.sessionDescription(sdp: sdp, codec: .H264)
            peerConnection.setLocalDescription(sdpPreferringH264, completionHandler: {(error) in
                self.didSetSessionDescription(peerConnection, error: error, complete: { (error:Error?) in
                    complete?(sdpPreferringH264, error)
                })
            })
        }
    }
    
    fileprivate func didSetSessionDescription(_ peerConnection:RTCPeerConnection,error:Error?, complete:((_ error:Error?)->Void)?) {
        if error != nil{
            let error = SDPUtils.error(reflecting: RTCUtil.self, info: "Failed to set session description.", errorCode: .ErrorSetSDP)
            self.delegate?.didError(self, error: error)
            complete?(error)
            return
        }
        complete?(nil)
    }
}
