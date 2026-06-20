import AppKit
import Foundation

struct CaptureStats {
    let width: Int
    let height: Int
    let alphaPixels: Int
    let opaquePixels: Int
    let whiteBubblePixels: Int
    let spriteColorPixels: Int
    let darkOpaquePixels: Int
    let opaqueCorners: Int

    var totalPixels: Int { width * height }
    var alphaRatio: Double { Double(alphaPixels) / Double(totalPixels) }
    var opaqueRatio: Double { Double(opaquePixels) / Double(totalPixels) }
}

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count == 2 else {
    fail("usage: swift script/inspect_production_capture.swift <window-capture.png>")
}

let path = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: path),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff)
else {
    fail("failed to load screenshot")
}

let width = bitmap.pixelsWide
let height = bitmap.pixelsHigh
guard width <= 900, height <= 900 else {
    fail("unexpected production window size \(width)x\(height)")
}

let cornerPoints = [
    (0, 0),
    (width - 1, 0),
    (0, height - 1),
    (width - 1, height - 1)
]
var opaqueCorners = 0
var alphaPixels = 0
var opaquePixels = 0
var whiteBubblePixels = 0
var spriteColorPixels = 0
var darkOpaquePixels = 0

for y in 0..<height {
    for x in 0..<width {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        let alpha = color.alphaComponent
        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent

        if alpha > 0.02 {
            alphaPixels += 1
        }
        if alpha > 0.8 {
            opaquePixels += 1
        }
        if alpha > 0.7, red > 0.88, green > 0.88, blue > 0.88 {
            whiteBubblePixels += 1
        }
        if alpha > 0.5,
           !(red > 0.88 && green > 0.88 && blue > 0.88),
           max(abs(red - green), abs(green - blue), abs(red - blue)) > 0.12 {
            spriteColorPixels += 1
        }
        if alpha > 0.7, red < 0.08, green < 0.08, blue < 0.08 {
            darkOpaquePixels += 1
        }
    }
}

for (x, y) in cornerPoints {
    let alpha = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 1
    if alpha > 0.02 {
        opaqueCorners += 1
    }
}

let stats = CaptureStats(
    width: width,
    height: height,
    alphaPixels: alphaPixels,
    opaquePixels: opaquePixels,
    whiteBubblePixels: whiteBubblePixels,
    spriteColorPixels: spriteColorPixels,
    darkOpaquePixels: darkOpaquePixels,
    opaqueCorners: opaqueCorners
)

guard stats.opaqueCorners <= 1 else {
    fail("too many opaque screenshot corners for transparent production surface: \(stats.opaqueCorners)")
}
guard stats.alphaRatio >= 0.06 else {
    fail("production capture is too empty: alphaRatio=\(stats.alphaRatio)")
}
guard stats.alphaRatio <= 0.55, stats.opaqueRatio <= 0.48 else {
    fail("production capture is too opaque for a transparent pet panel: alphaRatio=\(stats.alphaRatio), opaqueRatio=\(stats.opaqueRatio)")
}
guard stats.whiteBubblePixels >= 1_800 else {
    fail("production capture is missing white speech-bubble pixels: \(stats.whiteBubblePixels)")
}
guard stats.spriteColorPixels >= 350 else {
    fail("production capture is missing Mimo sprite color pixels: \(stats.spriteColorPixels)")
}
guard stats.darkOpaquePixels <= 1_500 else {
    fail("production capture has too much opaque dark fill for a transparent panel: \(stats.darkOpaquePixels)")
}

print(
    "Production capture inspection passed: " +
    "size=\(stats.width)x\(stats.height), " +
    "alphaRatio=\(String(format: "%.3f", stats.alphaRatio)), " +
    "whiteBubblePixels=\(stats.whiteBubblePixels), " +
    "spriteColorPixels=\(stats.spriteColorPixels)"
)
