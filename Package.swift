// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FocusBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FocusBar", targets: ["FocusBar"]),
        .library(name: "FocusCore", targets: ["FocusCore"]),
    ],
    targets: [
        // 純邏輯：計時狀態機、統計、持久化。不依賴 UI，可注入時鐘。
        .target(name: "FocusCore"),
        // 選單列 App：SwiftUI + 少量 AppKit / Carbon。
        .executableTarget(name: "FocusBar", dependencies: ["FocusCore"]),
        .testTarget(name: "FocusCoreTests", dependencies: ["FocusCore"]),
    ]
)
