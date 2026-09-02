//
//  DeviceType.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

#if os(iOS)
import UIKit
#endif

enum DeviceType {
    case iPhone, iPad, mac, unknown
    
    static var current: DeviceType {
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return .iPhone
        case .pad:
            return .iPad
        default:
            return .unknown
        }
        #elseif os(macOS)
        return .mac
        #else
        return .unknown
        #endif
    }
    
    static var isIphone: Bool {
        DeviceType.current == DeviceType.iPhone
    }
    
    static var isIpad: Bool {
        DeviceType.current == DeviceType.iPad
    }
    
    static var isMac: Bool {
        DeviceType.current == DeviceType.mac
    }
}
