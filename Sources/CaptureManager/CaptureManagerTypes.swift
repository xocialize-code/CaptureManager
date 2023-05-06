//
//  File.swift
//  
//
//  Created by Dustin Nielson on 5/6/23.
//

import Cocoa
import SceneKit

public enum DeviceFamily: String, CaseIterable {
    case iPhoneLegacy, iPhoneXSeries, iPad, iPadPro11

    public var raw: String {
        switch self {
        case .iPad:
            return "iPad"
        case .iPadPro11:
            return "iPadPro"
        case .iPhoneLegacy:
            return "iPhoneLegacy"
        case .iPhoneXSeries:
            return "iPhoneXSeries"
        }
    }
}

public enum Orientation {
    case portrait, landscape
}

enum PixelFormat {
    case rgb
    case yCbCr
    
    var coreVideoType: OSType {
        switch self {
        case .rgb:
            return kCVPixelFormatType_32BGRA
        case .yCbCr:
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            
        }
    }
}

public enum TheaterMode {
    case desktop, capture
}

struct VideoSpec {
    var fps: Int32?
    var size: CGSize?
}
