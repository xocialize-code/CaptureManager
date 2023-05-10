//
//  PreviewView.swift
//  MVS Expo
//
//  Created by Dustin Nielson on 9/2/22.
//


#if os(iOS)
import UIKit
#else
import Cocoa
#endif
import AVFoundation

#if os(iOS)
final public class CapturePreviewView: UIView {

    
    override func draw(_ dirtyRect: NSRect) { super.draw(dirtyRect) }
    
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        layer?.masksToBounds = true
        layer?.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    }
    
    func initPreviewLayer(videoPreviewLayer: AVCaptureVideoPreviewLayer) {
        self.layer!.insertSublayer(videoPreviewLayer, at: 0)
        videoPreviewLayer.frame = self.frame
    }
    
    func removePreviewLayer() {
        self.layer?.sublayers?.removeAll()
    }
    
}
#else
public final class CapturePreviewView: NSView {

    
    public override func draw(_ dirtyRect: NSRect) { super.draw(dirtyRect) }
    
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        layer?.masksToBounds = true
        layer?.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    }
    
    func initPreviewLayer(videoPreviewLayer: AVCaptureVideoPreviewLayer) {
        self.layer!.insertSublayer(videoPreviewLayer, at: 0)
        videoPreviewLayer.frame = self.frame
    }
    
    func removePreviewLayer() {
        self.layer?.sublayers?.removeAll()
    }
    
}
#endif

