//
//  Eddystone.swift
//  TogetHomeExperiment
//
//  Created by IT DICE on 2023/04/02.
//

import Foundation
import CoreBluetooth

class BeaconID: NSObject {
    
    enum IDType {
        case Namespace
        case Instance
    }
    
    let namespaceID: [UInt8]
    let instanceID: [UInt8]
    
    private init(namespaceID: [UInt8], instanceID: [UInt8]) {
        self.namespaceID = namespaceID
        self.instanceID = instanceID
    }
    
    // BeaconID description Overriding
    override var description: String {
        let hexNamespaceID = inttohex(intData: self.namespaceID)
        let hexInstanceID = inttohex(intData: self.instanceID)
        
        return "BeaconID [NamespaceID] : \(hexNamespaceID), [InstanceID] : \(hexInstanceID)"
    }
    
    class func beaconIDfromData(beaconIDRawData: [UInt8]) -> BeaconID {
        let namespaceID: [UInt8] = Array(beaconIDRawData[0..<10])
        let instanceID: [UInt8] = Array(beaconIDRawData[10..<16])
        
        return BeaconID(namespaceID: namespaceID, instanceID: instanceID)
    }
    
    // BeaconID String Output
    public func idtostring(idType: IDType) -> String {
        if idType == IDType.Namespace {
            return inttohex(intData: self.namespaceID)
        }
        else if idType == IDType.Instance {
            return inttohex(intData: self.instanceID)
        }
        else
        {
            return ""
        }
    }
    
    // UInt8 data to Hex Stirng
    private func inttohex(intData: [UInt8]) -> String {
        var retval = ""
        for byte in intData {
            var s = String(byte, radix: 16, uppercase: true)
            if s.count == 1{
                s = "0" + s
            }
            retval += s
        }
        return retval
    }
}

class BeaconState: NSObject {
    
    enum StateType {
        case Normal
        case Triggered
        case LowBattery
        case Unknown
    }
    
    static let StateNormal: UInt8 = 0x00
    static let StateTriggered: UInt8 = 0x10
    static let StateLowBattery: UInt8 = 0x20
    
    let deviceState: StateType
    let batteryAmout: Int
    let deviceStateHex: String
    
    private init(deviceState: StateType, batteryAmout: Int, deviceStateHex: String) {
        self.deviceState = deviceState
        self.batteryAmout = batteryAmout
        self.deviceStateHex = deviceStateHex
    }
    
    // BeaconState description Overriding
    override var description: String {
        let stateString: String
        
        switch self.deviceState {
        case .Normal:
            stateString = "Normal"
        case .Triggered:
            stateString = "Triggreed"
        case .LowBattery:
            stateString = "Low Battery"
        case .Unknown:
            stateString = "Uknown State"
        }
        
        return "BeaconState [CurrentState] : \(stateString), [BatteryLevel] : \(self.batteryAmout)%"
    }
    
    // Initail BeaconState Function
    class func stateTypeFromData(stateRawData: [UInt8]) -> BeaconState? {
        if stateRawData.count == 2 {
            
            let deviceState: StateType
            let batteryAmount: Int
            var deviceStateHex: String = ""
            
            switch stateRawData[0] {
            case StateNormal:
                deviceState = .Normal
            case StateTriggered:
                deviceState = .Triggered
            case StateLowBattery:
                deviceState = .LowBattery
            default:
                deviceState = .Unknown
            }
            
            batteryAmount = Int(stateRawData[1])
            
            for byte in stateRawData {
                var s = String(byte, radix: 16, uppercase: true)
                if s.count == 1{
                    s = "0" + s
                }
                deviceStateHex += s
            }
            
            return BeaconState(deviceState: deviceState, batteryAmout: batteryAmount, deviceStateHex: deviceStateHex)
        }
        else {
            NSLog("This BeaconState Data is not available.")
            return nil
        }
    }
}

class BeaconInfo: NSObject {
    
    static let EddystoneUID: UInt8 = 0x00
    
    let txPower: Int
    let beaconID: BeaconID?
    let beaconState: BeaconState?
    let RSSI: Int
    
    enum EddystoneFrameType {
        case UID
        case Unknown
        
        var description: String {
            switch  self {
            case .UID:
                return "UID Frame"
            case .Unknown:
                return "Unknown Frame Type"
            }
        }
    }
    
    private init(txPower: Int, beaconID: BeaconID?, beaconState: BeaconState?, RSSI: Int) {
        self.txPower = txPower
        self.beaconID = beaconID
        self.beaconState = beaconState
        self.RSSI = RSSI
    }
    
    class func frameTypefromData(advertisementFrameList: [NSObject : AnyObject]) -> EddystoneFrameType {
        let uuid = CBUUID(string: "FEAA")
        if let frameData = advertisementFrameList[uuid] as? NSData {
            if frameData.length > 1 {
                let count = frameData.length
                var frameBytes = [UInt8](repeating: 0, count: count)
                frameData.getBytes(&frameBytes, length: count)
                
                if frameBytes[0] == EddystoneUID {
                    return EddystoneFrameType.UID
                }
            }
        }
        return EddystoneFrameType.Unknown
    }
    
    class func beaconInfoFromData(frameData: NSData, RSSI: Int) -> BeaconInfo? {
        if frameData.length > 1 {
            let count = frameData.length
            var frameByte = [UInt8](repeating: 0, count: count)
            frameData.getBytes(&frameByte, length: count)
            
            if frameByte[0] != EddystoneUID {
                NSLog("[Warning] This data is not a UID Frame.")
                return nil
            }
            else if frameByte.count < 20 {
                NSLog("[Warning] Data is partially truncated.")
                return nil
            }
            else {
                let _txPower: Int = Int(Int8(bitPattern: frameByte[1]))
                let beaconIDData: [UInt8] = Array(frameByte[2..<18])
                let beaconStateData: [UInt8] = Array(frameByte[18..<20])
                
                let _beaconID: BeaconID = BeaconID.beaconIDfromData(beaconIDRawData: beaconIDData)
                let _beaconState: BeaconState? = BeaconState.stateTypeFromData(stateRawData: beaconStateData)
                
                return BeaconInfo(txPower: _txPower, beaconID: _beaconID, beaconState: _beaconState, RSSI: RSSI)
            }
        }
        else {
            NSLog("[Warning] This data is not available.")
            return nil
        }
    }
    
    override var description: String {
        return "Eddystone \(String(describing: self.beaconID)), \(String(describing: self.beaconState)), txPower: \(self.txPower), RSSI: \(self.RSSI)"
    }
}
