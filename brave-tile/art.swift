// Draw the tile's banner (320x180) and icon (192x192) from Brave's lion logo.
// Usage: swift art.swift <res dir> <logo png>
// The logo is Brave's own (brave/brave-core app/theme/brave/product_logo_256.png).
import AppKit

func png(_ w: Int, _ h: Int, _ path: String, _ draw: (CGRect) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    draw(CGRect(x: 0, y: 0, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let res = CommandLine.arguments[1]
let lion = NSImage(contentsOfFile: CommandLine.arguments[2])!

// Banner: the lion and the name, white on Brave's dark grey.
png(320, 180, "\(res)/drawable-xhdpi/banner.png") { r in
    NSColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1).setFill(); r.fill()
    lion.draw(in: CGRect(x: 28, y: 40, width: 100, height: 100))
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 54, weight: .bold), .foregroundColor: NSColor.white]
    ("Brave" as NSString).draw(at: CGPoint(x: 140, y: 56), withAttributes: a)
}
// Icon: the lion alone.
png(192, 192, "\(res)/mipmap-xxxhdpi/icon.png") { r in
    lion.draw(in: r.insetBy(dx: 12, dy: 12))
}
