// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "TunnelKitEnvironment",
  platforms: [.iOS(.v15), .macOS(.v13)],
  products: [
    .library(name: "Tun2SocksKit", targets: ["Tun2SocksKit"]),
    .library(name: "Tun2SocksKitC", targets: ["Tun2SocksKitC"])
  ],
  targets: [
    .target(
      name: "Tun2SocksKit",
      dependencies: ["HevSocks5Tunnel", "Tun2SocksKitC"]
    ),
    .target(
      name: "Tun2SocksKitC",
      publicHeadersPath: "."
    ),
    .binaryTarget(
      name: "HevSocks5Tunnel",
      url: "https://github.com/PrimeGuardVPN/TunnelKitEnvironment/releases/download/1.0.5/HevSocks5Tunnel.xcframework.zip",
      checksum: "12779bee87068f2faad49a203036bbfd9b9b1a2c59af1dce0cba66fb8b82de19"
    )
  ]
)
