//
//  CaptureScreen.swift
//  Demostration
//
//  Created by Dustin Nielson on 12/31/24.
//

import Foundation

import Cocoa
import ScreenCaptureKit
import AVFoundation
import AVFAudio
import Combine
import OSLog

struct CapturedFrame: @unchecked Sendable {
    static var invalid: CapturedFrame {
        CapturedFrame(surface: nil, contentRect: .zero, contentScale: 0, scaleFactor: 0)
    }
    let surface: IOSurface?
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat
    var size: CGSize { contentRect.size }
}

protocol CaptureScreenDelegate: AnyObject {
    
    func ScreenRecordBuffer(sampleBuffer: CMSampleBuffer)
}

class CaptureScreen: NSObject {
    
    private let logger = Logger()
    
    weak var delegate: CaptureScreenDelegate?
    
    var availableDisplays = [SCDisplay]()
    var selectedDisplay: SCDisplay?
    
    private let videoSampleBufferQueue = DispatchQueue(label: "com.mvstaging.VideoSampleBufferQueue")
    
    // Store the the startCapture continuation, so that you can cancel it when you call stopCapture().
    private var continuation: AsyncThrowingStream<CapturedFrame, Error>.Continuation?
    
    var filter:SCContentFilter!
    var streamConfig:SCStreamConfiguration!
    var stream:SCStream!
    
    convenience init(delegate: CaptureScreenDelegate) {
        self.init()
        self.delegate = delegate
//        AVCaptureDevice.requestAccess(for: .video) { granted in
//            if granted {
//                print("Camera permission granted")
//                self.initScreenRecording()
//            } else {
//                print("Camera permission denied")
//            }
//        }
        
        print("ScreenCapture :: Init")
    }
    
    func initScreenRecording()  {
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                
                availableDisplays = content.displays
                
                let excludedApps = content.applications.filter { app in
                    Bundle.main.bundleIdentifier == app.bundleIdentifier //Skip ourself
                }
                
                if selectedDisplay == nil {
                    selectedDisplay = availableDisplays.first
                }
                
                guard let display = selectedDisplay else { fatalError("No display selected.") }
                
                print(display)
                
                filter = SCContentFilter(display: display,
                                         excludingApplications: excludedApps,
                                         exceptingWindows: [])
                
                // Creating a SCStreamConfiguration object
                streamConfig = SCStreamConfiguration()
                        
                // Set output resolution to 1080p
                streamConfig.width = 1920
                streamConfig.height = 1080
                streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
                // Set the capture interval at 60 fps
                streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(60))

                // Hides cursor
                streamConfig.showsCursor = true

                // Enable audio capture
                streamConfig.capturesAudio = false

                // Set sample rate to 48000 kHz stereo
                streamConfig.sampleRate = 48000
                streamConfig.channelCount = 2
                
                // Create a capture stream with the filter and stream configuration
                stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
                
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
               // try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioFrameOutputQueue)

                // Start the capture session
                try await stream.startCapture()
                
                print("Capture started.")
                
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func handleLatestScreenSample(_ sampleBuffer: CMSampleBuffer) {
       // print(sampleBuffer)
        delegate?.ScreenRecordBuffer(sampleBuffer: sampleBuffer)
    }
    
    func handleLatestAudioSample(_ sampleBuffer: CMSampleBuffer) {
        print("AB")
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        switch type {
        case .screen:
            handleLatestScreenSample(sampleBuffer)
//        casa.audio:         handleLatestAudioSample(sampleBuffer)
            default : break
        }
    }

    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.logger.error("Stream stopped with error: \(error.localizedDescription)")
       }
    }
}

extension CaptureScreen: SCStreamDelegate {}

extension CaptureScreen: SCStreamOutput {}
