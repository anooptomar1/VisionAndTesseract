//
//  ObjectTracker.swift
//  CoreMLTest
//
//  Created by Mohssen Fathi on 6/26/17.
//  Copyright © 2017 Mohssen Fathi. All rights reserved.
//

import AVFoundation
import Vision

struct ObjectTracker: VisionBase {
    
    private static var shared = Classifier()
    
    static func track(object: VNDetectedObjectObservation, in sampleBuffer: CMSampleBuffer, completion: @escaping ([VNDetectedObjectObservation]) -> ()) {
        
        let request = VNTrackObjectRequest(detectedObjectObservation: object) { (request, error) in
            
            guard error == nil,
                let results = request.results as? [VNDetectedObjectObservation] else {
                completion([])
                return
            }
            
            completion(results)
        }
        
        request.trackingLevel = .accurate
        
        do {
            try shared.perform(request: request, with: sampleBuffer, isSequence: true)
        }
        catch {
            completion([])
        }
        
    }
}

