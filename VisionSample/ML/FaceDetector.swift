//
//  FaceDetector.swift
//  CoreMLTest
//
//  Created by Mohssen Fathi on 6/21/17.
//  Copyright © 2017 Mohssen Fathi. All rights reserved.
//

import Vision
import AVFoundation

struct FaceDetector: VisionBase {
    
    private static var shared = FaceDetector()
    
    static func landmarks(in sampleBuffer: CMSampleBuffer, completion: @escaping ([VNFaceObservation]) -> ()) {
         
        do {
            try shared.perform(request: VNDetectFaceLandmarksRequest { request, error in
                
                guard error == nil else {
                    completion([])
                    return
                }
                
                guard let results = request.results as? [VNFaceObservation] else {
                    completion([])
                    return
                }
                
                completion(results)
                
            }, with: sampleBuffer)
            
        }
        catch {
            completion([])
        }

    }
    
}
