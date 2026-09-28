// 產生 App 圖示：純色圓角方塊 + 白色 SF Symbol "timer"。
// 用法：swift scripts/make-icon.swift <輸出的 .iconset 資料夾>
import AppKit

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <out.iconset>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// NSBitmapImageRep 以「像素」為單位，避免 Retina 螢幕把尺寸翻倍。
func render(size: Int) -> Data {
    let s = CGFloat(size)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return Data() }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    defer { NSGraphicsContext.restoreGraphicsState() }
    do {
        let rect = NSRect(x: 0, y: 0, width: s, height: s)
        // Apple 圖示範本：內容區約佔 80%，四周留白。
        let inset = s * 0.098
        let body = rect.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
        NSColor(srgbRed: 0.851, green: 0.294, blue: 0.231, alpha: 1).setFill()
        path.fill()

        let config = NSImage.SymbolConfiguration(pointSize: s * 0.48, weight: .regular)
        if let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let tinted = NSImage(size: symbol.size, flipped: false) { r in
                symbol.draw(in: r)
                NSColor.white.set()
                r.fill(using: .sourceIn)
                return true
            }
            let target = NSRect(x: (s - tinted.size.width) / 2, y: (s - tinted.size.height) / 2,
                                width: tinted.size.width, height: tinted.size.height)
            tinted.draw(in: target)
        }
    }
    return rep.representation(using: .png, properties: [:]) ?? Data()
}

// iconutil 需要的檔名與尺寸
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in entries {
    try render(size: px).write(to: outDir.appendingPathComponent(name))
}
