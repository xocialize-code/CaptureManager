//
//  File.swift
//  
//
//  Created by Dustin Nielson on 5/6/23.
//

import Cocoa
import AVFoundation

@available(macOS 10.15, iOS 16.0, *)
extension CaptureManager {
    
    func enableObservers(){
        
        observers.append(
            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureSessionDidStartRunning, object: nil, queue: nil) { (notif) in
                print("AppManagerObservers :: enableObservers :: AVCaptureSessionDidStartRunning \(notif)")
                self.refreshDevices()
            }
        )
        
        observers.append(
            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureSessionDidStopRunning, object: nil, queue: nil) { (notif) in
                print("AppManagerObservers :: enableObservers :: AVCaptureSessionDidStopRunning \(notif)")
                
            }
        )
        
        observers.append(
            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasDisconnected, object: nil, queue: OperationQueue.main) { (notif) -> Void in
                
                if let device = notif.object as? AVCaptureDevice {
                    self.deviceLost(device: device)
                }
            }
        )
        
        observers.append(
            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil, queue: OperationQueue.main) { (notif) -> Void in
                
                if let device = notif.object as? AVCaptureDevice {
                    self.deviceFound(device: device)
                }
            }
        )
        print("AVCaptureSessionDidStopRunning :: enableObservers :: ENABLED")
    }
    
    func disableObservers(){
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = [NSObjectProtocol]()
    }
}
