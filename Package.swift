// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "UNIScanLib",
  platforms: [
    .iOS(.v12),
    .macOS(SupportedPlatform.MacOSVersion.v10_15)
  ],
  products: [
    .library(
      name: "UNIScanLib",
      targets: ["UNIScanLib"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "UNIScanLib",
      dependencies: []),
  ]
)
