//
//  FaceMaskViewController.swift
//  CoreMLTest
//
//  Created by Mohssen Fathi on 6/26/17.
//  Copyright © 2017 Mohssen Fathi. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import SceneKit

class FaceMaskViewController: BaseVisionViewController {
    
    override var annotationCount: Int { return 0 }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        camera.position = .front
        setupScene()
    }
    
    override func didOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer) {
        super.didOutput(output, didOutput: sampleBuffer)
        
        FaceDetector.landmarks(in: sampleBuffer) { results in
            DispatchQueue.main.async {
                guard let observation = results.first, let landmarks = observation.landmarks else {
                    self.mask.isHidden = true
                    return
                }
                self.updateMask(observation: observation, landmarks: landmarks)
            }
        }
    }
    
    
    func setupScene() {
        
        let sceneContainer = UIView(frame: view.bounds)
        sceneContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneContainer.backgroundColor = .clear
        view.insertSubview(sceneContainer, at: 1)
        
        let sceneView = SCNView()
        sceneView.frame = sceneContainer.bounds
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = .clear
        sceneContainer.addSubview(sceneView)
        
        let scene = SCNScene(named: "art.scnassets/IronMan.scn")!
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true
        sceneView.scene = scene
        
        mask = scene.rootNode
        mask.isHidden = true
    }
    
    private var mask: SCNNode!
}

// MARK: - FaceDetection
extension FaceMaskViewController {
    
    func updateMask(observation: VNFaceObservation, landmarks: VNFaceLandmarks2D) {
        
        mask.isHidden = false
        
        let boundingBox = CGRect(
            x: 1.0 - observation.boundingBox.origin.x - observation.boundingBox.size.width,
            y: 1.0 - observation.boundingBox.origin.y - observation.boundingBox.size.height,
            width: observation.boundingBox.width,
            height: observation.boundingBox.height
            ) * camera.previewLayer.frame
        
        let newPosition = SCNVector3Make(Float(boundingBox.center.x - camera.previewLayer.frame.width/2.0),
                                         Float(camera.previewLayer.frame.height/2.0 - boundingBox.center.y) + 40, -10)
        mask.position = newPosition
        
//        if let leftEye = landmarks.leftEye?.normalizedPoints.first?.point,
//            let rightEye = landmarks.rightEye?.normalizedPoints.first?.point {
//
//            let le = leftEye * boundingBox.size
//            let re = rightEye * boundingBox.size
//
//            let dx = abs(re.x - le.x)
//            let dy = abs(re.y - le.y)
//
//            let angle = atan(dy/dx) * (re.y > le.y ? -1 : 1)
//
//            mask.eulerAngles = SCNVector3Make(mask.eulerAngles.x, mask.eulerAngles.y, Float(angle))
//        }
        
        let scaleMultiplier: Float = 1.65
//        if let facePoints = landmarks.faceContour?.normalizedPoints,
//            let first = facePoints.first?.point,
//            let last = facePoints.last?.point {
//
//            let dx = abs((first * boundingBox.size).x - (last * boundingBox.size).x)
//            let scale = Float(dx/camera.previewLayer.frame.width) * scaleMultiplier
//
//            mask.scale = SCNVector3Make(scale, scale, 1)
//        }
        
        //        if let nosePoints = landmarks.noseCrest?.points,
        //            let first = nosePoints.first?.point,
        //            let last = nosePoints.last?.point {
        //
        //            let dy = abs((first * boundingBox.size).y - (last * boundingBox.size).y)
        //            let percentage = 0.15 - dy/boundingBox.height
        //            let angle = Float.pi * Float(-percentage)
        //            mask.eulerAngles = SCNVector3Make(angle, mask.eulerAngles.y, mask.eulerAngles.z)
        //        }
    }
}
