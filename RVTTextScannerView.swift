//
//  RVTTextScannerView.swift
//
//  Created by Adam Share on 9/30/15.
//  Copyright (c) 2015. All rights reserved.
//

import Foundation
import UIKit
import TesseractOCR
import GPUImage
import PureLayout
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


public protocol RVTTextScannerViewDelegate: class {
    
    func scannerDidRecognizeText(_ scanner: RVTTextScannerView, textResult: RVTTextResult, image: UIImage?)
    func scannerDidFindCommontextResult(_ scanner: RVTTextScannerView, textResult: RVTTextResult, image: UIImage?)
    func scannerDidStopScanning(_ scanner: RVTTextScannerView)
    func scannerOptimizationHint(_ scanner: RVTTextScannerView, hint: String!)
}

extension RVTTextScannerViewDelegate {
    
    func scannerDidStopScanning(_ scanner: RVTTextScannerView) {
        
    }
    
    func scannerDidFindCommontextResult(_ scanner: RVTTextScannerView, textResult: RVTTextResult, image: UIImage?) {
        
    }
    
    func scannerOptimizationHint(_ scanner: RVTTextScannerView, hint: String!) {
        
    }
}

open class RVTTextScannerView: UIView, G8TesseractDelegate {
    
    open class func scanImage(_ image: UIImage) -> RVTTextResult? {
        
        let tesseract:G8Tesseract = G8Tesseract(language: "eng")
        let image = image.g8_blackAndWhite()
        tesseract.image = image
        tesseract.recognize()
        let result = tesseract.recognizedText
        G8Tesseract.clearCache()
        
        if let text = result {
            return RVTTextResult(withText: text)
        }
        
        return nil
    }
    
    open var showCropView: Bool! = false {
        didSet {
            self.cropView?.removeFromSuperview()
            if self.showCropView == true {
                self.cropView = RVTScanCropView.addToScannerView(self)
                self.cropRect = self.cropView!.cropRect
            }
            else {
                self.cropRect = self.bounds
            }
        }
    }
    
    open var allowsHorizontalScanning = false
    open var cropView: RVTScanCropView?
    
    
    var gpuImageView: GPUImageView!
    
    open weak var delegate: RVTTextScannerViewDelegate?
    
    var timer: Timer?
    
    /// For capturing the video and passing it on to the filters.
    fileprivate let videoCamera: GPUImageVideoCamera = GPUImageVideoCamera(sessionPreset: AVCaptureSessionPreset1920x1080.rawValue, cameraPosition: .back)
    
    let ocrOperationQueue = OperationQueue()
    
    // Quick reference to the used filter configurations
    var exposure = GPUImageExposureFilter()
    var highlightShadow = GPUImageHighlightShadowFilter()
    var saturation = GPUImageSaturationFilter()
    var contrast = GPUImageContrastFilter()
    var crop = GPUImageCropFilter()
    
    var cropRect: CGRect = UIScreen.main.bounds {
        didSet {
            self.foundTextResults = [:]
        }
    }
    
    open var matchThreshold = 3
    var foundTextResults: [String: RVTTextResult] = [:]
    
    open var tesseract:G8Tesseract = G8Tesseract(language: "eng")
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
     
        self.setup()
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        self.setup()
    }
    
    func setup() {
        
        videoCamera.outputImageOrientation = .portrait;
        self.gpuImageView = GPUImageView(frame: self.frame)
        self.addSubview(gpuImageView)
        self.gpuImageView.autoCenterInSuperview()
        self.gpuImageView.autoPinEdge(toSuperviewEdge: .left)
        self.gpuImageView.autoPinEdge(toSuperviewEdge: .right)
        self.gpuImageView.autoMatch(.height, to: .width, of: self.gpuImageView, withMultiplier: 16/9)
        
        self.ocrOperationQueue.maxConcurrentOperationCount = 1
        
        // Filter settings
        highlightShadow.highlights = 0
        
        // Chaining the filters
        videoCamera.addTarget(exposure)
        exposure.addTarget(highlightShadow)
        highlightShadow.addTarget(saturation)
        saturation.addTarget(contrast)
        contrast.addTarget(self.gpuImageView)
        
        self.tesseract.delegate = self
    }
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if self.superview == nil {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        else {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
    }
    
    /**
     Starts a scan immediately
     */
    open func startScan() {
        
        self.videoCamera.startCapture()
        
        self.timer?.invalidate()
        self.timer = nil;
        self.timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(RVTTextScannerView.scan), userInfo: nil, repeats: false)
    }
    
    /**
     Stops a scan
     */
    open func stopScan() {
        
        self.videoCamera.stopCapture()
        timer?.invalidate()
        timer = nil
        self.delegate?.scannerDidStopScanning(self)
    }
    
    /**
     Perform a scan
     */
    open func scan() {

        OperationQueue.main.addOperation({ () -> Void in
            
            self.timer?.invalidate()
            self.timer = nil
            
            let startTime = Date()
            
            let currentFilterConfiguration = self.contrast
            currentFilterConfiguration.useNextFrameForImageCapture()
            currentFilterConfiguration.framebufferForOutput()?.disableReferenceCounting()
            let snapshot = currentFilterConfiguration.imageFromCurrentFramebuffer()
            
            if snapshot == nil {
                self.startScan()
                return
            }
            
            
            self.ocrOperationQueue.addOperation({[weak self] () -> Void in
                
                guard let weakSelf = self else {
                    return
                }
                
                var result:String?
                var image: UIImage?
                var component: RVTTextResult?
                var existingComponent: RVTTextResult?
                
                // Crop scan area
                
                var cropRect:CGRect! = weakSelf.cropRect
                cropRect.origin.y -= weakSelf.gpuImageView.frame.origin.y
                
                let fullImage = UIImage(cgImage: (snapshot?.cgImage!)!)
                
                let frameHeight = weakSelf.gpuImageView.frame.size.height;
                let snapShotHeight = fullImage.size.height;
                let ratio = snapShotHeight/frameHeight
                cropRect.origin.x *= ratio;
                cropRect.origin.y *= ratio;
                cropRect.size.width *= ratio;
                cropRect.size.height *= ratio;
                
                
                let imageRef:CGImage! = snapshot!.cgImage!.cropping(to: cropRect);
                image =   UIImage(cgImage: imageRef)
                
                if weakSelf.allowsHorizontalScanning {
                    
                    var rotate = false
                    let selectedFilter = GPUImageTransformFilter()
                    
                    let orientation = UIDevice.current.orientation
                    
                    switch orientation {
                    case .landscapeLeft:
                        selectedFilter.setInputRotation(kGPUImageRotateLeft, at: 0)
                        rotate = true
                        break
                    case .landscapeRight:
                        selectedFilter.setInputRotation(kGPUImageRotateRight, at: 0)
                        rotate = true
                        break
                    case .portrait:
                        break
                    default:
                        break
                    }
                    
                    if rotate {
                        image = selectedFilter.image(byFilteringImage: image)
                    }
                }
                
                image = image?.g8_blackAndWhite()
                weakSelf.tesseract.image = image
                weakSelf.tesseract.recognize()
                result = weakSelf.tesseract.recognizedText
                G8Tesseract.clearCache()
                weakSelf.cropView?.progress = 0
                
                if let text = result {
                    component = RVTTextResult(withText: text)
                    existingComponent = weakSelf.matchedPastComponentThreshold(component!)
                }
                
                OperationQueue.main.addOperation({ () -> Void in
                    
                    var hint = ""
                    if result?.characters.count == 0 {
                        weakSelf.cropView?.progressView.isHidden = true
                        hint = "Align text to top left corner"
                    }
                    else {
                        if (abs(startTime.timeIntervalSinceNow) > 1.5 && self?.cropView?.frame.size.height > 100) {
                            hint = "Hint: Resize the scanner to fit only the required text for faster results"
                        }
                    }
                    
                    weakSelf.cropView?.hintLabel.text = hint
                    if hint.characters.count > 0 {
                        self?.delegate?.scannerOptimizationHint(weakSelf, hint: hint)
                    }
                    
                    if component != nil {
                        weakSelf.delegate?.scannerDidRecognizeText(weakSelf, textResult: component!, image: image);
                    }
                    
                    if existingComponent != nil {
                        weakSelf.delegate?.scannerDidFindCommontextResult(weakSelf, textResult: existingComponent!, image: image)
                    }
                    
                    self?.startScan()
                })
                })
        })
    }
    
    func matchedPastComponentThreshold(_ textResult: RVTTextResult) -> RVTTextResult? {
        
        if textResult.text.characters.count == 0 {
            return nil
        }
        
        if textResult.key.characters.count <= 2 {
            return nil
        }
        
        if let pasttextResult = self.foundTextResults[textResult.key] {
            pasttextResult.matched += 1
            
            if pasttextResult.matched >= self.matchThreshold {
                self.foundTextResults = [:]
                return pasttextResult
            }
            
            return nil
        }
        
        self.foundTextResults[textResult.key] = textResult
        return nil
    }
    
    
    open func progressImageRecognition(for tesseract: G8Tesseract!) {
        
        self.cropView?.progress = tesseract.progress
    }
    
    var cancelCurrentScan: Bool = false
    
    open func shouldCancelImageRecognition(for tesseract: G8Tesseract!) -> Bool {
        
        if cancelCurrentScan {
            cancelCurrentScan = false
            return true
        }
        
        return cancelCurrentScan
    }
}


open class RVTTextResult {
    
    init (withText text: String) {
        self.text = text
    }
    
    var matched: Int = 0
    var text: String!
    
    var lines: [String] {
        var lines = self.text.components(separatedBy: CharacterSet.newlines)
        
        lines = lines.filter({ $0.characters.count != 0 })
        
        return lines
    }
    
    var key: String {
        
        if let firstText = self.lines.first {
//            let squashed = firstText.replacingOccurrences(of: "[ ]+", with: "", options: NSString.CompareOptions.regularExpression, range: firstText.characters.indices)
            let final = firstText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return final.lowercased()
        }
        
        return ""
    }
    
    var whiteSpacedComponents: [String] {
        
//        let squashed = self.text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "[ ]+", with: " ", options: NSString.CompareOptions.regularExpression, range: text.characters.indices)
        let final = self.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        return final.components(separatedBy: " ")
    }
    
}



open class RVTScanCropView: UIView {
    
    var showProgressView: Bool! = true {
        didSet {
            self.progressView.isHidden = !self.showProgressView
        }
    }
    
    var showHintLabel: Bool! = true {
        didSet {
            self.hintLabel.isHidden = !self.showHintLabel
        }
    }
    
    var progress: UInt! = 0 {
        didSet {
            OperationQueue.main.addOperation { () -> Void in
                
                if self.progress == 0 || self.progress == 100 {
                    self.progressView.isHidden = true
                }
                else {
                    self.progressView.isHidden = false
                    self.progressLeftLayoutConstraint.constant = CGFloat(self.progress)/100 * self.cropRect.width
                    self.layoutIfNeeded()
                }
            }
        }
    }
    
    open var edgeColor: UIColor! = UIColor.lightGray {
        didSet {
            self.cornerShapeLayer.strokeColor = self.edgeColor.cgColor;
            self.resizedView.layer.borderColor = self.edgeColor.withAlphaComponent(0.3).cgColor
        }
    }
    
    open var progressColor: UIColor! = UIColor.lightGray {
        didSet {
            self.progressView.backgroundColor = self.progressColor.withAlphaComponent(0.5)
        }
    }
    
    var cornerShapeLayer = CAShapeLayer()
    
    var cropRect: CGRect {
        
        return self.resizedView.frame
    }
    
    var progressView: UIView!
    var resizedView: UIView!
    var hintLabel: UILabel!
    
    var progressLeftLayoutConstraint: NSLayoutConstraint!
    
    var topConstraint: NSLayoutConstraint!
    var leftConstraint: NSLayoutConstraint!
    var bottomConstraint: NSLayoutConstraint!
    var rightConstraint: NSLayoutConstraint!
    
    class func addToScannerView(_ scannerView: RVTTextScannerView) -> RVTScanCropView {
        
        let containerView = RVTScanCropView(frame: scannerView.bounds)
        scannerView.addSubview(containerView)
        containerView.autoPinEdgesToSuperviewEdges()
        
        return containerView
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setupViews()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.setupViews()
    }
    
    func setupViews() {
        
        self.backgroundColor = UIColor.clear
        
        let cropView = UIView()
        self.resizedView = cropView
        self.addSubview(cropView)
        
        cropView.layer.borderColor = self.edgeColor.withAlphaComponent(0.5).cgColor
        cropView.layer.borderWidth = 1.0
        cropView.backgroundColor = UIColor.clear
        
        let cropConstraints = cropView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsetsMake(self.frame.size.height/3, 16, self.frame.size.height/3, 16))
        
        for layoutConstraint in cropConstraints {
            
            switch layoutConstraint.firstAttribute {
            case .leading, .leadingMargin, .left, .leftMargin:
                self.leftConstraint = layoutConstraint
                break
            case .topMargin, .top:
                self.topConstraint = layoutConstraint
                break
            case .right, .rightMargin, .trailing, .trailingMargin:
                self.rightConstraint = layoutConstraint
                break
            case .bottomMargin, .bottom, .lastBaseline, .firstBaseline:
                self.bottomConstraint = layoutConstraint
                break
            default:
                break
            }
        }
        
        let color = UIColor.black.withAlphaComponent(0.7)
        
        let topView = UIView()
        self.addSubview(topView)
        topView.backgroundColor = color
        
        topView.autoPinEdge(.left, to: .left, of: self)
        topView.autoPinEdge(.right, to: .right, of: self)
        topView.autoPinEdge(.top, to: .top, of: self)
        topView.autoPinEdge(.bottom, to: .top, of: cropView)
        
        
        let bottomView = UIView()
        self.addSubview(bottomView)
        bottomView.backgroundColor = color
        
        bottomView.autoPinEdge(.left, to: .left, of: self)
        bottomView.autoPinEdge(.right, to: .right, of: self)
        bottomView.autoPinEdge(.top, to: .bottom, of: cropView)
        bottomView.autoPinEdge(.bottom, to: .bottom, of: self)
        
        let leftView = UIView()
        self.addSubview(leftView)
        leftView.backgroundColor = color
        
        leftView.autoPinEdge(.left, to: .left, of: self)
        leftView.autoPinEdge(.right, to: .left, of: cropView)
        leftView.autoPinEdge(.top, to: .bottom, of: topView)
        leftView.autoPinEdge(.bottom, to: .top, of: bottomView)
        
        let rightView = UIView()
        self.addSubview(rightView)
        rightView.backgroundColor = color
        
        rightView.autoPinEdge(.left, to: .right, of: cropView)
        rightView.autoPinEdge(.right, to: .right, of: self)
        rightView.autoPinEdge(.top, to: .bottom, of: topView)
        rightView.autoPinEdge(.bottom, to: .top, of: bottomView)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(RVTScanCropView.didPan(_:)))
        self.addGestureRecognizer(panGesture)
        
        self.addCorners()
        
        self.bringSubview(toFront: cropView)
        
        progressView = UIView()
        cropView.addSubview(progressView)
        progressView.autoPinEdge(toSuperviewEdge: .top)
        progressView.autoPinEdge(toSuperviewEdge: .bottom)
        progressLeftLayoutConstraint = progressView.autoPinEdge(toSuperviewEdge: .left)
        progressView.autoSetDimension(.width, toSize: 3)
        progressView.backgroundColor = self.progressColor.withAlphaComponent(0.5)
        progressView.isHidden = true
        
        hintLabel = UILabel()
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        hintLabel.numberOfLines = 0
        hintLabel.textColor = UIColor.white
        hintLabel.text = "Align text to top left corner"
        hintLabel.font = UIFont.systemFont(ofSize: 20)
        hintLabel.textAlignment = .center
        hintLabel.adjustsFontSizeToFitWidth = true
        cropView.addSubview(hintLabel)
        hintLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        hintLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        hintLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 16, relation: .greaterThanOrEqual)
        hintLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 16, relation: .greaterThanOrEqual)
        hintLabel.autoCenterInSuperview()
        
        
    }
    
    var textScanView: RVTTextScannerView? {
        return self.superview as? RVTTextScannerView
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        if let scanView = self.textScanView {
            scanView.cropRect = self.cropRect
        }
        
        self.resizeCorners()
    }
    
    
    fileprivate var maxHeight: CGFloat {
        return self.frame.size.height
    }
    fileprivate var maxWidth: CGFloat {
        return self.frame.size.width
    }
    
    fileprivate let minHeight: CGFloat = 60
    fileprivate let minWidth: CGFloat = 60
    
    fileprivate enum PanEdge {
        case center, left, right, top, bottom, topLeftCorner, topRightCorner, bottomLeftCorner, bottomRightCorner, outside
    }
    
    fileprivate func startEdgeForView(_ view: UIView, point: CGPoint) -> PanEdge {
        
        let topLeft = CGPoint.zero
        let topRight = CGPoint(x: view.frame.size.width, y: 0)
        let bottomLeft = CGPoint(x: 0, y: view.frame.size.height)
        let bottomRight = CGPoint(x: view.frame.size.width, y: view.frame.size.height)
        
        let threshold: CGFloat = 20
        
        if topLeft.distanceToPoint(point) < threshold*2 {
            return .topLeftCorner
        }
        
        if topRight.distanceToPoint(point) < threshold*2 {
            return .topRightCorner
        }
        
        if bottomLeft.distanceToPoint(point) < threshold*2 {
            return .bottomLeftCorner
        }
        
        if bottomRight.distanceToPoint(point) < threshold*2 {
            return .bottomRightCorner
        }
        
        if fabs(point.y) < threshold {
            return .top
        }
        
        if fabs(point.x) < threshold {
            return .left
        }
        
        if fabs(point.x - bottomRight.x) < threshold {
            return .right
        }
        
        if fabs(point.y - bottomRight.y) < threshold {
            return .bottom
        }
        
        if (point.x < bottomRight.x && point.x > 0 && point.y < bottomRight.y && point.y > 0) {
            return .center
        }
        
        return .outside
    }
    
    fileprivate var startEdge: PanEdge = .center
    fileprivate var startPoint: CGPoint = CGPoint.zero
    
    func didPan(_ gesture: UIPanGestureRecognizer) {
        
        let translation = gesture.translation(in: self.resizedView)
        let location = gesture.location(in: self.resizedView)
        
        var currentPosition = self.startPoint
        currentPosition.x += translation.x
        currentPosition.y += translation.y
        
        switch (gesture.state) {
        case .began:
            self.resetStartingConstraint()
            self.startPoint = translation
            self.startEdge = self.startEdgeForView(self.resizedView, point: location)
            break
        case .changed:
            
            self.moveEdge(self.startEdge, translation: translation)
            self.textScanView?.cancelCurrentScan = true
            
            break
        case .cancelled:
            self.textScanView?.cancelCurrentScan = true
            break
        case .ended:
            self.textScanView?.cancelCurrentScan = true
            break
        default:
            break
        }
    }
    
    fileprivate var topStart: CGFloat = 0
    fileprivate var bottomStart: CGFloat = 0
    fileprivate var rightStart: CGFloat = 0
    fileprivate var leftStart: CGFloat = 0
    
    fileprivate func resetStartingConstraint() {
        self.topStart = self.topConstraint.constant
        self.bottomStart = self.bottomConstraint.constant
        self.rightStart = self.rightConstraint.constant
        self.leftStart = self.leftConstraint.constant
    }
    
    fileprivate func moveEdge(_ edge:PanEdge, translation:CGPoint) {
        
        var nextTop = self.topStart+translation.y
        var nextLeft = self.leftStart+translation.x
        
        if nextTop < 0 {
            nextTop = 0
        }
        
        if nextLeft < 0 {
            nextLeft = 0
        }
        
        //negative
        var nextBottom = self.bottomStart+translation.y
        var nextRight = self.rightStart+translation.x
        
        
        if nextBottom > 0 {
            nextBottom = 0
        }
        
        if nextRight > 0 {
            nextRight = 0
        }
        
        let shouldMoveTop = self.frame.size.height - fabs(nextTop) - fabs(self.bottomConstraint.constant) >= self.minHeight
        let shouldMoveBottom = self.frame.size.height - fabs(nextBottom) - fabs(self.topConstraint.constant) >= self.minHeight
        let shouldMoveLeft = self.frame.size.width - fabs(nextLeft) - fabs(self.rightConstraint.constant) >= self.minWidth
        let shouldMoveRight = self.frame.size.width - fabs(nextRight) - fabs(self.leftConstraint.constant) >= self.minWidth
        
        switch edge {
        case .top:
            if shouldMoveTop {
                self.topConstraint.constant = nextTop
            }
            
            break
        case .bottom:
            if shouldMoveBottom {
                self.bottomConstraint.constant = nextBottom
            }
            
            break
        case .left:
            if shouldMoveLeft {
                self.leftConstraint.constant = nextLeft
            }
            
            break
        case .right:
            if shouldMoveRight {
                self.rightConstraint.constant = nextRight
            }
            
            break
        case .topLeftCorner:
            
            if shouldMoveTop {
                self.topConstraint.constant = nextTop
            }
            
            if shouldMoveLeft {
                self.leftConstraint.constant = nextLeft
            }
            
            break
        case .topRightCorner:
            
            if shouldMoveTop {
                self.topConstraint.constant = nextTop
            }
            
            if shouldMoveRight {
                self.rightConstraint.constant = nextRight
            }
            break
        case .bottomLeftCorner:
            
            if shouldMoveBottom {
                self.bottomConstraint.constant = nextBottom
            }
            
            if shouldMoveLeft {
                self.leftConstraint.constant = nextLeft
            }
            break
        case .bottomRightCorner:
            
            if shouldMoveBottom {
                self.bottomConstraint.constant = nextBottom
            }
            
            if shouldMoveRight {
                self.rightConstraint.constant = nextRight
            }
            
            break
        case .center:
            if self.frame.size.height - nextBottom - self.topConstraint.constant >= self.minHeight {
                self.bottomConstraint.constant = nextBottom
            }
            
            if self.frame.size.width - nextRight - self.leftConstraint.constant >= self.minWidth {
                self.rightConstraint.constant = nextRight
            }
            
            if self.frame.size.height - nextTop - self.bottomConstraint.constant >= self.minHeight {
                self.topConstraint.constant = nextTop
            }
            
            if self.frame.size.width - nextLeft - self.rightConstraint.constant >= self.minWidth {
                self.leftConstraint.constant = nextLeft
            }
            break
        case .outside:
            break
        }
        
        self.layoutIfNeeded()
    }
    
    fileprivate func addCorners() {
        
        let shapeLayer = self.cornerShapeLayer;
        shapeLayer.fillColor = UIColor.clear.cgColor;
        shapeLayer.strokeColor = self.edgeColor.cgColor;
        shapeLayer.lineWidth = 5.0;
        shapeLayer.fillRule = kCAFillRuleNonZero;
        
        self.resizedView.layer.addSublayer(shapeLayer)
        
        self.resizeCorners()
    }
    
    fileprivate func resizeCorners() {
        let segmentLength: CGFloat = self.minHeight/3;
        
        let width = self.resizedView.frame.size.width
        let height = self.resizedView.frame.size.height
        let x: CGFloat = 0
        let y: CGFloat = 0
        
        let path = CGMutablePath();
//        CGPathMoveToPoint(path, nil, segmentLength, y);
//        CGPathAddLineToPoint(path, nil, x, y);
//        CGPathAddLineToPoint(path, nil, x, segmentLength);
//
//        CGPathMoveToPoint(path, nil, width-segmentLength, y);
//        CGPathAddLineToPoint(path, nil, width, y);
//        CGPathAddLineToPoint(path, nil, width, segmentLength);
//
//        CGPathMoveToPoint(path, nil, width-segmentLength, height);
//        CGPathAddLineToPoint(path, nil, width, height);
//        CGPathAddLineToPoint(path, nil, width, height - segmentLength);
//
//        CGPathMoveToPoint(path, nil, segmentLength, height);
//        CGPathAddLineToPoint(path, nil, x, height);
//        CGPathAddLineToPoint(path, nil, x, height - segmentLength);
        
        self.cornerShapeLayer.path = path
        self.cornerShapeLayer.frame = self.resizedView.bounds;
    }
}



extension UILabel {
    
    public func resizeFontToFit() {
        
        let maxFontSize: CGFloat = 25
        let minFontSize: CGFloat = 5
        
        self.font = UIFont(name: self.font!.fontName, size: self.binarySearchForFontSize(maxFontSize, minFontSize: minFontSize))
    }
    
    func binarySearchForFontSize(_ maxFontSize: CGFloat, minFontSize: CGFloat) -> CGFloat {
        
        // Find the middle
        let fontSize = (minFontSize + maxFontSize) / 2;
        // Create the font
        let font = UIFont(name:self.font.fontName, size:fontSize)
        // Create a constraint size with max height
        let constraintSize = CGSize(width: self.frame.size.width, height: CGFloat.greatestFiniteMagnitude);
        
        // Find label size for current font size
        let labelSize = self.text!.boundingRect(with: constraintSize, options:NSStringDrawingOptions.usesLineFragmentOrigin, attributes:[NSFontAttributeName : font!], context:nil).size
        
        if (fontSize > maxFontSize) {
            return maxFontSize
        } else if fontSize < minFontSize {
            return minFontSize
        } else if (labelSize.height > self.frame.size.height || labelSize.width > self.frame.size.width) {
            return self.binarySearchForFontSize(maxFontSize-1, minFontSize: minFontSize)
        } else {
            return self.binarySearchForFontSize(maxFontSize, minFontSize: fontSize+1)
        }
    }
}

extension CGPoint {
    
    public func distanceToPoint(_ point: CGPoint) -> CGFloat {
        
        return CGFloat(hypotf(Float(self.x - point.x), Float(self.y - point.y)))
    }
}


extension UIImage {
    
    public func imageWithSize(_ newSize: CGSize, contentMode: UIViewContentMode = UIViewContentMode.scaleAspectFit) -> UIImage {
        var newSize = newSize
        
        let imgRef = self.cgImage;
        // the below values are regardless of orientation : for UIImages from Camera, width>height (landscape)
        let  originalSize = CGSize(width: CGFloat(imgRef!.width), height: CGFloat(imgRef!.height)); // not equivalent to self.size (which is dependant on the imageOrientation)!
        
        var boundingSize = newSize
        
        // adjust boundingSize to make it independant on imageOrientation too for farther computations
        let  imageOrientation = self.imageOrientation;
        
        switch (imageOrientation) {
        case .left, .right, .rightMirrored, .leftMirrored:
            boundingSize = CGSize(width: boundingSize.height, height: boundingSize.width);
            break
        default:
            // NOP
            break;
        }
        
        let wRatio = boundingSize.width / originalSize.width;
        let hRatio = boundingSize.height / originalSize.height;
        
        switch contentMode {
            
        case .scaleAspectFit:
            
            if (wRatio < hRatio) {
                newSize = CGSize(width: boundingSize.width, height: floor(originalSize.height * wRatio))
            } else {
                newSize = CGSize(width: floor(originalSize.width * hRatio), height: boundingSize.height);
            }
            
        case .scaleAspectFill:
            
            if (wRatio > hRatio) {
                newSize = CGSize(width: boundingSize.width, height: floor(originalSize.height * wRatio))
            } else {
                newSize = CGSize(width: floor(originalSize.width * hRatio), height: boundingSize.height);
            }
            
        default:
            break
        }
        
        /* Don't resize if we already meet the required destination size. */
        if originalSize.equalTo(newSize) {
            return self;
        }
        
        let scaleRatioWidth = newSize.width / originalSize.width
        let scaleRatioHeight = newSize.height / originalSize.height
        
        var transform = CGAffineTransform.identity;
        
        switch(imageOrientation) {
            
        case .up: //EXIF = 1
            transform = CGAffineTransform.identity;
            break;
            
        case .upMirrored: //EXIF = 2
            transform = CGAffineTransform(translationX: originalSize.width, y: 0.0);
            transform = transform.scaledBy(x: -1.0, y: 1.0);
            break;
            
        case .down: //EXIF = 3
            transform = CGAffineTransform(translationX: originalSize.width, y: originalSize.height);
            transform = transform.rotated(by: CGFloat(M_PI));
            break;
            
        case . downMirrored: //EXIF = 4
            transform = CGAffineTransform(translationX: 0.0, y: originalSize.height);
            transform = transform.scaledBy(x: 1.0, y: -1.0);
            break;
            
        case . leftMirrored: //EXIF = 5
            newSize = CGSize(width: newSize.height, height: newSize.width);
            transform = CGAffineTransform(translationX: originalSize.height, y: originalSize.width);
            transform = transform.scaledBy(x: -1.0, y: 1.0);
            transform = transform.rotated(by: 3.0 * CGFloat(M_PI_2));
            break;
            
        case . left: //EXIF = 6
            newSize = CGSize(width: newSize.height, height: newSize.width);
            transform = CGAffineTransform(translationX: 0.0, y: originalSize.width);
            transform = transform.rotated(by: 3.0 * CGFloat(M_PI_2));
            break;
            
        case .rightMirrored: //EXIF = 7
            newSize = CGSize(width: newSize.height, height: newSize.width);
            transform = CGAffineTransform(scaleX: -1.0, y: 1.0);
            transform = transform.rotated(by: CGFloat(M_PI_2));
            break;
            
        case . right: //EXIF = 8
            newSize = CGSize(width: newSize.height, height: newSize.width);
            transform = CGAffineTransform(translationX: originalSize.height, y: 0.0);
            transform = transform.rotated(by: CGFloat(M_PI_2));
            break;
        }
        
        /////////////////////////////////////////////////////////////////////////////
        // The actual resize: draw the image on a new context, applying a transform matrix
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale);
        
        let context = UIGraphicsGetCurrentContext();
        
        if (imageOrientation == . right || imageOrientation == . left) {
            context!.scaleBy(x: -scaleRatioWidth, y: scaleRatioHeight);
            context!.translateBy(x: -originalSize.height, y: 0);
        } else {
            context!.scaleBy(x: scaleRatioWidth, y: -scaleRatioHeight);
            context!.translateBy(x: 0, y: -originalSize.height);
        }
        
        context!.concatenate(transform);
        
        // we use originalSize (and not newSize) as the size to specify is in user space (and we use the CTM to apply a scaleRatio)
        UIGraphicsGetCurrentContext()!.draw(imgRef!, in: CGRect(x: 0, y: 0, width: originalSize.width, height: originalSize.height));
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return resizedImage!;
    }
}
