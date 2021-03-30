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
  dependencies: [
    .package(
      url: "https://github.com/alexey-savchenko/UNILib.git",
      Package.Dependency.Requirement.branch("main")
    )
  ],
  targets: [
    .target(
      name: "UNIScanLib",
      dependencies: [
        .product(name: "UNILibCore", package: "UNILib")
      ]),
  ]
)
