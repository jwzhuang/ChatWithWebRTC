//
//  SDPUtils.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/9.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import WebRTC

public enum SDPCodec:String{
    case H264 = "H264"
}

public enum SDPError: Int {
    case ErrorUnknown = -99, ErrorCreateSDP, ErrorSetSDP, ErrorInvalidClient
}

class SDPUtils{
    class func sessionDescription(sdp description:RTCSessionDescription, codec:SDPCodec) -> RTCSessionDescription{
        let sdpString = description.sdp
        let lineSeparator = "\n"
        let mLineSeparator = " "
        let findVideo = "m=video"
        var lines = sdpString.components(separatedBy: lineSeparator)
        var lineIndex = -1
        for line in lines{
            lineIndex += 1
            if line.hasPrefix(findVideo){
                break
            }
        }
        
        guard lineIndex != -1 else {
            print("No \(findVideo) line, so can't prefre \(codec.rawValue)")
            return description
        }
        
        // An array with all payload types with name |codec|. The payload types are
        // integers in the range 96-127, but they are stored as strings here.
        var codecPayloadTypes = [String]()
        // a=rtpmap:<payload type> <encoding name>/<clock rate>
        // [/<encoding parameters>]
        let pattern = "^a=rtpmap:(\\d+) \(codec.rawValue)(\\/\\d+)+[\r]?$"
        
        do{
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            for line in lines{
                if let codecMatches = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.characters.count)){
                    let codecPayloadType = (line as NSString).substring(with: codecMatches.rangeAt(1))
                    codecPayloadTypes.append(codecPayloadType)
                }
                
            }
            guard codecPayloadTypes.count > 0 else{
                print("No payload types with name \(codec)")
                return description
            }
            let origMLineParts = lines[lineIndex].components(separatedBy: mLineSeparator)
            
            // The format of ML should be: m=<media> <port> <proto> <fmt> ...
            let kHeaderLength = 3
            guard origMLineParts.count > kHeaderLength else {
                print("Wrong SDP media description format: \(lines[lineIndex])")
                return description
            }
            
            // Split the line into header and payloadTypes.
            let header = origMLineParts[0..<kHeaderLength]
            var payloadTypes = origMLineParts[kHeaderLength..<origMLineParts.count]
            
            // Reconstruct the line with |codecPayloadTypes| moved to the beginning of the
            // payload types.
            var newMLineParts = [String]()
            newMLineParts.append(contentsOf: header)
            newMLineParts.append(contentsOf: codecPayloadTypes)
            for type in codecPayloadTypes{
                let index = payloadTypes.index(of: type)
                payloadTypes.remove(at: index!)
            }
            newMLineParts.append(contentsOf: payloadTypes)
            
            let newMLine = newMLineParts.joined(separator: mLineSeparator)
            lines[lineIndex] = newMLine
            
            let mangledSdpString = lines.joined(separator: lineSeparator)
            return RTCSessionDescription(type: description.type, sdp: mangledSdpString)
        }catch{
            //Handle error
            print(error)
            return description
        }
    }
    
    class func error(reflecting subject: Any, info:String, errorCode code:SDPError = .ErrorUnknown) -> NSError{
        let domain = String(describing: subject)
        let userInfo = [NSLocalizedDescriptionKey: info]
        let error = NSError(domain: domain, code: code.rawValue, userInfo: userInfo)
        return error
    }
    
    class func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
}
