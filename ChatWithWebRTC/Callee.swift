//
//  Callee.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/14.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import WebRTC
import Alamofire
import SwiftyJSON

let Callee_HTTPHeader_Key = (device:"Device-Name", ip:"Device-IP", sessionId:"Session-Id", message:"message")

fileprivate struct RTCTracks{
    var localVideoTrack:RTCVideoTrack!
    var localAudioTrack:RTCAudioTrack!
    var remoteViewTrack:RTCVideoTrack!
    
    func haveRemoteTrack() -> Bool {
        
        guard self.remoteViewTrack == nil else {
            return true
        }
        return false
    }
}

public protocol CalleeDelegate:class{
    func didReceive(remoteVideoTrack: RTCVideoTrack)
    func didReset(remoteVideoTrack: RTCVideoTrack)
    func didLeave(callee:Callee)
    func didPeerDisconnected()
}

public class Callee:NSObject{
    
    public var device:String
    public var ip:String
    public var uid = ""
    public weak var delegate:CalleeDelegate?
    fileprivate let factory = RTCPeerConnectionFactory()
    fileprivate let constraintsFactory = ConstraintsFactory()
    fileprivate lazy var peerConnection:RTCPeerConnection! = self.setupPeerConnection()
    fileprivate var messages = [SignalingMessage]()
    fileprivate var isPreviewing = false
    fileprivate var receivedSDP = false
    fileprivate var tracks:RTCTracks! = RTCTracks()
    
    init(_ device:String, address ip:String, sendHello:Bool = false) {
        self.device = device
        self.ip = ip
        super.init()
        if sendHello{
            self.sendHello()
        }
    }
    
    override public var description: String{
        return "Device: \(self.device)" +
        "\nIP: \(self.ip)" +
        "\nUID: \(self.uid)"
    }
    
    fileprivate func setupPeerConnection() -> RTCPeerConnection{
        
        let config = RTCConfiguration()
        //        config.iceServers
        let peerConnection = self.factory.peerConnection(with: config, constraints: constraintsFactory.peerConnectionConstraints, delegate: self)
        return peerConnection
    }
}

//MARK: - public method
extension Callee{
    public override func isEqual(_ object: Any?) -> Bool {
        if let rhs = object as? Callee{
            return (self.device == rhs.device) && (self.ip == rhs.ip)
        }
        return false
    }
    
    public func prepare(_ isCaller:Bool = false, localView:RTCCameraPreviewView!){
        RTCUtil.sharedInstance().previewLocalCamera(self.peerConnection, localView: localView) {[unowned self] (videoTrack, audiorack) in
            self.isPreviewing = true
            self.tracks.localVideoTrack = videoTrack
            self.tracks.localAudioTrack = audiorack
            if isCaller{
                self.createOffer()
            }else{
                self.drainMessageQueueIfReady()
            }
        }
    }
    
    public func disconnect(complete:(()->Void)?){
        self.sendBye { [unowned self] in
            self.reset()
            complete?()
        }
    }
    
    public func switchCamera(){
        let source = self.tracks.localVideoTrack.source as! RTCAVFoundationVideoSource
        source.useBackCamera = !source.useBackCamera
    }
    
    public func isVideoEnable() -> Bool{
        return self.tracks.localVideoTrack.isEnabled
    }
    
    public func enableVideo(){
        self.tracks.localVideoTrack.isEnabled = !self.tracks.localVideoTrack.isEnabled
    }
    
    public func enableAudio(){
        self.tracks.localAudioTrack.isEnabled = !self.tracks.localAudioTrack.isEnabled
    }
    
    public func isAudioEnable() -> Bool{
        return self.tracks.localAudioTrack.isEnabled
    }
}

//MARK: - Private Method for RTC
extension Callee{
    
    fileprivate func synchronized(_ lock: Any, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    fileprivate func reset(){
        
        guard let _ = self.tracks else {
            print("\(UIDevice.current.name) reseted")
            return
        }
        
        if !self.tracks.haveRemoteTrack(){
            print("\(UIDevice.current.name) have no remote track")
            return
        }
        
        self.delegate?.didReset(remoteVideoTrack: self.tracks.remoteViewTrack)
        self.tracks = RTCTracks()
        self.peerConnection.close()
        for stream in self.peerConnection.localStreams{
            
            for videoTrack in stream.videoTracks{
                videoTrack.isEnabled = false
                stream.removeVideoTrack(videoTrack)
            }
            
            for audioTrack in stream.audioTracks{
                audioTrack.isEnabled = false
                stream.removeAudioTrack(audioTrack)
            }
            self.peerConnection.remove(stream)
        }
        
        self.peerConnection = self.setupPeerConnection()
        self.messages.removeAll()
        
        self.isPreviewing = false
        self.receivedSDP = false
    }
    
    fileprivate func setMaxBitrate(){
        for sender in self.peerConnection.senders {
            if let track = sender.track, track.kind == kVideoTrackKind{
                if let max = SettingsModel().currentMaxBitrateSettingFromStore(), max.intValue > 0{
                    let parametersToModify = sender.parameters
                    for encoding in parametersToModify.encodings {
                        encoding.maxBitrateBps = (max.intValue * kKbpsMultiplier) as NSNumber
                    }
                    sender.parameters = parametersToModify
                }
            }
        }
    }
    
    fileprivate func didReveiceMessage(_ message:SignalingMessage){
        let serialQueue = DispatchQueue(label: "serialQueue")
        serialQueue.sync { [unowned self] in
            switch message.type {
            case .Offer, .Answer:
                // Offers and answers must be processed before any other message, so we
                // place them at the front of the queue.
                self.messages.insert(message, at: 0)
                self.receivedSDP = true
            case .Candidate, .CandidateRemoval:
                self.messages.append(message)
            case .Bye:
                self.process(message)
                break
            }
            if self.isPreviewing{
                self.drainMessageQueueIfReady()
            }
        }
    }
    
    fileprivate func drainMessageQueueIfReady(){
        if self.receivedSDP{
            for message in messages{
                self.process(message)
                self.messages.removeFirst()
            }
        }
    }
    
    fileprivate func process(_ message:SignalingMessage){
        switch message.type {
        case .Offer, .Answer:
            let sdp = message.sdp
            print("\(UIDevice.current.name) process \(message.type.rawValue) start")
            RTCUtil.sharedInstance().setRemoteDescription(self.peerConnection, description: sdp, complete: { (error:Error?) in
                guard error == nil else{
                    print("Failed to set remote session description. Error: \(error)")
                    return
                }
                if message.type == .Offer{
                    self.createAnswer()
                }
                print("\(UIDevice.current.name) process \(message.type.rawValue) done")
            })
        case .Candidate:
            let candidate = message.candidate!
            print("\(UIDevice.current.name) process candidate start")
            print(candidate.sdp)
            self.peerConnection.add(candidate)
            print("\(UIDevice.current.name) process candidate done")
        case .CandidateRemoval:
            let candidate = message.candicates!
            print("\(UIDevice.current.name) process remove candidate start")
            self.peerConnection.remove(candidate)
            print("\(UIDevice.current.name) process remote candidate done")
        case .Bye:
            self.reset()
            self.delegate?.didLeave(callee: self)
        }
    }
}

//MARK: - Private Method for Http Request
extension Callee{
    
    fileprivate func createRequest(_ type:SignalingServerPath, data:Data!) -> URLRequest{
        
        
        let urlString = "\(ServerProtocol)\(ip):\(ServerPoft)\(type.rawValue)"
        let url = URL(string: urlString)
        let request = NSMutableURLRequest(url: url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        if let data = data{
            request.setValue(UIDevice.current.identifierForVendor!.uuidString, forHTTPHeaderField: Callee_HTTPHeader_Key.sessionId)
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
        }
        return request as URLRequest
    }
    
    fileprivate func runInMainThead(_ closure:@escaping ()->()){
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                closure()
            }
        }
    }
    
    fileprivate func createOffer() {
        print("\(UIDevice.current.name) create offer")
        RTCUtil.sharedInstance().createOffer(self.peerConnection) { (offer, error) in
            if error == nil{
                self.sendOffer(offer!.jsonData())
                self.setMaxBitrate()
            }
        }
    }
    
    fileprivate func createAnswer(){
        print("\(UIDevice.current.name) create answer")
        RTCUtil.sharedInstance().createAnswer(self.peerConnection) { (answer, error) in
            if error == nil{
                self.sendAnswer(answer!.jsonData())
                self.setMaxBitrate()
            }
        }
    }
    
    fileprivate func sendOffer(_ data:Data){
        print("\(UIDevice.current.name) send offer")
        let request = self.createRequest(.Offer, data: data)
        Alamofire.request(request).responseJSON { (response:DataResponse<Any>) in
            self.handle(response: response)
        }
    }
    
    fileprivate func sendAnswer(_ data:Data){
        print("\(UIDevice.current.name) send answer")
        let request = self.createRequest(.Answer, data: data)
        Alamofire.request(request).responseJSON { (response:DataResponse<Any>) in
            self.handle(response: response)
        }
    }
    
    fileprivate func sendCandidate(_ data:Data){
        print("\(UIDevice.current.name) send candidate")
        let request = self.createRequest(.Candidate, data: data)
        Alamofire.request(request).responseJSON { (response:DataResponse<Any>) in
            self.handle(response: response)
        }
    }
    
    fileprivate func sendRemoveCandidate(_ data:Data){
        print("\(UIDevice.current.name) send remove candidates")
        let request = self.createRequest(.CandidateRemoval, data: data)
        Alamofire.request(request).responseJSON { (response:DataResponse<Any>) in
            self.handle(response: response)
        }
    }
    
    fileprivate func handle(response:DataResponse<Any>){
        if response.result.isFailure{
            print(response.result.error!)
            return
        }
        
        if let dict = response.result.value as? [String:Any], dict.keys.contains(where: { (key) -> Bool in
            return key == SignalingResponse_Keys.Error}){
            print(dict[SignalingResponse_Keys.Error]!)
        }
    }
    
    fileprivate func sendHello(){
        let dict = [Callee_HTTPHeader_Key.device:UIDevice.current.name, Callee_HTTPHeader_Key.ip:SDPUtils.getWiFiAddress()!]
        let json = JSON(dict)
        do{
            let jsonData = try json.rawData()
            let request = self.createRequest(.Hello, data: jsonData)
            Alamofire.request(request).responseJSON(completionHandler: { (response:DataResponse<Any>) in
                if response.result.isFailure{
                    return
                }
                
                self.runInMainThead {
                    guard var dict = response.result.value as? [String : Any] else{
                        print("Hello response data some worng")
                        return
                    }
                    dict[Callee_HTTPHeader_Key.sessionId] = response.response?.allHeaderFields[Callee_HTTPHeader_Key.sessionId]
                    NotificationCenter.default.post(name: SignalingServer_NewPeer, object: nil, userInfo: dict)
                }
            })
        }catch{
            print(error)
        }
    }
    
    fileprivate func sendBye(complete:(()->Void)?){
        let dict = ["message":"Bye"]
        let json = JSON(dict)
        do{
            let jsonData = try json.rawData()
            let request = self.createRequest(.Bye, data: jsonData)
            Alamofire.request(request).responseJSON(completionHandler: { (response:DataResponse<Any>) in
                self.runInMainThead {
                    complete?()
                }
            })
        }catch{
            print(error)
        }
    }
}

//MARK: - Public Method for Http response
extension Callee{
    
    public func receiveByeJson(_ jsonDictionary:[AnyHashable : Any]){
        print("\(UIDevice.current.name) receiveByeJson")
        runInMainThead {
            let message = SignalingMessage(type: .Bye)
            self.didReveiceMessage(message)
        }
    }
    
    public func receiveOfferJson(_ jsonDictionary:[AnyHashable : Any]){
        print("\(UIDevice.current.name) receiveOfferJson")
        runInMainThead {
            let offerSDP = RTCSessionDescription(fromJSONDictionary: jsonDictionary)
            let message = SignalingMessage(type: .Offer)
            message.sdp = offerSDP
            self.didReveiceMessage(message)
        }
    }
    
    public func receiveAnswerJson(_ jsonDictionary:[AnyHashable : Any]){
        print("\(UIDevice.current.name) receiveAnswerJson")
        self.runInMainThead {
            let answerSDP = RTCSessionDescription(fromJSONDictionary: jsonDictionary)
            let message = SignalingMessage(type: .Answer)
            message.sdp = answerSDP
            self.didReveiceMessage(message)
        }
    }
    
    public func receiveCandidate(_ jsonDictionary:[AnyHashable : Any]){
        print("\(UIDevice.current.name) receiveCandidate")
        self.runInMainThead {
            let candidate = RTCIceCandidate(fromJSONDictionary: jsonDictionary)
            let message = SignalingMessage(type: .Candidate)
            message.candidate = candidate
            self.didReveiceMessage(message)
        }
    }
    
    public func receiveRemoveCandidate(_ jsonArray:[Any]){
        print("\(UIDevice.current.name) receiveRemoveCandidate")
        self.runInMainThead {
            let candidates = RTCIceCandidate.candidates(fromJSONArray: jsonArray)
            let message = SignalingMessage(type: .CandidateRemoval)
            message.candicates = candidates
            self.didReveiceMessage(message)
        }
    }
}

//MARK: - PeerConnectionHandlerDelegate
extension Callee:RTCPeerConnectionDelegate{
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("\(UIDevice.current.name) peerConnection did change state \(stateChanged.rawValue)")
    }
    
    /** Called when media is received on a new stream from remote peer. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream){
        print("\(UIDevice.current.name) Received \(stream.videoTracks.count) video tracks and \(stream.audioTracks.count) audio tracks")
        if let track = stream.videoTracks.first{
            self.runInMainThead {
                self.reset()
                self.tracks.remoteViewTrack = track
                self.delegate?.didReceive(remoteVideoTrack: self.tracks.remoteViewTrack)
            }
        }
    }
    
    /** Called when a remote peer closes a stream. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream){
        print("\(UIDevice.current.name) Stream was removed.")
    }
    
    /** Called when negotiation is needed, for example ICE has restarted. */
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection){
        print("\(UIDevice.current.name) WARNING: Renegotiation needed but unimplemented.")
    }
    
    
    /** Called any time the IceConnectionState changes. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState){
        print("\(UIDevice.current.name) ICE connection state changed: \(newState.rawValue)")
        
        switch newState {
        case .failed, .disconnected, .closed:
            self.reset()
            self.runInMainThead {
                self.delegate?.didPeerDisconnected()
            }
        default:
            break
        }
    }
    
    /** Called any time the IceGatheringState changes. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState){
        print("\(UIDevice.current.name) ICE gathering state changed: \(newState)")
    }
    
    
    /** New ice candidate has been found. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate){
        print("\(UIDevice.current.name) didGenerate candidate")
        if let data = candidate.jsonData(){
            self.runInMainThead {
                self.sendCandidate(data)
            }
        }
    }
    
    /** Called when a group of local Ice candidates have been removed. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]){
        print("\(UIDevice.current.name) didRemove candidate")
        let jsonData = RTCIceCandidate.jsonData(for: candidates)
        self.runInMainThead {
            self.sendRemoveCandidate(jsonData!)
        }
    }
    
    /** New data channel has been opened. */
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel){
        print("\(UIDevice.current.name) didOpen Data Channel")
    }
}
