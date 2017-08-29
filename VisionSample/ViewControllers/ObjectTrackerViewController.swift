//
//  ObjectTrackerViewController.swift
//  CoreMLTest
//
//  Created by Mohssen Fathi on 6/26/17.
//  Copyright © 2017 Mohssen Fathi. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ObjectTrackerViewController: BaseVisionViewController {
    
    override var annotationCount: Int { return 1 }
    @IBOutlet weak var trackView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        camera.position = .back
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        view.addGestureRecognizer(tapGestureRecognizer)

    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        
        let location = sender.location(in: sender.view)
        let width: CGFloat = 120.0
        
        let boundingBox = CGRect(x: location.x - width/2.0, y: location.y - width/2.0, width: width, height: width)
        annotations.first?.frame = camera.previewLayer.bounds
        annotations.first?.path = UIBezierPath(rect: boundingBox).cgPath
        
        var convertedBoundingBox = camera.previewLayer.metadataOutputRectConverted(fromLayerRect: boundingBox)
        convertedBoundingBox.origin.y = 1.0 - convertedBoundingBox.origin.y
        
        trackObservation = VNDetectedObjectObservation(boundingBox: convertedBoundingBox)
    }
    
    override func didOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer) {
        super.didOutput(output, didOutput: sampleBuffer)
        
        guard let object = trackObservation else { return }
        
        ObjectTracker.track(object: object, in: sampleBuffer, completion: { (results) in
            
            DispatchQueue.main.async {
                
                guard let newObservation = results.first, newObservation.confidence > 0.3 else {
                    self.annotations.first?.path = nil
                    return
                }
                
                self.trackObservation = newObservation
                
                self.annotations.first?.position = self.view.center
                self.annotations.first?.frame = self.view.bounds
                
                var boundingBox = newObservation.boundingBox
                boundingBox.origin.y = 1 - boundingBox.origin.y
                let convertedRect = self.camera.previewLayer.layerRectConverted(fromMetadataOutputRect: boundingBox)
                
                self.annotations.first?.path = UIBezierPath(rect: convertedRect).cgPath
            }
        })
    }
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var trackObservation: VNDetectedObjectObservation?
}
