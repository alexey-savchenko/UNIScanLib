//
//  CGPoint+Utils.swift
//  WeScan
//
//  Created by Boris Emorine on 2/9/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import CoreGraphics
import UNILibCore

public extension CGPoint {
  /// Returns the closest corner from the point
  func closestCornerFrom(quad: Quadrilateral) -> CornerPosition {
    var smallestDistance = distanceTo(point: quad.topLeft)
    var closestCorner = CornerPosition.topLeft

    if distanceTo(point: quad.topRight) < smallestDistance {
      smallestDistance = distanceTo(point: quad.topRight)
      closestCorner = .topRight
    }

    if distanceTo(point: quad.bottomRight) < smallestDistance {
      smallestDistance = distanceTo(point: quad.bottomRight)
      closestCorner = .bottomRight
    }

    if distanceTo(point: quad.bottomLeft) < smallestDistance {
      smallestDistance = distanceTo(point: quad.bottomLeft)
      closestCorner = .bottomLeft
    }

    return closestCorner
  }
}
