//
//  Classifier.swift
//  CoreMLTest
//
//  Created by Mohssen Fathi on 6/20/17.
//  Copyright © 2017 Mohssen Fathi. All rights reserved.
//

import AVFoundation
import Vision

struct Classifier: VisionBase {
    
    private static var shared = Classifier()
    private var model: VNCoreMLModel?
    
    init() {
        model = try? VNCoreMLModel(for: Inceptionv3().model)
    }
    
    static func classify(sampleBuffer: CMSampleBuffer, completion: @escaping ([(String, Float)]) -> ()) {
        
        guard let model = shared.model else {
            completion([])
            return
        }
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard error == nil else {
                completion([])
                return
            }
            
            guard let observations = request.results as? [VNClassificationObservation] else {
                fatalError("unexpected result type from VNCoreMLRequest")
            }
            let results = observations[0 ... 10].filter({
                $0.confidence > 0.05
            }).map {
                return ($0.identifier, $0.confidence)
            }
            
            DispatchQueue.main.async {
                completion(results)
            }
            
        }
        
        request.imageCropAndScaleOption = .centerCrop

        do {
            try shared.perform(request: request, with: sampleBuffer)
        }
        catch {
            completion([])
        }
        
    }
    
}
