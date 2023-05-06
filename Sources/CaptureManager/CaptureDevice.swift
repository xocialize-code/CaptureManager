//
//  CaptureDevice.swift
//  MVS Expo
//
//  Created by Dustin Nielson on 9/2/22.
//

import Cocoa
import AVFoundation

protocol CaptureDeviceDelegate: AnyObject {
    
    func deviceVideoBuffer(model: String, sampleBuffer: CMSampleBuffer, uniqueID: String)
    
    func devicePreviewLayer(previewLayer: AVCaptureVideoPreviewLayer, model: String)
    
    func autoDetect(deviceFamily: DeviceFamily)
    
}

class CaptureDevice: NSObject {
    var count:Int = 0
    
    weak var delegate:CaptureDeviceDelegate?
    
    var observers:[NSObjectProtocol] = [NSObjectProtocol]()
    
    var device:AVCaptureDevice!
    
    var captureDeviceQueue:DispatchQueue!
    
    var previewLayer:AVCaptureVideoPreviewLayer!
    
    var input:AVCaptureInput?
    var dataVideoOutput:AVCaptureVideoDataOutput?
    var dataAudioOutput:AVCaptureAudioDataOutput?
    
    var videoPort:AVCaptureInput.Port?
    var audioPort:AVCaptureInput.Port?
    
    var videoConnection:AVCaptureConnection?
    var audioConnection:AVCaptureConnection?
    var videoPreviewConnection:AVCaptureConnection? // Need to figure out why the metal conversion from the BM Devices is so choppy
    var audioPreviewConnection:AVCaptureConnection?
    
    var audioPreview:AVCaptureAudioPreviewOutput? //This is temporary until I figure out how to do it with the sample buffer
    
    var videoPreviewConnectionActive:Bool = false
    
    var width:Int32 = 0
    var height:Int32 = 0
    var orientation:Orientation = .portrait
    var deviceFamily:DeviceFamily = .iPhoneLegacy {
        didSet{
            delegate?.autoDetect(deviceFamily: deviceFamily)
        }
    }
    
    convenience init(device: AVCaptureDevice, delegate: CaptureDeviceDelegate) {
        self.init()
        self.delegate = delegate
        self.device = device
        self.captureDeviceQueue = DispatchQueue(label: device.uniqueID, qos: .userInteractive, attributes: [])
        //self.captureDeviceQueue = DispatchQueue(label: device.uniqueID, attributes: [])
        captureDeviceInit()
    }
    
    deinit {
        print("CaptureDevice :: deinit :: DEINIT CAPTURE DEVICE")
    }
    
    func captureDeviceInit(){
        setupDevice()
        setupInput()
        setupVideoDataOutput()
        setupVideoConnection()
        setupAudioDataOutput()
        setupAudioConnection()
    }
    
    func setupPreviewLayer(session: AVCaptureSession) -> AVCaptureConnection {
        
        previewLayer = {
            let pl = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
            pl.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            pl.videoGravity = .resizeAspectFill
            return pl
        }()
        
        videoPreviewConnection = AVCaptureConnection(inputPort: videoPort!, videoPreviewLayer: previewLayer!)
        
        videoPreviewConnectionActive = true
        
        print("CaptureDevice :: setupPreviewLayer :: setupPreviewLayer")
        return videoPreviewConnection!
    }
    
    func setupDevice() {
        if let _ = device?.formats.first {
            do {
                try device?.lockForConfiguration()
                device?.activeFormat = (device?.formatWithHighestResolution((device?.formats)!))!
                device?.unlockForConfiguration()
                
            } catch {
                print("CaptureDevice :: setupDevice :: Unable to probe for activeFormat \(device.modelID): \(error)")
            }
        }
    }
    
    func setupInput(){
        do {
            input = try AVCaptureDeviceInput(device: device!)
            
            for port in (input?.ports)! {
                if port.mediaType == .audio {
                    audioPort = port
                }
                if port.mediaType == .video {
                    videoPort = port
                    print("CaptureDevice :: setupInput :: VideoPort should not be null \(port)")
                    
                    let observer:NSObjectProtocol = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureInputPortFormatDescriptionDidChange, object: videoPort, queue: nil) { [weak self] (notif) -> Void in
                        
                        if let description = self!.videoPort?.formatDescription {
                            print("CaptureDevice :: setupInput :: formatDescription \(description)")
                            let videoDimensions = CMVideoFormatDescriptionGetDimensions(description)
                            
                            self?.autoDetectProcess(width: Int32(videoDimensions.width), height: Int32(videoDimensions.height))
                            
                            self!.width = videoDimensions.width
                            self!.height = videoDimensions.height
                            
                            let mwidth = Double(videoDimensions.width)
                            let mheight = Double(videoDimensions.height)
                            
                            if videoDimensions.width > videoDimensions.height {
                                self!.orientation = .landscape
                            } else {
                                self!.orientation = .portrait
                            }
                            
                            self?.previewLayer?.frame = NSRect(x: 0, y: 0, width: mwidth, height: mheight)
                            
                            
                            self!.delegate?.devicePreviewLayer(previewLayer: self!.previewLayer, model: self!.device.modelID)
                            
                        } else {
                            print("CaptureDevice :: setupInput :: Unable to process the videoPort.formatDescription: \(String(describing: self!.videoPort))")
                        }
                    }
                    
                    observers.append(observer)
                }
            }
        } catch {
            print("CaptureDevice :: setupInput :: Capture Device Couldn't process input")
            print(error.localizedDescription)
        }
    }
    
    func setupVideoDataOutput(){
        
        let pixelFormat:PixelFormat = .rgb
        
        dataVideoOutput = {
            let dvo = AVCaptureVideoDataOutput()
            dvo.alwaysDiscardsLateVideoFrames = true
            dvo.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(pixelFormat.coreVideoType),
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            //dvo.setSampleBufferDelegate(nil, queue: captureDeviceQueue)// If using preview layer
            
            dvo.setSampleBufferDelegate(self, queue: captureDeviceQueue) // Rock on for metal
            return dvo
        }()
        
        print("CaptureDevice :: setupVideoDataOutput :: SampleBufferDelegate: \(String(describing: dataVideoOutput?.sampleBufferDelegate))")
        print("CaptureDevice :: setupVideoDataOutput :: captureDeviceQueue \(String(describing: captureDeviceQueue))")
    }
    
    func setupVideoConnection(){
        
        guard videoPort != nil else { return }
        
        print("CaptureDevice :: setupVideoConnection :: VideoPort: \(String(describing: videoPort)) dataVideoOutput: \(String(describing: dataVideoOutput))")
        videoConnection = AVCaptureConnection(inputPorts: [videoPort!], output: dataVideoOutput!)
        print("CaptureDevice :: setupVideoConnection ::  videoConnection: \(String(describing: videoConnection))")
        
    }
    
    func setupAudioDataOutput(){
        dataAudioOutput = {
            let dao = AVCaptureAudioDataOutput()
            dao.setSampleBufferDelegate(self, queue: captureDeviceQueue)
            return dao
        }()
    }
    
    func setupAudioConnection(){
        guard audioPort != nil else { return }
        //audioConnection = AVCaptureConnection(inputPorts: [audioPort!], output: dataAudioOutput!)
        audioPreview = AVCaptureAudioPreviewOutput()
        audioPreview?.volume = 1.0
        audioConnection = AVCaptureConnection(inputPorts: [audioPort!], output: audioPreview!)
        print("CaptureDevice :: setupAudioConnection :: audoConnection: \(String(describing: audioConnection))")
    }
    
}

extension CaptureDevice: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func sendPreviewLayer(){
        guard previewLayer != nil else { return }
        delegate?.devicePreviewLayer(previewLayer: previewLayer, model: self.device!.modelID)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        switch connection {
        case self.audioConnection:
            //print("CaptureDevice :: captureOutput :: Audio Buffer \(output)")
            //convertAudioData(sampleBuffer: sampleBuffer)
            break
        case self.videoConnection:
            //print("\(count) frames output \(self.device!)")
            count = count + 1
            //print("CaptureDevice :: captureOutput :: sampleBuffer: \(sampleBuffer)")
            delegate?.deviceVideoBuffer(model: self.device!.modelID, sampleBuffer: sampleBuffer, uniqueID: self.device!.uniqueID)
            break
        default:break
        }
    }
    
    func autoDetectProcess(width: Int32, height: Int32){
        
        if width != self.width || height != self.height {
            
            self.width = width
            self.height = height
            
            var aspectRatioTest:Double = 0.0
            if self.width > self.height {
                self.orientation = .landscape
                aspectRatioTest = Double(self.width) / Double(self.height)
            } else {
                self.orientation = .portrait
                aspectRatioTest = Double(self.height) / Double(self.width)
            }
            
            aspectRatioTest = aspectRatioTest * 100
            
            let ratios:[Int] = [133,143,150,177,216]
            
            var match:Int = 0
            
            print("CaptureDevice :: autoDetectProcess :: Trying to autodetect \(width) \(height) \(self.width) \(self.height) \(aspectRatioTest.rounded())" )
            
            for ratio in ratios {
                if match == 0 || abs(Int(aspectRatioTest.rounded()) - match) > abs(ratio - Int(aspectRatioTest.rounded())){
                    match = ratio
                }
            }
            
            switch match {
            case 133:
                deviceFamily = .iPad
                break
            case 143:
                deviceFamily = .iPadPro11
                break
            case 150:
                deviceFamily = .iPhoneLegacy
                break
            case 177:
                deviceFamily = .iPhoneLegacy
                break
            case 216:
                deviceFamily = .iPhoneXSeries
                break
            default:
                deviceFamily = .iPhoneLegacy
                break
            }
            print("CaptureDevice :: autoDetectProcess :: Autodetected Family: \(deviceFamily)")
        }
    }
    
    func prepareForRemoval(){
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = [NSObjectProtocol]()
        
        self.audioConnection = nil
        self.videoConnection = nil
        self.dataVideoOutput = nil
        self.dataAudioOutput = nil
        self.input = nil
        self.captureDeviceQueue = nil
        self.audioPort = nil
        self.videoPort = nil
        self.previewLayer = nil
        self.videoPreviewConnection = nil
        self.device = nil
    }
    
}

extension AVCaptureDevice {
    
    func availableFormatsFor(preferredFps: Float64) -> [AVCaptureDevice.Format] {
        var availableFormats: [AVCaptureDevice.Format] = []
        for format in formats
        {
            let ranges = format.videoSupportedFrameRateRanges
            for range in ranges where range.minFrameRate <= preferredFps && preferredFps <= range.maxFrameRate
            {
                availableFormats.append(format)
            }
        }
        
        return availableFormats
    }
    
    func formatWithHighestResolution(_ availableFormats: [AVCaptureDevice.Format]) -> AVCaptureDevice.Format?
    {
        var maxWidth: Int32 = 0
        var selectedFormat: AVCaptureDevice.Format?
        for format in availableFormats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let width = dimensions.width
            if width >= maxWidth {
                maxWidth = width
                selectedFormat = format
            }
        }
        
        return selectedFormat
    }
    
    private func formatFor(preferredSize: CGSize, availableFormats: [AVCaptureDevice.Format]) -> AVCaptureDevice.Format?
    {
        for format in availableFormats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            
            if dimensions.width >= Int32(preferredSize.width) && dimensions.height >= Int32(preferredSize.height)
            {
                return format
            }
        }
        
        return nil
    }
    
    func updateFormatWithPreferredVideoSpec(preferredSpec: VideoSpec)
    {
        let availableFormats: [AVCaptureDevice.Format]
        if let preferredFps = preferredSpec.fps {
            availableFormats = availableFormatsFor(preferredFps: Float64(preferredFps))
        } else {
            availableFormats = formats
        }
        
        var format: AVCaptureDevice.Format?
        if let preferredSize = preferredSpec.size {
            format = formatFor(preferredSize: preferredSize, availableFormats: availableFormats)
        } else {
            format = formatWithHighestResolution(availableFormats)
        }
        
        guard let selectedFormat = format else {return}
        print("selected format: \(selectedFormat)")
        do {
            try lockForConfiguration()
        } catch {
            fatalError("")
        }
        activeFormat = selectedFormat
        
        if let preferredFps = preferredSpec.fps {
            activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: preferredFps)
            activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: preferredFps)
            unlockForConfiguration()
        }
    }
}
