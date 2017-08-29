//
//  FaceLinesViewController.swift
//  CoreMLTest
//
//  Created by Mohssen Fathi on 6/26/17.
//  Copyright © 2017 Mohssen Fathi. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class FaceLinesViewController: BaseVisionViewController {
    
    override var annotationCount: Int { return 8 }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        camera.position = .front
    }
    
    override func didOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer) {
        super.didOutput(output, didOutput: sampleBuffer)
        
        FaceDetector.landmarks(in: sampleBuffer) { results in
            DispatchQueue.main.async {
                
                guard let observation = results.first, let landmarks = observation.landmarks else {
                    self.annotations.forEach { $0.path = nil }
                    return
                }
                
                self.drawFaceAnnotations(observation: observation, landmarks: landmarks)
            }
        }
    }

    func drawFaceAnnotations(observation: VNFaceObservation, landmarks: VNFaceLandmarks2D) {
        
        let boundingBox = CGRect(
            x: 1.0 - observation.boundingBox.origin.x - observation.boundingBox.size.width,
            y: 1.0 - observation.boundingBox.origin.y - observation.boundingBox.size.height,
            width: observation.boundingBox.width,
            height: observation.boundingBox.height
            ) * camera.previewLayer.frame
        
        annotationContainer.frame = boundingBox
        annotations.forEach { $0.frame = annotationContainer.bounds }
        
        let regions = [landmarks.leftEye, landmarks.rightEye, landmarks.outerLips,
                       landmarks.leftEyebrow, landmarks.rightEyebrow, landmarks.faceContour,
                       landmarks.nose, landmarks.noseCrest].flatMap { $0 }
        
        for(i, region) in regions.enumerated() {
            annotations[i].path = region.path(boundingBox: boundingBox, closePath: i < 3).cgPath
        }
    }
    
}
