//
//  CaptureManager.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation
import CoreMotion
import AVFoundation
import UIKit

func benchmark(operationTitle: String? = nil, operation: () -> Void) {
  let startTime = CFAbsoluteTimeGetCurrent()
  operation()
  let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
  print("Time elapsed for \(operationTitle ?? "unknown"): \(timeElapsed) s.")
}

/// A set of functions that inform the delegate object of the state of the detection.
public protocol RectangleDetectionDelegateProtocol: NSObjectProtocol {
  /// Called when the capture of a picture has started.
  ///
  /// - Parameters:
  ///   - captureSessionManager: The `CaptureSessionManager` instance that started capturing a picture.
  func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager)

  /// Called when a quadrilateral has been detected.
  /// - Parameters:
  ///   - captureSessionManager: The `CaptureSessionManager` instance that has detected a quadrilateral.
  ///   - quad: The detected quadrilateral in the coordinates of the image.
  ///   - imageSize: The size of the image the quadrilateral has been detected on.
  func captureSessionManager(
    _ captureSessionManager: CaptureSessionManager,
    didDetectQuad quad: Quadrilateral?,
    _ imageSize: CGSize
  )

  /// Called when a picture with or without a quadrilateral has been captured.
  ///
  /// - Parameters:
  ///   - captureSessionManager: The `CaptureSessionManager` instance that has captured a picture.
  ///   - picture: The picture that has been captured.
  ///   - quad: The quadrilateral that was detected in the picture's coordinates if any.
  func captureSessionManager(
    _ captureSessionManager: CaptureSessionManager,
    didCapturePicture picture: UIImage,
    withQuad quad: Quadrilateral?
  )

  /// Called when an error occured with the capture session manager.
  /// - Parameters:
  ///   - captureSessionManager: The `CaptureSessionManager` that encountered an error.
  ///   - error: The encountered error.
  func captureSessionManager(
    _ captureSessionManager: CaptureSessionManager,
    didFailWithError error: Error
  )

  func captureSessionManager(
    _ captureSessionManager: CaptureSessionManager,
    didReceiveImage image: CIImage
  )
  
  func captureSessionManager(
    _ captureSessionManager: CaptureSessionManager,
    didCaptureQRCodeTextData textData: String
  )
}

public extension RectangleDetectionDelegateProtocol {
  func captureSessionManager(
    _ captureSessionManager: CaptureSessionManager,
    didReceiveImage image: CIImage
  ) {}
  
  func captureSessionManager(
    _ captureSessionManager: CaptureSessionManager,
    didCaptureQRCodeTextData textData: String
  ) {}
}

/// The CaptureSessionManager is responsible for setting up and managing the AVCaptureSession and the functions related to capturing.
public final class CaptureSessionManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  public var captureAreaFrame = CGRect.zero
  public var parentFrame = CGRect.zero

  private weak var videoPreviewLayer: AVCaptureVideoPreviewLayer?
  private let captureSession = AVCaptureSession()
  private let rectangleFunnel = RectangleFeaturesFunnel()
  public weak var delegate: RectangleDetectionDelegateProtocol?
  public var displayedRectangleResult: RectangleDetectorResult?
  private var photoOutput = AVCapturePhotoOutput()
  private var metadataOutput = AVCaptureMetadataOutput()

  /// Whether the CaptureSessionManager should be detecting quadrilaterals.
  private var isDetecting = true

  /// The number of times no rectangles have been found in a row.
  private var noRectangleCount = 0

  /// The minimum number of time required by `noRectangleCount` to validate that no rectangles have been found.
  private let noRectangleThreshold = 3

  private let completeImageCapture_queue = DispatchQueue(
    label: "completeImageCapture_queue",
    qos: .userInitiated,
    autoreleaseFrequency: .workItem,
    target: nil
  )
  private let sampleDelegateQueue = DispatchQueue(
    label: "video_ouput_queue",
    qos: .userInitiated
  )
  
  public var shouldCaptureQR = true
  public var qrCodeScanningActive = false

  // MARK: Life Cycle

  public init?(videoPreviewLayer: AVCaptureVideoPreviewLayer?) {
    self.videoPreviewLayer = videoPreviewLayer
    super.init()

    guard let device = AVCaptureDevice.default(for: AVMediaType.video) else {
      let error = ImageScannerError.inputDevice
      delegate?.captureSessionManager(self, didFailWithError: error)
      return nil
    }
    DispatchQueue(label: "capture_session_setup").sync {
      self.captureSession.beginConfiguration()

      let videoOutput = AVCaptureVideoDataOutput()
      videoOutput.alwaysDiscardsLateVideoFrames = true

      defer {
        device.unlockForConfiguration()
        self.captureSession.commitConfiguration()
      }

      guard let deviceInput = try? AVCaptureDeviceInput(device: device),
            self.captureSession.canAddInput(deviceInput),
            self.captureSession.canAddOutput(self.photoOutput),
            self.captureSession.canAddOutput(videoOutput) else {
        let error = ImageScannerError.inputDevice
        self.delegate?.captureSessionManager(self, didFailWithError: error)
        return
      }

      do {
        try device.lockForConfiguration()
      } catch {
        let error = ImageScannerError.inputDevice
        self.delegate?.captureSessionManager(self, didFailWithError: error)
        return
      }

      //      device.isSubjectAreaChangeMonitoringEnabled = true

      self.captureSession.addInput(deviceInput)
      self.captureSession.addOutput(self.photoOutput)
      self.captureSession.addOutput(videoOutput)

      // MARK: Layer connect
      if let _ = videoPreviewLayer {
        videoPreviewLayer?.session = self.captureSession
      }
      videoPreviewLayer?.videoGravity = .resizeAspectFill

      videoOutput.setSampleBufferDelegate(self, queue: sampleDelegateQueue)

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(self.captureSessionInterruptionNotification),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
      )
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(self.captureSessionInterruptionEndedNotification),
        name: UIApplication.willEnterForegroundNotification,
        object: nil
      )
    }
    
    configureQRCodeSession()
  }

  deinit {
    videoPreviewLayer?.removeFromSuperlayer()
    videoPreviewLayer = nil
    captureSession.inputs.forEach { input in
      captureSession.removeInput(input)
    }

    captureSession.outputs.forEach { output in
      captureSession.removeOutput(output)
    }

    captureSession.stopRunning()
    print("⚰️ \(self) deinit 📸 ⚰️ ")
  }

  @objc private func captureSessionInterruptionNotification(
    _ notification: Notification
  ) {
    stop()
  }

  @objc private func captureSessionInterruptionEndedNotification(
    _ notification: Notification
  ) {
    start()
  }

  // MARK: Capture Session Life Cycle

  /// Starts the camera and detecting quadrilaterals.
  private var isRunning: Bool = false
  public func start() {
    guard !isRunning else { return }

    let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    switch authorizationStatus {
    case .authorized:
      DispatchQueue.main.async {
        self.captureSession.startRunning()
        self.isRunning = true
      }
      isDetecting = true
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { _ in
        DispatchQueue.main.async { [weak self] in
          self?.start()
          self?.isRunning = true
        }
      })
    default:
      let error = ImageScannerError.authorization
      delegate?.captureSessionManager(self, didFailWithError: error)
    }
  }

  public func stop() {
    guard isRunning else { return }
    captureSession.stopRunning()
    isRunning = false
  }

  public func capturePhoto() {
    guard isRunning else { return }
    isRunning = false

    guard
      let connection = photoOutput.connection(with: .video),
      connection.isEnabled,
      connection.isActive
    else {
      let error = ImageScannerError.capture
      delegate?.captureSessionManager(self, didFailWithError: error)
      return
    }

    CaptureSession.current.setImageOrientation()
    let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    photoSettings.isHighResolutionPhotoEnabled = true
    photoSettings.isAutoStillImageStabilizationEnabled = true
    photoOutput.isHighResolutionCaptureEnabled = true
    photoOutput
      .setPreparedPhotoSettingsArray([photoSettings]) { [weak photoOutput] success, error in
        if success {
          photoOutput?.capturePhoto(with: photoSettings, delegate: self)
        }
      }
  }

  // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
  public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard
      isDetecting == true,
      let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }

    let imageSize = CGSize(
      width: CVPixelBufferGetWidth(pixelBuffer),
      height: CVPixelBufferGetHeight(pixelBuffer)
    )

    autoreleasepool {
      VisionRectangleDetector.rectangle(forPixelBuffer: pixelBuffer) { [weak self] rectangle in
        var scaledQuad = rectangle
        scaledQuad?.topLeft.x += 15
        scaledQuad?.topLeft.y -= 15
        scaledQuad?.topRight.x -= 15
        scaledQuad?.topRight.y -= 15
        scaledQuad?.bottomLeft.x += 15
        scaledQuad?.bottomLeft.y += 15
        scaledQuad?.bottomRight.x -= 15
        scaledQuad?.bottomRight.y += 15
        
        self?.processRectangle(rectangle: scaledQuad, imageSize: imageSize)
      }

      let image = CIImage(cvImageBuffer: pixelBuffer)
      delegate?.captureSessionManager(self, didReceiveImage: image)
    }
  }

  private func processRectangle(rectangle: Quadrilateral?, imageSize: CGSize) {
    if let rectangle = rectangle {
      self.noRectangleCount = 0
      self.rectangleFunnel.add(
        rectangle,
        currentlyDisplayedRectangle: self.displayedRectangleResult?.rectangle
      ) { [weak self] result, rectangle in

        guard let strongSelf = self else {
          return
        }

        let shouldAutoScan = (result == .showAndAutoScan)
        strongSelf.displayRectangleResult(.init(rectangle: rectangle, imageSize: imageSize))

        if shouldAutoScan, CaptureSession.current.isAutoScanEnabled,
           !CaptureSession.current.isEditing {
          capturePhoto()
        }
      }

    } else {
      DispatchQueue.main.async { [weak self] in
        guard let strongSelf = self else {
          return
        }
        strongSelf.noRectangleCount += 1

        if strongSelf.noRectangleCount > strongSelf.noRectangleThreshold {
          // Reset the currentAutoScanPassCount, so the threshold is restarted the next time a rectangle is found
          strongSelf.rectangleFunnel.currentAutoScanPassCount = 0

          // Remove the currently displayed rectangle as no rectangles are being found anymore
          strongSelf.displayedRectangleResult = nil
          strongSelf.delegate?.captureSessionManager(strongSelf, didDetectQuad: nil, imageSize)
        }
      }
      return
    }
  }

  @discardableResult
  private func displayRectangleResult(
    _ result: RectangleDetectorResult
  ) -> Quadrilateral {
    displayedRectangleResult = result

    let quad = result.rectangle
      .toCartesian(withHeight: result.imageSize.height)

    DispatchQueue.main.async { [weak self] in
      guard let strongSelf = self else {
        return
      }

      strongSelf.delegate?
        .captureSessionManager(strongSelf, didDetectQuad: quad, result.imageSize)
    }

    return quad
  }
  
  private func configureQRCodeSession() {
    guard captureSession.canAddOutput(metadataOutput) else { return }
    
    captureSession.addOutput(metadataOutput)
    
    metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
    metadataOutput.metadataObjectTypes = [.qr]
  }
}

extension CaptureSessionManager: AVCaptureMetadataOutputObjectsDelegate {
  public func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard qrCodeScanningActive, shouldCaptureQR else { return }
    
    shouldCaptureQR = false
    
    if let metadataObject = metadataObjects.first,
       let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
       let stringValue = readableObject.stringValue {
      
      delegate?.captureSessionManager(self, didCaptureQRCodeTextData: stringValue)
    } else {
      shouldCaptureQR = true
    }
  }
}


extension CaptureSessionManager: AVCapturePhotoCaptureDelegate {
  /*
   public func photoOutput(
   _ captureOutput: AVCapturePhotoOutput,
   didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
   previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
   resolvedSettings: AVCaptureResolvedPhotoSettings,
   bracketSettings: AVCaptureBracketedStillImageSettings?,
   error: Error?) {

   if let error = error {
   delegate?.captureSessionManager(self, didFailWithError: error)
   return
   }

   isDetecting = false
   rectangleFunnel.currentAutoScanPassCount = 0
   delegate?.didStartCapturingPicture(for: self)

   if let sampleBuffer = photoSampleBuffer,
   let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: nil) {
   completeImageCapture(with: imageData)
   } else {
   let error = ImageScannerControllerError.capture
   delegate?.captureSessionManager(self, didFailWithError: error)
   return
   }

   }
   */

  public func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    if let error = error.flatMap({ $0 as NSError }) {
      if error.code == -11803 {
        let _error = ImageScannerError.capture
        delegate?.captureSessionManager(self, didFailWithError: _error)
      } else {
        delegate?.captureSessionManager(self, didFailWithError: error)
      }
      return
    }

    isDetecting = false
    rectangleFunnel.currentAutoScanPassCount = 0
    delegate?.didStartCapturingPicture(for: self)

    if let imageData = photo.fileDataRepresentation() {
      completeImageCapture(with: imageData)
    } else {
      let error = ImageScannerError.capture
      delegate?.captureSessionManager(self, didFailWithError: error)
      return
    }
  }

  /// Completes the image capture by processing the image, and passing it to the delegate object.
  /// This function is necessary because the capture functions for iOS 10 and 11 are decoupled.
  private func completeImageCapture(with imageData: Data) {
    completeImageCapture_queue.async { [weak self] in
      autoreleasepool {
        benchmark(operationTitle: "Photo capture") {
          CaptureSession.current.isEditing = true

          guard let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
              guard let strongSelf = self else { return }
              strongSelf.delegate?
                .captureSessionManager(
                  strongSelf,
                  didFailWithError: ImageScannerError.capture
                )
            }
            return
          }

          var angle: CGFloat = 0.0

          switch image.imageOrientation {
          case .right:
            angle = CGFloat.pi / 2
          case .up:
            angle = CGFloat.pi
          default:
            break
          }

          var orientedImage = image

          benchmark(operationTitle: "Orient captured image") {
            orientedImage = image.applyingPortraitOrientation()
          }

          var quad: Quadrilateral?
          if let displayedRectangleResult = self?.displayedRectangleResult {
            quad = self?.displayRectangleResult(displayedRectangleResult)
            quad = quad?.scale(
              displayedRectangleResult.imageSize,
              orientedImage.size,
              withRotationAngle: angle
            )
          }

          DispatchQueue.main.async {
            guard let strongSelf = self else {
              return
            }
            strongSelf.delegate?
              .captureSessionManager(
                strongSelf,
                didCapturePicture: orientedImage,
                withQuad: quad
              )
          }
        }
      }
    }
  }
}

/// Data structure representing the result of the detection of a quadrilateral.
public struct RectangleDetectorResult {
  /// The detected quadrilateral.
  public let rectangle: Quadrilateral

  /// The size of the image the quadrilateral was detected on.
  public let imageSize: CGSize
}
