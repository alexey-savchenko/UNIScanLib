//
//  Quadrilateral.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import CoreImage
import UNILibCore

/// Simple enum to keep track of the position of the corners of a quadrilateral.
public enum CornerPosition {
  case topLeft
  case topRight
  case bottomRight
  case bottomLeft
}

/// Simple enum to keep track of the position of the edges of a quadrilateral.
public enum EdgePosition {
  case top
  case bottom
  case left
  case right
}

/// A data structure representing a quadrilateral and its position. This class exists to bypass the fact that CIRectangleFeature is read-only.
public struct Quadrilateral: Codable, Transformable {
  /// A point that specifies the top left corner of the quadrilateral.
  public var topLeft: CGPoint

  /// A point that specifies the top right corner of the quadrilateral.
  public var topRight: CGPoint

  /// A point that specifies the bottom right corner of the quadrilateral.
  public var bottomRight: CGPoint

  /// A point that specifies the bottom left corner of the quadrilateral.
  public var bottomLeft: CGPoint

  public var description: String {
    return "topLeft: \(topLeft), topRight: \(topRight), bottomRight: \(bottomRight), bottomLeft: \(bottomLeft)"
  }

  /// The path of the Quadrilateral as a `UIBezierPath`
  public var path: UIBezierPath {
    let path = UIBezierPath()
    path.move(to: topLeft)
    path.addLine(to: topRight)
    path.addLine(to: bottomRight)
    path.addLine(to: bottomLeft)
    path.close()

    return path
  }

  /// The perimeter of the Quadrilateral
  var perimeter: Double {
    let perimeter = topLeft.distanceTo(point: topRight) + topRight
      .distanceTo(point: bottomRight) + bottomRight
      .distanceTo(point: bottomLeft) + bottomLeft.distanceTo(point: topLeft)
    return Double(perimeter)
  }

  init(rectangleFeature: CIRectangleFeature) {
    self.topLeft = rectangleFeature.topLeft
    self.topRight = rectangleFeature.topRight
    self.bottomLeft = rectangleFeature.bottomLeft
    self.bottomRight = rectangleFeature.bottomRight
  }

  @available(iOS 11.0, *)
  public init(rectangleObservation: VNRectangleObservation) {
    self.topLeft = rectangleObservation.topLeft
    self.topRight = rectangleObservation.topRight
    self.bottomLeft = rectangleObservation.bottomLeft
    self.bottomRight = rectangleObservation.bottomRight
  }

  public init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
    self.topLeft = topLeft
    self.topRight = topRight
    self.bottomRight = bottomRight
    self.bottomLeft = bottomLeft
  }

  public init() {
    self.topLeft = .zero
    self.topRight = .zero
    self.bottomRight = .zero
    self.bottomLeft = .zero
  }

  /// Applies a `CGAffineTransform` to the quadrilateral.
  ///
  /// - Parameters:
  ///   - t: the transform to apply.
  /// - Returns: The transformed quadrilateral.
  public func applying(_ transform: CGAffineTransform) -> Quadrilateral {
    let quadrilateral = Quadrilateral(
      topLeft: topLeft.applying(transform),
      topRight: topRight.applying(transform),
      bottomRight: bottomRight.applying(transform),
      bottomLeft: bottomLeft.applying(transform)
    )

    return quadrilateral
  }

  /// Checks whether the quadrilateral is withing a given distance of another quadrilateral.
  ///
  /// - Parameters:
  ///   - distance: The distance (threshold) to use for the condition to be met.
  ///   - rectangleFeature: The other rectangle to compare this instance with.
  /// - Returns: True if the given rectangle is within the given distance of this rectangle instance.
  func isWithin(_ distance: CGFloat, ofRectangleFeature rectangleFeature: Quadrilateral) -> Bool {
    let topLeftRect = topLeft.surroundingSquare(withSize: distance)
    if !topLeftRect.contains(rectangleFeature.topLeft) {
      return false
    }

    let topRightRect = topRight.surroundingSquare(withSize: distance)
    if !topRightRect.contains(rectangleFeature.topRight) {
      return false
    }

    let bottomRightRect = bottomRight.surroundingSquare(withSize: distance)
    if !bottomRightRect.contains(rectangleFeature.bottomRight) {
      return false
    }

    let bottomLeftRect = bottomLeft.surroundingSquare(withSize: distance)
    if !bottomLeftRect.contains(rectangleFeature.bottomLeft) {
      return false
    }

    return true
  }

  /// Reorganizes the current quadrilateal, making sure that the points are at their appropriate positions. For example, it ensures that the top left point is actually the top and left point point of the quadrilateral.
  public mutating func reorganize() {
    let points = [topLeft, topRight, bottomRight, bottomLeft]
    let ySortedPoints = sortPointsByYValue(points)

    guard ySortedPoints.count == 4 else {
      return
    }

    let topMostPoints = Array(ySortedPoints[0 ..< 2])
    let bottomMostPoints = Array(ySortedPoints[2 ..< 4])
    let xSortedTopMostPoints = sortPointsByXValue(topMostPoints)
    let xSortedBottomMostPoints = sortPointsByXValue(bottomMostPoints)

    guard xSortedTopMostPoints.count > 1,
          xSortedBottomMostPoints.count > 1 else {
      return
    }

    topLeft = xSortedTopMostPoints[0]
    topRight = xSortedTopMostPoints[1]
    bottomRight = xSortedBottomMostPoints[1]
    bottomLeft = xSortedBottomMostPoints[0]
  }

  /// Scales the quadrilateral based on the ratio of two given sizes, and optionaly applies a rotation.
  ///
  /// - Parameters:
  ///   - fromSize: The size the quadrilateral is currently related to.
  ///   - toSize: The size to scale the quadrilateral to.
  ///   - rotationAngle: The optional rotation to apply.
  /// - Returns: The newly scaled and potentially rotated quadrilateral.
  public func scale(
    _ fromSize: CGSize,
    _ toSize: CGSize,
    withRotationAngle rotationAngle: CGFloat = 0.0
  ) -> Quadrilateral {
    var invertedfromSize = fromSize
    let rotated = rotationAngle != 0.0

    if rotated && rotationAngle != CGFloat.pi {
      invertedfromSize = CGSize(width: fromSize.height, height: fromSize.width)
    }

    var transformedQuad = self
    let invertedFromSizeWidth = invertedfromSize
      .width == 0 ? .leastNormalMagnitude : invertedfromSize.width

    let scale = toSize.width / invertedFromSizeWidth
    let scaledTransform = CGAffineTransform(scaleX: scale, y: scale)
    transformedQuad = transformedQuad.applying(scaledTransform)

    if rotated {
      let rotationTransform = CGAffineTransform(rotationAngle: rotationAngle)

      let fromImageBounds = CGRect(origin: .zero, size: fromSize).applying(scaledTransform)
        .applying(rotationTransform)

      let toImageBounds = CGRect(origin: .zero, size: toSize)
      let translationTransform = CGAffineTransform.translateTransform(
        fromCenterOfRect: fromImageBounds,
        toCenterOfRect: toImageBounds
      )

      transformedQuad = transformedQuad.applyTransforms([rotationTransform, translationTransform])
    }

    return transformedQuad
  }

  // Convenience functions

  /// Sorts the given `CGPoints` based on their y value.
  /// - Parameters:
  ///   - points: The poinmts to sort.
  /// - Returns: The points sorted based on their y value.
  private func sortPointsByYValue(_ points: [CGPoint]) -> [CGPoint] {
    return points.sorted { (point1, point2) -> Bool in
      point1.y < point2.y
    }
  }

  /// Sorts the given `CGPoints` based on their x value.
  /// - Parameters:
  ///   - points: The points to sort.
  /// - Returns: The points sorted based on their x value.
  private func sortPointsByXValue(_ points: [CGPoint]) -> [CGPoint] {
    return points.sorted { (point1, point2) -> Bool in
      point1.x < point2.x
    }
  }
}

public extension Quadrilateral {
  func relativeToSize(_ size: CGSize) -> Quadrilateral {
    return Quadrilateral(
      topLeft: .init(x: topLeft.x / size.width, y: topLeft.y / size.height),
      topRight: .init(x: topRight.x / size.width, y: topRight.y / size.height),
      bottomRight: .init(x: bottomRight.x / size.width, y: bottomRight.y / size.height),
      bottomLeft: .init(x: bottomLeft.x / size.width, y: bottomLeft.y / size.height)
    )
  }

  func makeAbsolute(with size: CGSize) -> Quadrilateral {
    return Quadrilateral(
      topLeft: .init(x: topLeft.x * size.width, y: topLeft.y * size.height),
      topRight: .init(x: topRight.x * size.width, y: topRight.y * size.height),
      bottomRight: .init(x: bottomRight.x * size.width, y: bottomRight.y * size.height),
      bottomLeft: .init(x: bottomLeft.x * size.width, y: bottomLeft.y * size.height)
    )
  }

  /// Converts the current to the cartesian coordinate system (where 0 on the y axis is at the bottom).
  ///
  /// - Parameters:
  ///   - height: The height of the rect containing the quadrilateral.
  /// - Returns: The same quadrilateral in the cartesian corrdinate system.
  func toCartesian(withHeight height: CGFloat) -> Quadrilateral {
    let topLeft = self.topLeft.cartesian(withHeight: height)
    let topRight = self.topRight.cartesian(withHeight: height)
    let bottomRight = self.bottomRight.cartesian(withHeight: height)
    let bottomLeft = self.bottomLeft.cartesian(withHeight: height)

    return Quadrilateral(
      topLeft: topLeft,
      topRight: topRight,
      bottomRight: bottomRight,
      bottomLeft: bottomLeft
    )
  }
}

extension CGPoint: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(x)
    hasher.combine(y)
  }
}

extension Quadrilateral: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(topLeft)
    hasher.combine(topRight)
    hasher.combine(bottomLeft)
    hasher.combine(bottomRight)
  }
}

private let minImageWidth: CGFloat = 100.0

public extension Quadrilateral {
  init(rect: CGRect) {
    self.init(
      topLeft: rect.origin,
      topRight: .init(x: rect.maxX, y: rect.minY),
      bottomRight: .init(x: rect.maxX, y: rect.maxY),
      bottomLeft: .init(x: rect.minX, y: rect.maxY)
    )
  }

  static func defaultQuad(for image: UIImage) -> Quadrilateral {
    let imgSize = image.size

    if imgSize.width >= minImageWidth {
      return .init(
        rect: CGRect(
          origin: .zero,
          size: imgSize
        )
        .insetBy(dx: 40, dy: 40)
      )
    } else {
      return Quadrilateral(
        topLeft: CGPoint(x: 0, y: 0),
        topRight: CGPoint(x: imgSize.width, y: 0),
        bottomRight: CGPoint(x: imgSize.width, y: imgSize.height),
        bottomLeft: CGPoint(x: 0, y: imgSize.height)
      )
    }

    // old implementation:

    //    return Quadrilateral(
    //      topLeft: CGPoint(x: imgSize.width / 3, y: imgSize.height / 3),
    //      topRight: CGPoint(x: (imgSize.width / 3) * 2, y: imgSize.height / 3),
    //      bottomRight: CGPoint(x: (imgSize.width / 3) * 2, y: (imgSize.height / 3) * 2),
    //      bottomLeft: CGPoint(x: imgSize.width / 3, y: (imgSize.height / 3) * 2)
    //    )
  }

  static func defaultHorizontalQuad(for image: UIImage) -> Quadrilateral {
    let imgSize = image.size
    return Quadrilateral(
      topLeft: CGPoint(x: imgSize.width * 0.33, y: imgSize.height / 3),
      topRight: CGPoint(x: imgSize.width * 0.66, y: imgSize.height / 3),
      bottomRight: CGPoint(x: imgSize.width * 0.66, y: (imgSize.height / 3) * 2),
      bottomLeft: CGPoint(x: imgSize.width * 0.33, y: (imgSize.height / 3) * 2)
    )
  }
}

public extension Quadrilateral {
  static func quad(
    _ first: Quadrilateral,
    significantlyDifferentThen second: Quadrilateral
  ) -> Bool {
    let _max = max(first.squreValue(), second.squreValue())
    let _min = min(first.squreValue(), second.squreValue())

    return (_max / _min) - 1.0 > 0.25
  }

  func squreValue() -> CGFloat {
    let a = Line(p1: topLeft, p2: topRight)
    let b = Line(p1: topRight, p2: bottomRight)
    let c = Line(p1: bottomRight, p2: bottomLeft)
    let d = Line(p1: bottomLeft, p2: topLeft)

    let lineLengths = [a, b, c, d].map(lengthOf)
    let halfPerimeter = lineLengths.reduce(0, +) / 2

    return CGFloat(sqrtf(
      zip(
        lineLengths,
        (0 ... lineLengths.count)
          .map { _ in halfPerimeter }
      )
      .reduce(1, { $0 * ($1.1 - $1.0) })
    ))
  }
}

public func lengthOf(_ line: Line) -> Float {
  return sqrtf(Float(
    pow(line.p2.x - line.p1.x, CGFloat(2)) +
      pow(line.p2.y - line.p1.y, CGFloat(2))
  ))
}

public struct Line {
  public let p1: CGPoint
  public let p2: CGPoint

  public init(p1: CGPoint, p2: CGPoint) {
    self.p1 = p1
    self.p2 = p2
  }

  public var slope: Float {
    let value = Float(abs((p1.y - p2.y) / (p1.x - p2.x)))
    return value != Float.infinity ? value : 10000
  }
}

infix operator &/
func &/ (lhs: Float, rhs: Float) -> Float {
  if rhs == 0 {
    return 0
  }
  return lhs / rhs
}

func &/ (lhs: CGFloat, rhs: CGFloat) -> CGFloat {
  if rhs == 0 {
    return 0
  }
  return lhs / rhs
}

public func angleBetween(_ l1: Line, and l2: Line) -> Float {
  return (atan((l1.slope - l2.slope) / (1 + l1.slope * l2.slope))) * 180.0 / Float.pi
}

extension Quadrilateral: Equatable {
  public static func == (lhs: Quadrilateral, rhs: Quadrilateral) -> Bool {
    return pointsEquals(lhs.topLeft, rhs.topLeft) &&
      pointsEquals(lhs.topRight, rhs.topRight) &&
      pointsEquals(lhs.bottomLeft, rhs.bottomLeft) &&
      pointsEquals(lhs.bottomRight, rhs.bottomRight)
  }

  fileprivate static func pointsEquals(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
    let delta = 0.001
    return fabs(Double(lhs.x - rhs.x)) < delta && fabs(Double(lhs.y - rhs.y)) < delta
  }
}
