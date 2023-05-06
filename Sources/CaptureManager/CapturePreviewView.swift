//
//  PreviewView.swift
//  MVS Expo
//
//  Created by Dustin Nielson on 9/2/22.
//

import Cocoa
import AVFoundation

class CapturePreviewView: NSView {
    
    
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
