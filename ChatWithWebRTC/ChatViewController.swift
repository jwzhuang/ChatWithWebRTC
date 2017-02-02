//
//  ViewController.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/4.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import UIKit
import WebRTC

class ChatViewController: UIViewController{
    
    fileprivate lazy var CameraResult: SessionSetupResult = self.checkCameraAuthorization()
    fileprivate lazy var MicrophoneResult: SessionSetupResult = self.checkMicrophoneAuthorization()
    @IBOutlet weak var localView: RTCCameraPreviewView!
    @IBOutlet weak var remoteView: RTCEAGLVideoView!
    public var callee:Callee?
    public var isCaller = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.callee?.delegate = self
        self.navigationItem.hidesBackButton = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.chatWithCallee()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    fileprivate func chatWithCallee(){
        sessionQueue.async {
            
            guard self.CameraResult == .success else{
                let message = NSLocalizedString("Doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
                self.requestPermission(message)
                return
            }
            
            guard self.MicrophoneResult == .success else{
                let message = NSLocalizedString("Doesn't have permission to use the microphone, please change privacy settings", comment: "Alert message when the user has denied access to the microphone")
                self.requestPermission(message)
                return
            }
            
            self.callee?.prepare(self.isCaller, localView: self.localView)
        }
    }
    
    //MARK: - Actions
    
    @IBAction func clickSwitch(_ sender: Any) {
        self.callee?.switchCamera()
    }
    
    @IBAction func disconnect(_ sender: Any){
        self.callee?.disconnect(complete: {
            self.didLeave(callee: self.callee!)
        })
    }
    
    @IBAction func clickBack(_ sender: Any){
        self.callee?.disconnect(complete: {
            self.didLeave(callee: self.callee!)
        })
    }
    
    @IBAction func clickOther(_ sender: Any){
        let videoTitle = (self.callee?.isVideoEnable())! ? NSLocalizedString("Disable Video", comment: "Video Button") : NSLocalizedString("Enable Video", comment: "Video Button")
        let videoAction = UIAlertAction.init(title: videoTitle, style: .default) { (action) in
            self.callee?.enableVideo()
        }
        
        let audioTitle = (self.callee?.isAudioEnable())! ? NSLocalizedString("Disable Audio", comment: "Audio Button") : NSLocalizedString("Enable Audio", comment: "Audio Button")
        
        let audioAction = UIAlertAction.init(title: audioTitle, style: .default) { (action) in
            self.callee?.enableAudio()
        }
        
        let alert = UIAlertController.init(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(videoAction)
        alert.addAction(audioAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    //MARK: - Authorization
    fileprivate enum SessionSetupResult {
        case success
        case notAuthorized
    }
    
    fileprivate let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
    
    fileprivate func checkCameraAuthorization() -> SessionSetupResult{
        var result:SessionSetupResult = .success
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            result = .success
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [unowned self] granted in
                result = granted ? .success : .notAuthorized
                self.sessionQueue.resume()
            })
        default:
            result = .notAuthorized
        }
        return result
    }
    
    fileprivate func checkMicrophoneAuthorization() -> SessionSetupResult{
        var result:SessionSetupResult = .success
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            result = .success
        case .notDetermined:
            sessionQueue.suspend()
            AVAudioSession.sharedInstance().requestRecordPermission({ [unowned self] granted in
                result = granted ? .success : .notAuthorized
                self.sessionQueue.resume()
            })
            
        default:
            result = .notAuthorized
        }
        return result
    }

    fileprivate func requestPermission(_ message:String){
        DispatchQueue.main.async { [unowned self] in
            
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
            
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
                }
            }))
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

//MARK: - CalleeDelegate
extension ChatViewController:CalleeDelegate{
    func didReceive(remoteVideoTrack: RTCVideoTrack) {
        remoteVideoTrack.add(self.remoteView)
    }
    
    func didReset(remoteVideoTrack: RTCVideoTrack) {
        self.localView.captureSession = nil
        remoteVideoTrack.remove(self.remoteView)
    }
    
    func didLeave(callee: Callee) {
        _ = self.navigationController?.popViewController(animated: true)
    }
    
    func didPeerDisconnected() {
        let actionOK = UIAlertAction.init(title: NSLocalizedString("OK", comment: "OK Button"), style: .default) { (action:UIAlertAction) in
            self.didLeave(callee: self.callee!)
        }
        
        let alert = UIAlertController(title: nil, message: NSLocalizedString("Peer was disconnected", comment: "Disconnected Alert View"), preferredStyle: .alert)
        alert.addAction(actionOK)
        self.present(alert, animated: true, completion: nil)
    }
}

