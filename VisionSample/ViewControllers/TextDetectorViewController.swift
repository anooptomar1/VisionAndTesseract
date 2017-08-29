//
//  TextDetectorViewController.swift
//  VisionSample
//
//  Created by Mohssen Fathi on 6/27/17.
//  Copyright © 2017 mohssenfathi. All rights reserved.
//

import UIKit
import Vision
import AVFoundation
import TesseractOCR

class TextDetectorViewController: BaseVisionViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        camera.position = .back
    }
    
    func scanImage(_ image: UIImage) -> String? {
        let tesseract:G8Tesseract = G8Tesseract(language: "eng")
        let image = image.g8_blackAndWhite()
        tesseract.image = image
        tesseract.recognize()
        let result = tesseract.recognizedText
        G8Tesseract.clearCache()
        
        if let text = result {
            return text
        }
        
        return nil
    }
    
    func convert(cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    func highlightWord(box: VNTextObservation) -> CGRect {
        guard let _ = box.characterBoxes else {
            return CGRect()
        }
        
        let dim = box.boundingBox
        
        let size = self.camera.previewLayer.frame
        let width = dim.width * size.width
        let height = dim.height * size.height
        let x = dim.origin.x * size.width
        let y = (1 - dim.origin.y) * size.height - height
        
        let layerFrame = CGRect(x: x, y: y, width: width, height: height)
        let visibleFrame = self.view.convert(layerFrame, to: self.view)
        return layerFrame
        
//        if self.view.frame.contains(visibleFrame) {
//            let outlineb = CALayer()
//            outlineb.frame = layerFrame
//            outlineb.borderWidth = 2.0
//            outlineb.borderColor = UIColor.red.cgColor
//
//            self.vwCamera.layer.addSublayer(outlineb)
//
//            self.currentSentenceFrames.append(layerFrame)
//        }
    }
    
    func cropImage(imageToCrop:UIImage, toRect rect:CGRect) -> UIImage{
        
        let imageRef:CGImage = imageToCrop.cgImage!.cropping(to: rect)!
        let cropped:UIImage = UIImage(cgImage:imageRef)
        return cropped
    }

    override func didOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer) {
        super.didOutput(output, didOutput: sampleBuffer)
        
        TextDetector.detectText(in: sampleBuffer) { results in
            DispatchQueue.main.async {
                guard results.count > 3 else {
                    return
                }

//                if results.count > 0 {
//                    debugPrint("results.count: \(results.count)")
//                }
                
//                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 0)!, options: options)

                
                let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
                let ciimage: CIImage = CIImage(cvPixelBuffer: imageBuffer)
                let image: UIImage = self.convert(cmage: ciimage)
                let cgImage: CGImage = image.cgImage!
//                let imageRect = self.camera.previewLayer.frame
                let imageRect:CGRect = CGRect(origin: CGPoint(), size: image.size)

//                if let observe: VNTextObservation = results.first {
//                }


                
                if let observe: VNTextObservation = results[1] {
//                for observe:VNTextObservation in results {
//                    guard observe.confidence >= 0.7 else {
//                        continue
//                    }

                    // calculate view rect
                    var transformedRect = observe.boundingBox
                    transformedRect.origin.y = 1 - transformedRect.origin.y
                    let convertedRect = self.camera.previewLayer.layerRectConverted(fromMetadataOutputRect: transformedRect)
                    debugPrint("observe.boundingBox:\(String(describing: observe.boundingBox))")
                    debugPrint("convertedRect:\(String(describing: convertedRect))")

                    
                    let wordRect = self.highlightWord(box: observe)
                    debugPrint("wordRect:\(String(describing: wordRect))")

//                    let boundingBox: CGRect = observe.boundingBox
//                    let w = boundingBox.size.width * imageRect.width
//                    let h = boundingBox.size.height * imageRect.height
//                    let x = boundingBox.origin.x * imageRect.width + imageRect.origin.x
//                    let y = imageRect.maxY - (boundingBox.origin.y * imageRect.height) - h
//
//
//                    let relativeBox: CGRect = CGRect(x: x, y: y, width: h, height: w)
//                    debugPrint("relativeBox:\(String(describing: relativeBox))")
//                    debugPrint("observe.boundingBox:\(String(describing: observe.boundingBox))")
                    
//                    let imageRef: CGImage = cgImage.cropping(to: wordRect)!;
                    let imageUI = UIImage(cgImage: cgImage)
                    let croppedImage = self.cropImage(imageToCrop: imageUI, toRect:convertedRect)
                    let croppedWord = self.cropImage(imageToCrop: imageUI, toRect:wordRect)

                    if let text = self.scanImage(croppedImage) {
                        if text.count > 0 {
                            debugPrint(imageUI)
                            debugPrint("text:\(String(describing: text))")
                        }
                    }
                    
                    if let text = self.scanImage(croppedWord) {
                        if text.count > 0 {
                            debugPrint(imageUI)
                            debugPrint("text:\(String(describing: text))")
                        }
                    }

                }
                
                let paths = results.map { observation -> UIBezierPath in
                    
                    let imageRect = self.camera.previewLayer.frame
                    let w = observation.boundingBox.size.width * imageRect.width
                    let h = observation.boundingBox.size.height * imageRect.height
                    let x = observation.boundingBox.origin.x * imageRect.width + imageRect.origin.x
                    let y = imageRect.maxY - (observation.boundingBox.origin.y * imageRect.height) - h
                    
                    return UIBezierPath(rect: CGRect(x: x, y: y, width: w, height: h))
                }
                
                self.updateAnnotations(with: paths)
            }
        }
    }
    
}
