// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "SAMD21E",
  products: [
    .executable(name: "Application", targets: ["Application"])
  ],
  targets: [
    .executableTarget(name: "Application", dependencies: ["SAMD21E"]),
    .target(name: "Support"),
    .target(name: "SAMD21E", dependencies: ["Support"]),
  ],
  swiftLanguageModes: [.v5])
