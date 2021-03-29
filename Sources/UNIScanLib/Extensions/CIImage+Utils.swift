//
//  CIImage+Utils.swift
//  WeScan
//
//  Created by Julian Schiavo on 14/11/2018.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import CoreImage
import UIKit

extension CIImage {
  
  func rotated(radians: CGFloat) -> CIImage {
    return Self.rotate(image: self, radians: radians)
  }
  
  func scaled(_ scaleValue: CGFloat) -> CIImage {
    return Self.scale(inputImage: self, scale: CGSize(width: scaleValue, height: scaleValue))
  }
  
  static func rotate(image: CIImage,
              radians: CGFloat,
              relativeAnchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> CIImage {
    
    let extent = image.extent
    let anchor = CGPoint(x: extent.width * relativeAnchorPoint.x,
                         y: extent.height * relativeAnchorPoint.y)
    
    let t = CGAffineTransform.identity
      .translatedBy(x: anchor.x, y: anchor.y)
      .rotated(by: radians)
      .translatedBy(x: -anchor.x, y: -anchor.y)
    
    return image.transformed(by: t)
  }

  static func scale(inputImage: CIImage,
             scale: CGSize,
             relativeAnchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> CIImage {
    
    // scale transform
    let scaleTransform = CGAffineTransform.identity.scaledBy(x: scale.width, y: scale.height)
    let scaledImage = inputImage.transformed(by: scaleTransform)
    
    // translation transform to keep image aligned with anchor point
    let translationTransform =
      CGAffineTransform(translationX: (inputImage.extent.origin.x - scaledImage.extent.origin.x) + (inputImage.extent.width - scaledImage.extent.width) * relativeAnchor.x,
                        y: (inputImage.extent.origin.y - scaledImage.extent.origin.y) + (inputImage.extent.height - scaledImage.extent.height) * relativeAnchor.y)
    let translatedImage = scaledImage.transformed(by: translationTransform)
    return translatedImage
  }
  
    /// Applies an AdaptiveThresholding filter to the image, which enhances the image and makes it completely gray scale
    func applyingAdaptiveThreshold() -> UIImage? {
        guard let colorKernel = CIColorKernel(source:
            """
            kernel vec4 color(__sample pixel, float inputEdgeO, float inputEdge1)
            {
                float luma = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
                float threshold = smoothstep(inputEdgeO, inputEdge1, luma);
                return vec4(threshold, threshold, threshold, 1.0);
            }
            """
            ) else { return nil }
        
        let firstInputEdge = 0.25
        let secondInputEdge = 0.75
        
        let arguments: [Any] = [self, firstInputEdge, secondInputEdge]

        guard let enhancedCIImage = colorKernel.apply(extent: self.extent, arguments: arguments) else { return nil }

        if let cgImage = CIContext(options: nil).createCGImage(enhancedCIImage, from: enhancedCIImage.extent) {
            return UIImage(cgImage: cgImage)
        } else {
            return UIImage(ciImage: enhancedCIImage, scale: 1.0, orientation: .up)
        }
    }
}
