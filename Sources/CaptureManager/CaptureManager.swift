//
//  AVSessionManager.swift
//  MVS Expo
//
//  Created by Dustin Nielson on 9/2/22.
//

import Cocoa
import AVFoundation
import CoreMediaIO

public protocol CaptureManagerDelegate: AnyObject {
    func deviceSampleBuffer(sampleBuffer: CMSampleBuffer)
    func captureSampleBuffer(sampleBuffer: CMSampleBuffer)
    func captureDevice(active: Bool)
    func autoDetect(deviceFamily: DeviceFamily)
    func deviceLost()
}

@available(macOS 10.15, *)
public final class CaptureManager: AVCaptureSession {
    var debugCount:Int = 0
    
    public weak var delegate: CaptureManagerDelegate?
    
    var observers:[NSObjectProtocol] = [NSObjectProtocol]()
    
    var previewDevice:CapturePreviewView!
    var previewLaptop:CapturePreviewView!
    
    var sessionQueue = DispatchQueue(label: "sessionManagerQueue", qos: .userInteractive, attributes: [])
    
    var audioPassthruEnabled:Bool = true {
        didSet {
            guard activeIOS != nil else { return }
            if audioPassthruEnabled {
                activeIOS?.audioPreview?.volume = 1
            } else {
                activeIOS?.audioPreview?.volume = 0
            }
        }
    }
    
    var captureDevices:[CaptureDevice] = [CaptureDevice]()
    
    var activeIOS:CaptureDevice? {
        didSet{
            guard activeIOS != nil else { return }
            if audioPassthruEnabled {
                activeIOS?.audioPreview?.volume = 1
            } else {
                activeIOS?.audioPreview?.volume = 0
            }
        }
    }
    
    var activeCapture:CaptureDevice? {
        didSet{
            guard activeCapture != nil else {
                delegate?.captureDevice(active: false)
                return
            }
            delegate?.captureDevice(active: true)
        }
    }
    
    public convenience init(delegate: CaptureManagerDelegate) {
        self.init()
        self.delegate = delegate
        sessionQueue.async { [weak self] in
            self!.sessionPreset = .high
            self!.startRunning()
        }
        captureManagerInit()
    }
    
    public override init() { super.init() }
    
    func captureManagerInit(){
        previewLaptop = {
            let mv = CapturePreviewView(frame: NSZeroRect)
            return mv
        }()
        previewDevice = {
            let mv = CapturePreviewView(frame: NSZeroRect)
            return mv
        }()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            self.enableIosDevices()
        }
        
        enableObservers()
        
        print("CaptureManager :: init :: COMPLETE")
    }
    
    func enableIosDevices(allow_in: UInt32 = 1){
        
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var allow: UInt32 = allow_in;
        
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil, UInt32(MemoryLayout.size(ofValue: allow)), &allow)
        
    }
    
    func availableDevices() -> [AVCaptureDevice] {
        var deviceList = [AVCaptureDevice]()
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession( deviceTypes: [.externalUnknown, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        let deviceDiscoverySessionMuxed = AVCaptureDevice.DiscoverySession( deviceTypes: [.externalUnknown, .builtInWideAngleCamera], mediaType: .muxed, position: .unspecified)
        deviceList.append(contentsOf: deviceDiscoverySession.devices)
        deviceList.append(contentsOf: deviceDiscoverySessionMuxed.devices)
        
        return deviceList
    }
    
    func refreshDevices(){
        print("AppManagerCaptureExtension :: refreshDevices :: Refresh Devices Called")
        let devices = availableDevices()
        for device in devices {
            deviceFound(device: device)
        }
    }
    
    func deviceFound(device: AVCaptureDevice){
        print("AppManagerCaptureExtension :: deviceFound :: Found Device: \(device)")
        print("AppManagerCaptureExtension :: deviceFound :: device.model: \(device.modelID)")
        print("AppManagerCaptureExtension :: deviceFound :: device.manufacturer: \(device.manufacturer)")
        if device.modelID == "iOS Device" {
            guard activeIOS == nil else { return }
            
            activeIOS = {
                let ai = CaptureDevice(device: device, delegate: self)
                return ai
            }()
            
            if let activeIOS = activeIOS {
                addToSession(captureDevice: activeIOS)
            }
            
            print("AppManagerCaptureExtension :: deviceFound :: Device CANDIDATE :: \(device)")
            
        } else {
            guard activeCapture == nil && device.manufacturer != "Apple Inc."  else { return }
            
            activeCapture = {
                let ac = CaptureDevice(device: device, delegate: self)
                return ac
            }()
            
            if let activeCapture = activeCapture {
                addToSession(captureDevice: activeCapture)
            }
            
            print("AppManagerCaptureExtension :: deviceFound :: LAPTOP CANDIDATE :: \(device)")
        }
    }
    
    func deviceLost(device: AVCaptureDevice){
        print("AppManagerCaptureExtension :: deviceLost :: Lost Device: \(device)")
        if activeIOS != nil {
            if device.uniqueID == activeIOS?.device.uniqueID {
                removeFromSession(captureDevice: activeIOS!) {
                    print("AppManagerCaptureExtension :: deviceLost :: HERE IS GOOD Device removed")
                    self.activeIOS = nil // NSImage(named: "demod3sk_phone")
                    //let texture = self.mm.convertDataToMetalTexture(data: NSImage(named: "device")!.tiffRepresentation!)
                    //self.bezelSCNScene.applyTexture(texture: texture!)
                }
            }
        }
        
        if activeCapture != nil {
            if device.uniqueID == activeCapture?.device.uniqueID {
                removeFromSession(captureDevice: activeCapture!) {
                    print("AppManagerCaptureExtension :: deviceLost :: HERE IS GOOD Capture removed")
                    self.activeCapture = nil // NSImage(named: "demod3sk_phone")
                }
            }
        }
        
    }
    
    func addToSession(captureDevice: CaptureDevice){
        
        print("AVSessionManager :: addToSession :: \(captureDevice.device.uniqueID)")
        
        sessionQueue.async { [weak self] in
            self!.beginConfiguration()
            
            if self!.canAddInput(captureDevice.input!) && self!.canAddOutput(captureDevice.dataVideoOutput!) {
                
                self!.addInputWithNoConnections(captureDevice.input!)
                self!.addOutputWithNoConnections(captureDevice.dataVideoOutput!)
                
                if self!.canAddConnection(captureDevice.videoConnection!){
                    self!.addConnection(captureDevice.videoConnection!)
                }
                
                let previewConnection = captureDevice.setupPreviewLayer(session: self!)
                
                if self!.canAddConnection(previewConnection) {
                    self!.addConnection(previewConnection)
                    print("AVSessionManager :: addToSession :: VideoPreviewLayer connection should have added")
                } else {
                    print("AVSessionManager :: addToSession :: Can't add preview connection")
                }
                
            } else {
                print("AVSessionManager :: addToSession :: FAILED Device AV Input/Output check in AVSessionManager")
            }
            
            if captureDevice.audioPreview != nil && self!.canAddOutput(captureDevice.audioPreview!){
                
                self!.addOutputWithNoConnections(captureDevice.audioPreview!)
                
                if captureDevice.audioConnection != nil {
                    if self!.canAddConnection(captureDevice.audioConnection!){
                        self?.addConnection(captureDevice.audioConnection!)
                    }
                }
            
            } else {
                
                if self!.canAddOutput(captureDevice.dataAudioOutput!){
                    self!.addOutputWithNoConnections(captureDevice.dataAudioOutput!)
                    if captureDevice.audioConnection != nil {
                        if self!.canAddConnection(captureDevice.audioConnection!) {
                            self!.addConnection(captureDevice.audioConnection!)
                        }
                    }
                }
                
            }
            
            self!.commitConfiguration()
            
            self!.captureDevices.append(captureDevice)
        }
    }
    
    func removeFromSession(captureDevice: CaptureDevice, completion:  @escaping () -> Void ) {
        
         if let itemIndex = captureDevices.enumerated().filter({ $0.element.device!.uniqueID == captureDevice.device.uniqueID }).map({ $0.offset }).first {
            
            sessionQueue.async { [weak self] in
                self!.beginConfiguration()
                
                if self!.captureDevices[itemIndex].audioConnection != nil {
                    self!.removeConnection(self!.captureDevices[itemIndex].audioConnection!)
                }
                
                if self!.captureDevices[itemIndex].videoConnection != nil {
                    self!.removeConnection(self!.captureDevices[itemIndex].videoConnection!)
                }
                
                for op in self!.outputs {
                    switch op {
                    case self!.captureDevices[itemIndex].dataAudioOutput:
                        self!.removeOutput(op)
                        break
                    case self!.captureDevices[itemIndex].dataVideoOutput:
                        self!.removeOutput(op)
                        break
                    default: break
                    }
                }
                
                if self!.captureDevices[itemIndex].videoPreviewConnectionActive {
                    self!.removeConnection(self!.captureDevices[itemIndex].videoPreviewConnection!)
                }
                
                self!.removeInput(self!.captureDevices[itemIndex].input!)
                self!.commitConfiguration()
                self!.captureDevices[itemIndex].prepareForRemoval()
                self!.captureDevices.remove(at: itemIndex)
                self!.commitConfiguration()
                completion()
            }
             
        } else {
            print("AVSessionManager :: removeFromSession :: Remove Requested But No Device Is Found")
            completion()
        }
    }
    
}

@available(macOS 10.15, *)
extension CaptureManager: CaptureDeviceDelegate {
    func deviceVideoBuffer(model: String, sampleBuffer: CMSampleBuffer, uniqueID: String) {
        switch model {
        case "iOS Device":
            delegate?.deviceSampleBuffer(sampleBuffer: sampleBuffer)
            break;
        default:
            debugCount = debugCount + 1
            //print("CaptureManager :: CaptureDeviceDelegate :: deviceVideoBuffer :: model :: \(model) \(debugCount)")
            delegate?.captureSampleBuffer(sampleBuffer: sampleBuffer)
            break;
        }
        
    }
    
    func devicePreviewLayer(previewLayer: AVCaptureVideoPreviewLayer, model: String) {
        print("CaptureManager :: CaptureDeviceDelegate :: devicePreviewLayer :: model :: \(model)")
        if model == "iOS Device" {
            previewDevice.initPreviewLayer(videoPreviewLayer: previewLayer)
        } else {
            previewLaptop.initPreviewLayer(videoPreviewLayer: previewLayer)
        }
    }
    
    func autoDetect(deviceFamily: DeviceFamily) {
        delegate?.autoDetect(deviceFamily: deviceFamily)
        print("CaptureManager :: CaptureDeviceDelegate :: autoDetect :: \(deviceFamily)")
    }
}
