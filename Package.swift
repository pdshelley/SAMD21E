// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ATSAMD21E18",
  products: [
    .executable(name: "Application", targets: ["Application"])
  ],
  targets: [
    .executableTarget(name: "Application"),
  ],
  swiftLanguageModes: [.v5])
