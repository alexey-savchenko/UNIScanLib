//
//  Error.swift
//  WeScan
//
//  Created by Boris Emorine on 2/28/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import Foundation

/// Errors related to the `ImageScannerController`
public enum ImageScannerError: LocalizedError {
  /// The user didn't grant permission to use the camera.
  case authorization
  /// An error occured when setting up the user's device.
  case inputDevice
  /// An error occured when trying to capture a picture.
  case capture
  /// Error when creating the CIImage.
  case ciImageCreation
  
  var errorDescription: String {
    switch self {
    case .authorization:
      return "Failed to get the user's authorization for camera. Scanning is unavailable without camera usage description."
    case .inputDevice:
      return "Could not setup input device."
    case .capture:
      return "Could not capture picture."
    case .ciImageCreation:
      return "Internal Error - Could not create CIImage"
    }
  }
}
