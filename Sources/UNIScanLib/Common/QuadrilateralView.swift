//
//  RectangleView.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit
import AVFoundation

// Simple enum to keep track of the position of the corners of a quadrilateral.
enum CornerPosition {
  case topLeft
  case topRight
  case bottomRight
  case bottomLeft
}

// Simple enum to keep track of the position of the edges of a quadrilateral.
enum EdgePosition {
  case top
  case bottom
  case left
  case right
}

public protocol QuadrilateralViewDelegate: class {
  func didDragCornerAt(_ point: CGPoint)
  func didBeganDraggingCorner()
  func didFinishDraggingCorner()
}

// The `QuadrilateralView` is a simple `UIView` subclass that can draw a quadrilateral, and optionally edit it.
final public class QuadrilateralView: UIView {

  weak public var delegate: QuadrilateralViewDelegate?
  
  /// The quadrilateral drawn on the view.
  private(set) var quad: Quadrilateral?
  
  public var currentQuad: Quadrilateral? {
    return quad
  }
  
  private let quadView = QuadView()
  
  public var editable = false {
    didSet {
      editable == true ? showCornerButtons() : hideCornerButtons()
      edgeButtons(isHidden: !editable)
      
      guard let quad = quad else {
        return
      }
      drawQuad(quad)
      layoutCornerButtons(forQuad: quad)
      layoutEdgeButtons(forQuad: quad)
    }
  }
  
  // MARK: - Corner buttons
  
  lazy var topLeftCornerButton: EditScanCornerView = {
    return cornerButton(atPosition: .topLeft)
  }()
  
  lazy var topRightCornerButton: EditScanCornerView = {
    return cornerButton(atPosition: .topRight)
  }()
  
  lazy var bottomRightCornerButton: EditScanCornerView = {
    return cornerButton(atPosition: .bottomRight)
  }()
  
  lazy var bottomLeftCornerButton: EditScanCornerView = {
    return cornerButton(atPosition: .bottomLeft)
  }()
  
  // MARK: - Edge buttons
  
  lazy var topEdgeButton: EditScanEdgeView = {
    return edgeButton(atPosition: .top)
  }()
  
  lazy var bottomEdgeButton: EditScanEdgeView = {
    return edgeButton(atPosition: .bottom)
  }()
  
  lazy var leftEdgeButton: EditScanEdgeView = {
    return edgeButton(atPosition: .left)
  }()
  
  lazy var rightEdgeButton: EditScanEdgeView = {
    return edgeButton(atPosition: .right)
  }()
  
  // MARK: - Life Cycle
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func commonInit() {
    addSubview(quadView)
    quadView.backgroundColor = .clear
    setupCornerButtons()
    setupEdgeButtons()
  }
  
  public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    return CGRect(x: bounds.minX - 20,
                  y: bounds.minY - 20,
                  width: bounds.width + 20 * 2,
                  height: bounds.height + 20 * 2).contains(point)
  }
  
  public func setQuadValid(_ valid: Bool) {
    if valid {
      quadView.color = .valid
    } else {
      quadView.color = .invalid
    }
    quadView.setNeedsDisplay()
  }
  
  private func setupCornerButtons() {
    [topLeftCornerButton,
     topRightCornerButton,
     bottomRightCornerButton,
     bottomLeftCornerButton].forEach(addSubview)
  }
  
  private func setupEdgeButtons() {
    [topEdgeButton,
     bottomEdgeButton,
     leftEdgeButton,
     rightEdgeButton].forEach(addSubview)
  }
  
  override public func layoutSubviews() {
    super.layoutSubviews()
    quadView.frame = bounds
    
    if let quad = quad {
      drawQuadrilateral(quad: quad, animated: false)
    }
  }
  
  // MARK: - Drawings
  
  /// Draws the passed in quadrilateral.
  ///
  /// - Parameters:
  ///   - quad: The quadrilateral to draw on the view. It should be in the coordinates of the current `QuadrilateralView` instance.
  public func drawQuadrilateral(quad: Quadrilateral, animated: Bool) {
    self.quad = quad
    quadView.quad = quad
    
//    drawQuad(quad, animated: animated)
    if editable {
      showCornerButtons()
      edgeButtons(isHidden: false)
      layoutCornerButtons(forQuad: quad)
      layoutEdgeButtons(forQuad: quad)
    }
    
    if animated {
      UIView.animate(withDuration: 0.15) {
        self.quadView.setNeedsDisplay()
      }
    } else {
      quadView.setNeedsDisplay()
    }
  }
  
  private func drawQuad(_ quad: Quadrilateral) {
    quadView.quad = quad
    quadView.setNeedsDisplay()
  }
  
  private func layoutCornerButtons(forQuad quad: Quadrilateral) {
    let buttonSize: CGFloat = 32.0
    let cornerRadius = buttonSize / 2.0
    
    topLeftCornerButton.frame = CGRect(
      x: quad.topLeft.x - buttonSize / 2.0,
      y: quad.topLeft.y - buttonSize / 2.0,
      width: buttonSize,
      height: buttonSize
    )
    topLeftCornerButton.layer.cornerRadius = cornerRadius
    
    topRightCornerButton.frame = CGRect(
      x: quad.topRight.x - buttonSize / 2.0,
      y: quad.topRight.y - buttonSize / 2.0,
      width: buttonSize,
      height: buttonSize
    )
    topRightCornerButton.layer.cornerRadius = cornerRadius
    
    bottomRightCornerButton.frame = CGRect(
      x: quad.bottomRight.x - buttonSize / 2.0,
      y: quad.bottomRight.y - buttonSize / 2.0,
      width: buttonSize,
      height: buttonSize
    )
    bottomRightCornerButton.layer.cornerRadius = cornerRadius
    
    bottomLeftCornerButton.frame = CGRect(
      x: quad.bottomLeft.x - buttonSize / 2.0,
      y: quad.bottomLeft.y - buttonSize / 2.0,
      width: buttonSize,
      height: buttonSize
    )
    bottomLeftCornerButton.layer.cornerRadius = cornerRadius
  }
  
  private func layoutEdgeButtons(forQuad quad: Quadrilateral) {
    let buttonWidth: CGFloat = 24
    let cornerRadius = buttonWidth / 2.0
    let size = CGSize(
      width: buttonWidth,
      height: buttonWidth
    )
    
    topEdgeButton.frame = rectBetweenPoints(
      p1: quad.topLeft,
      p2: quad.topRight,
      size: size
    )
    topEdgeButton.layer.cornerRadius = cornerRadius
    
    bottomEdgeButton.frame = rectBetweenPoints(
      p1: quad.bottomLeft,
      p2: quad.bottomRight,
      size: size
    )
    bottomEdgeButton.layer.cornerRadius = cornerRadius
    
    leftEdgeButton.frame = rectBetweenPoints(
      p1: quad.topLeft,
      p2: quad.bottomLeft,
      size: size
    )
    leftEdgeButton.layer.cornerRadius = cornerRadius
    
    rightEdgeButton.frame = rectBetweenPoints(
      p1: quad.topRight,
      p2: quad.bottomRight,
      size: size
    )
    rightEdgeButton.layer.cornerRadius = cornerRadius
  }
  
  private func rectBetweenPoints(
    p1: CGPoint,
    p2: CGPoint,
    size: CGSize
  ) -> CGRect {
    
    return CGRect(
      x: (p1.x + p2.x - size.width) / 2,
      y: (p1.y + p2.y - size.height) / 2,
      width: size.width,
      height:size.height
    )
  }
  
  // MARK: - Actions
  
  @objc func dragCorner(panGesture: UIPanGestureRecognizer) {
    guard let cornerButton = panGesture.view as? EditScanCornerView,
      let quad = quad else {
        return
    }
    
    switch panGesture.state {
    case .began:
      delegate?.didBeganDraggingCorner()
    case .ended, .failed, .cancelled:
      delegate?.didFinishDraggingCorner()
    default:
      break
    }
    
    var center = panGesture.location(in: self)
    center = validPoint(
      center,
      forCornerViewOfSize: cornerButton.bounds.size,
      inView: self
    )
    
    panGesture.view?.center = center
    let updatedQuad = updated(
      quad,
      withPosition: center,
      forCorner: cornerButton.position
    )
    
    self.quad = updatedQuad
    layoutEdgeButtons(forQuad: updatedQuad)
    drawQuad(updatedQuad)
    delegate?.didDragCornerAt(center)
  }
  
  typealias EdgePositions = (p1: CGPoint, p2: CGPoint)
  
  private var translationPoints: EdgePositions?
  
  private func validAndGetEdgesPosition(
    gestureLocation: CGPoint,
    translation: EdgePositions,
    buttonSize: CGSize
  ) -> EdgePositions {
    
    let point1 = validPoint(
      CGPoint(
        x: gestureLocation.x + translation.p1.x,
        y: gestureLocation.y + translation.p1.y
      ),
      forCornerViewOfSize: buttonSize,
      inView: self
    )
    let point2 = validPoint(
      CGPoint(
        x: gestureLocation.x + translation.p2.x,
        y: gestureLocation.y + translation.p2.y
      ),
      forCornerViewOfSize: buttonSize,
      inView: self
    )
    
    return (p1: point1, p2: point2)
  }
  
  private func update(
    pointPositions: EdgePositions,
    edgeButton: EditScanEdgeView
  ) -> EdgePositions {
    (
      CGPoint(
        x: pointPositions.p1.x - edgeButton.center.x,
        y: pointPositions.p1.y - edgeButton.center.y
      ),
      CGPoint(
        x: pointPositions.p2.x - edgeButton.center.x,
        y: pointPositions.p2.y - edgeButton.center.y
      )
    )
  }
  
  @objc func dragEdge(panGesture: UIPanGestureRecognizer) {
    guard
      let edgeButton = panGesture.view as? EditScanEdgeView,
      var quad = quad
      else { return }
    
    switch panGesture.state {
      case .began:
        switch edgeButton.position {
          case .top:
            translationPoints = update(
              pointPositions: (
                p1: quad.topLeft,
                p2: quad.topRight),
              edgeButton: edgeButton
          )
          case .bottom:
            translationPoints = update(
              pointPositions: (
                p1: quad.bottomLeft,
                p2: quad.bottomRight),
              edgeButton: edgeButton
          )
          case .left:
            translationPoints = update(
              pointPositions: (
                p1: quad.topLeft,
                p2: quad.bottomLeft),
              edgeButton: edgeButton
          )
          case .right:
            translationPoints = update(
              pointPositions: (
                p1: quad.topRight,
                p2: quad.bottomRight),
              edgeButton: edgeButton
          )
        }
        delegate?.didBeganDraggingCorner()
      case .ended, .failed, .cancelled:
        translationPoints = nil
        delegate?.didFinishDraggingCorner()
      default:
        break
    }
    
    guard
      let translation = translationPoints
      else { return }
    
    let buttonSIze = edgeButton.bounds.size
    
    let gestureLocation = panGesture.location(in: self)
    panGesture.view?.center = gestureLocation
    let points = validAndGetEdgesPosition(
      gestureLocation: gestureLocation,
      translation: translation,
      buttonSize: buttonSIze
    )
    
    switch edgeButton.position {
      case .top:
        quad.topLeft = points.p1
        quad.topRight = points.p2
      case .bottom:
        quad.bottomLeft = points.p1
        quad.bottomRight = points.p2
      case .left:
        quad.topLeft = points.p1
        quad.bottomLeft = points.p2
      case .right:
        quad.topRight = points.p1
        quad.bottomRight = points.p2
    }
    
    self.quad = quad
    
    layoutEdgeButtons(forQuad: quad)
    layoutCornerButtons(forQuad: quad)
    
    drawQuad(quad)
    delegate?.didDragCornerAt(edgeButton.center)
  }
  
  // MARK: Validation
  
  /// Ensures that the given point is valid - meaning that it is within the bounds of the passed in `UIView`.
  ///
  /// - Parameters:
  ///   - point: The point that needs to be validated.
  ///   - cornerViewSize: The size of the corner view representing the given point.
  ///   - view: The view which should include the point.
  /// - Returns: A new point which is within the passed in view.
  private func validPoint(
    _ point: CGPoint,
    forCornerViewOfSize cornerViewSize: CGSize,
    inView view: UIView
  ) -> CGPoint {
    
    var validPoint = point
    
    if point.x > view.bounds.width {
      validPoint.x = view.bounds.width
    } else if point.x < 0.0 {
      validPoint.x = 0.0
    }
    
    if point.y > view.bounds.height {
      validPoint.y = view.bounds.height
    } else if point.y < 0.0 {
      validPoint.y = 0.0
    }
    
    return validPoint
  }
  
  // MARK: - Convenience
  
  private func cornerButton(atPosition position: CornerPosition) -> EditScanCornerView {
    let button = EditScanCornerView(frame: CGRect.zero, position: position)
    let dragCornerGesture = UIPanGestureRecognizer(
      target: self,
      action: #selector(dragCorner(panGesture:))
    )
    button.addGestureRecognizer(dragCornerGesture)
    
    return button
  }
  
  private func edgeButton(atPosition position: EdgePosition) -> EditScanEdgeView {
    let button = EditScanEdgeView(frame: CGRect.zero, position: position)
    let dragCornerGesture = UIPanGestureRecognizer(
      target: self,
      action: #selector(dragEdge(panGesture:))
    )
    button.addGestureRecognizer(dragCornerGesture)
    
    return button
  }
  
  private func hideCornerButtons() {
    topLeftCornerButton.isHidden = true
    topRightCornerButton.isHidden = true
    bottomRightCornerButton.isHidden = true
    bottomLeftCornerButton.isHidden = true
  }
  
  private func showCornerButtons() {
    topLeftCornerButton.isHidden = false
    topRightCornerButton.isHidden = false
    bottomRightCornerButton.isHidden = false
    bottomLeftCornerButton.isHidden = false
  }
  
  private func edgeButtons(isHidden: Bool) {
    topEdgeButton.isHidden = isHidden
    bottomEdgeButton.isHidden = isHidden
    leftEdgeButton.isHidden = isHidden
    rightEdgeButton.isHidden = isHidden
  }
  
  private func updated(
    _ quad: Quadrilateral,
    withPosition position: CGPoint,
    forCorner corner: CornerPosition
  ) -> Quadrilateral {
    
    var quad = quad
    
    switch corner {
    case .topLeft:
      quad.topLeft = position
      
    case .topRight:
      quad.topRight = position
      
    case .bottomRight:
      quad.bottomRight = position
      
    case .bottomLeft:
      quad.bottomLeft = position
    }
    
    return quad
  }
}

public class QuadView: UIView {
  enum Color {
    case valid
    case invalid
  }
  
  var color: Color = .valid
  var quad = Quadrilateral()
  
  override public func draw(_ rect: CGRect) {
    drawQuad(quad)
  }
  
  private func drawQuad(_ quad: Quadrilateral) {
    let path = quad.path
    path.close()
    path.lineWidth = 1
    color.rawValue.setStroke()
    path.stroke()
  }
}

extension QuadView.Color: RawRepresentable {
  typealias RawValue = UIColor
  
  init?(rawValue: RawValue) {
    switch rawValue {
    case UIColor.white: self = .valid
    case UIColor.red: self = .invalid
    default: return nil
    }
  }
  
  var rawValue: RawValue {
    switch self {
    case .valid: return UIColor.white
    case .invalid: return UIColor.red
    }
  }
}

extension UIColor {
  static var lightishBlue: UIColor {
    return UIColor(
      red: 68.0 / 255.0,
      green: 116.0 / 255.0,
      blue: 1.0,
      alpha: 1.0)
  }
  
  static var vermillion: UIColor {
    return UIColor(
      red: 254.0 / 255.0,
      green: 36.0 / 255.0,
      blue: 10.0 / 255.0,
      alpha: 1.0)
  }
}
