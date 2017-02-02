//
//  SignalingResponse.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/20.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import UIKit

let SignalingResponse_Keys = (Error:"errormsg", Status:"status")

class SignalingResponse:HTTPDataResponse{

    override func httpHeaders() -> [AnyHashable : Any]! {
        var header = [String:Any]()
//        header["Content-Type"] = "text/plain; charset=utf-8"
        header["Content-Type"] = "application/json; charset=utf-8"
        header["Content-Length"] = String(self.contentLength())
        header[Callee_HTTPHeader_Key.sessionId] = UIDevice.current.identifierForVendor!.uuidString
        return header
    }
}
