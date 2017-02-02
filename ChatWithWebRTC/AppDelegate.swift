//
//  AppDelegate.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/4.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import UIKit
import WebRTC

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    fileprivate let bjService = BonjourService()
    fileprivate let signalingServer = SignalingServer()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        self.setupWebRTC()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.bjService.enable(false)
        self.signalingServer.start(false)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        self.bjService.enable(true)
        self.signalingServer.start()
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        self.setupWebRTC(isInitialize: false)
    }

    fileprivate func setupWebRTC(isInitialize initialize:Bool = true){
        if initialize{
            RTCInitFieldTrials(.improvedBitrateEstimate)
            RTCInitializeSSL();
            RTCSetupInternalTracer();
            #if DEBUG
//                RTCSetMinDebugLogLevel(.info)
            #endif
        }else{
            RTCShutdownInternalTracer();
            RTCCleanupSSL();
        }
    }

}

