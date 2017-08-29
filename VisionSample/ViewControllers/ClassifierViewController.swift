//
//  ClassifierViewController.swift
//  CoreMLTest
//
//  Created by Mohssen Fathi on 6/26/17.
//  Copyright © 2017 Mohssen Fathi. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ClassifierViewController: BaseVisionViewController {
    
    @IBOutlet var identifierLabels: [UILabel]!
    @IBOutlet var confidenceLabels: [UILabel]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        formatter.numberStyle = .percent
        camera.position = .back
    }
    
    override func didOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer) {
        super.didOutput(output, didOutput: sampleBuffer)
        
        Classifier.classify(sampleBuffer: sampleBuffer) { (results) in
            self.updateLabels(with: results)
        }
    }
    
    func updateLabels(with results: [(String, Float)]) {
        
        let max = 3
        for i in (0 ..< max).reversed() {
            if results.count > i {
                identifierLabels[i].text = results[i].0
                confidenceLabels[i].text = formatter.string(from: NSNumber(value: results[i].1))
            } else {
                identifierLabels[i].text = ""
                confidenceLabels[i].text = ""
            }
        }
    }
    
    private var formatter = NumberFormatter()
}
