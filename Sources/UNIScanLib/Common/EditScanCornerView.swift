//
//  EditScanCornerView.swift
//  WeScan
//
//  Created by Boris Emorine on 3/5/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit

/// A UIView used by corners of a quadrilateral that is aware of its position.
final class EditScanCornerView: UIView {
  
  let position: CornerPosition
  private let circleView = UIView()
  
  init(frame: CGRect, position: CornerPosition) {
    self.position = position
    super.init(frame: frame)
    
    backgroundColor = UIColor.clear
    clipsToBounds = true
  }
  
  override var frame: CGRect {
    didSet {
      configureCircleView()
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    circleView.layer.cornerRadius = circleView.frame.width / 2.0
  }
  
  private func configureCircleView() {
    circleView.frame.size = CGSize(
      width: bounds.width / 2,
      height: bounds.height / 2
    )
    circleView.center = CGPoint(
      x: bounds.width / 2,
      y: bounds.height / 2
    )
    circleView.backgroundColor = .clear
    circleView.layer.borderWidth = 1
    circleView.layer.borderColor = UIColor.white.cgColor
    addSubview(circleView)
  }
}

/// A UIView used by edges of a quadrilateral that is aware of its position.
final class EditScanEdgeView: UIView {
  
  let position: EdgePosition
  private let circleView = UIView()
  
  init(frame: CGRect, position: EdgePosition) {
    self.position = position
    super.init(frame: frame)
    
    backgroundColor = UIColor.clear
    clipsToBounds = true
  }
  
  override var frame: CGRect {
    didSet {
      configureCircleView()
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    circleView.layer.cornerRadius = circleView.frame.width / 2.0
  }
  
  private func configureCircleView() {
    circleView.frame.size = CGSize(
      width: bounds.width / 2,
      height: bounds.height / 2
    )
    circleView.center = CGPoint(
      x: bounds.width / 2,
      y: bounds.height / 2
    )
    circleView.backgroundColor = UIColor.white
    addSubview(circleView)
  }
}
