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

struct WhiteComponent {
    let area: Int
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
    var centerX: Double { Double(minX + maxX) / 2.0 }
    var centerY: Double { Double(minY + maxY) / 2.0 }
}

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

let requiresMultiBubbleHierarchy = CommandLine.arguments.contains("--multi-bubble-hierarchy")
let positionalArguments = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }

guard positionalArguments.count == 1 else {
    fail("usage: swift script/inspect_production_capture.swift [--multi-bubble-hierarchy] <window-capture.png>")
}

let path = positionalArguments[0]
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
var whiteMask = [Bool](repeating: false, count: width * height)
var markerMask = [Bool](repeating: false, count: width * height)

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
            whiteMask[y * width + x] = true
        }
        if isMarkerColor(alpha: alpha, red: red, green: green, blue: blue) {
            markerMask[y * width + x] = true
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

if requiresMultiBubbleHierarchy {
    let components = whiteComponents(mask: whiteMask, width: width, height: height)
    let bubbleComponents = components.filter { component in
        component.area >= 3_000 &&
            component.width >= 150 &&
            component.height >= 22 &&
            component.maxY <= 245
    }

    guard (4...5).contains(bubbleComponents.count) else {
        fail("multi-thread capture should show four or five white bubble components, found \(bubbleComponents.count): \(describe(bubbleComponents))")
    }

    guard let primary = bubbleComponents.max(by: { $0.maxY < $1.maxY }) else {
        fail("multi-thread capture had no primary bubble candidate")
    }
    let secondaryComponents = bubbleComponents.filter {
        $0.minX != primary.minX || $0.minY != primary.minY || $0.maxX != primary.maxX || $0.maxY != primary.maxY
    }
    let maxSecondaryWidth = secondaryComponents.map(\.width).max() ?? 0
    let maxSecondaryArea = secondaryComponents.map(\.area).max() ?? 0
    let lowestSecondaryBottom = secondaryComponents.map(\.maxY).max() ?? 0

    guard primary.width >= maxSecondaryWidth + 50 else {
        fail("primary bubble is not visibly wider than secondary bubbles: primary=\(describe(primary)), secondary=\(describe(secondaryComponents))")
    }
    guard primary.area >= Int(Double(maxSecondaryArea) * 1.35) else {
        fail("primary bubble is not visibly more prominent than secondary bubbles: primary=\(describe(primary)), secondary=\(describe(secondaryComponents))")
    }
    guard primary.minY >= lowestSecondaryBottom + 6 else {
        fail("primary bubble is not separated below the secondary context bubbles: primary=\(describe(primary)), secondary=\(describe(secondaryComponents))")
    }
    let secondaryCentersX = secondaryComponents.map(\.centerX)
    let secondaryCentersY = secondaryComponents.map(\.centerY)
    guard
        secondaryCentersX.contains(where: { $0 <= primary.centerX - 36 }),
        secondaryCentersX.contains(where: { $0 >= primary.centerX + 36 })
    else {
        fail("secondary context chips are not fanned to both sides of the primary bubble: primary=\(describe(primary)), secondary=\(describe(secondaryComponents))")
    }
    let secondaryHorizontalSpread = (secondaryCentersX.max() ?? 0) - (secondaryCentersX.min() ?? 0)
    let secondaryVerticalSpread = (secondaryCentersY.max() ?? 0) - (secondaryCentersY.min() ?? 0)
    guard secondaryHorizontalSpread >= 120, secondaryVerticalSpread >= 70 else {
        fail("secondary context chips look like a collapsed feed instead of a fanned bubble cluster: horizontalSpread=\(secondaryHorizontalSpread), verticalSpread=\(secondaryVerticalSpread), secondary=\(describe(secondaryComponents))")
    }

    guard hasCenteredTailTaper(mask: whiteMask, width: width, component: primary) else {
        fail("primary bubble does not have a centered speech-tail taper: primary=\(describe(primary))")
    }

    for secondary in secondaryComponents {
        guard !hasCenteredTailTaper(mask: whiteMask, width: width, component: secondary) else {
            fail("secondary context chip unexpectedly has a speech-tail taper: secondary=\(describe(secondary))")
        }
    }

    var markerDescriptions: [String] = []
    for component in bubbleComponents {
        let markers = markerComponents(mask: markerMask, width: width, bounds: component)
        guard !markers.isEmpty else {
            fail("bubble is missing a compact activity/state marker: bubble=\(describe(component))")
        }
        markerDescriptions.append(describe(markers))
    }

    print(
        "Multi-bubble hierarchy inspection passed: " +
        "primary=\(describe(primary)), " +
        "secondary=\(describe(secondaryComponents)), " +
        "markers=\(markerDescriptions)"
    )
}

print(
    "Production capture inspection passed: " +
    "size=\(stats.width)x\(stats.height), " +
    "alphaRatio=\(String(format: "%.3f", stats.alphaRatio)), " +
    "whiteBubblePixels=\(stats.whiteBubblePixels), " +
    "spriteColorPixels=\(stats.spriteColorPixels)"
)

func whiteComponents(mask: [Bool], width: Int, height: Int) -> [WhiteComponent] {
    var visited = [Bool](repeating: false, count: mask.count)
    var components: [WhiteComponent] = []

    for startIndex in mask.indices {
        guard mask[startIndex], !visited[startIndex] else { continue }

        var queue = [startIndex]
        var cursor = 0
        visited[startIndex] = true

        let startX = startIndex % width
        let startY = startIndex / width
        var area = 0
        var minX = startX
        var maxX = startX
        var minY = startY
        var maxY = startY

        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1

            let x = index % width
            let y = index / width
            area += 1
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)

            let neighbors = [
                x > 0 ? index - 1 : nil,
                x + 1 < width ? index + 1 : nil,
                y > 0 ? index - width : nil,
                y + 1 < height ? index + width : nil
            ]

            for optionalNeighbor in neighbors {
                guard let neighbor = optionalNeighbor, mask[neighbor], !visited[neighbor] else {
                    continue
                }
                visited[neighbor] = true
                queue.append(neighbor)
            }
        }

        components.append(WhiteComponent(area: area, minX: minX, minY: minY, maxX: maxX, maxY: maxY))
    }

    return components
}

func describe(_ component: WhiteComponent) -> String {
    "area=\(component.area),x=\(component.minX)-\(component.maxX),y=\(component.minY)-\(component.maxY),size=\(component.width)x\(component.height)"
}

func describe(_ components: [WhiteComponent]) -> String {
    "[" + components.map(describe).joined(separator: "; ") + "]"
}

func isMarkerColor(alpha: CGFloat, red: CGFloat, green: CGFloat, blue: CGFloat) -> Bool {
    guard alpha > 0.55 else { return false }
    if red > 0.88, green > 0.88, blue > 0.88 {
        return false
    }
    if red < 0.12, green < 0.12, blue < 0.12 {
        return false
    }
    return max(abs(red - green), abs(green - blue), abs(red - blue)) > 0.05
}

func markerComponents(mask: [Bool], width: Int, bounds: WhiteComponent) -> [WhiteComponent] {
    let height = mask.count / width
    var visited = Set<Int>()
    var components: [WhiteComponent] = []
    let minX = max(0, bounds.minX)
    let maxX = min(width - 1, bounds.maxX)
    let minY = max(0, bounds.minY)
    let maxY = min(height - 1, bounds.maxY)

    for y in minY...maxY {
        for x in minX...maxX {
            let startIndex = y * width + x
            guard mask[startIndex], !visited.contains(startIndex) else { continue }

            var queue = [startIndex]
            var cursor = 0
            visited.insert(startIndex)

            var area = 0
            var componentMinX = x
            var componentMaxX = x
            var componentMinY = y
            var componentMaxY = y

            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1

                let currentX = index % width
                let currentY = index / width
                area += 1
                componentMinX = min(componentMinX, currentX)
                componentMaxX = max(componentMaxX, currentX)
                componentMinY = min(componentMinY, currentY)
                componentMaxY = max(componentMaxY, currentY)

                let neighbors = [
                    currentX > minX ? index - 1 : nil,
                    currentX < maxX ? index + 1 : nil,
                    currentY > minY ? index - width : nil,
                    currentY < maxY ? index + width : nil
                ]

                for optionalNeighbor in neighbors {
                    guard let neighbor = optionalNeighbor,
                          mask[neighbor],
                          !visited.contains(neighbor)
                    else {
                        continue
                    }
                    visited.insert(neighbor)
                    queue.append(neighbor)
                }
            }

            let component = WhiteComponent(
                area: area,
                minX: componentMinX,
                minY: componentMinY,
                maxX: componentMaxX,
                maxY: componentMaxY
            )
            if isCompactMarker(component) {
                components.append(component)
            }
        }
    }

    return components
}

func isCompactMarker(_ component: WhiteComponent) -> Bool {
    component.area >= 70 &&
        component.area <= 900 &&
        component.width >= 7 &&
        component.width <= 36 &&
        component.height >= 10 &&
        component.height <= 36
}

func hasCenteredTailTaper(mask: [Bool], width: Int, component: WhiteComponent) -> Bool {
    let centerX = (component.minX + component.maxX) / 2
    let startY = max(component.minY, component.maxY - 6)
    let endY = component.maxY
    var centeredNarrowRows = 0
    var previousSpanWidth: Int?

    for y in startY...endY {
        guard let span = whiteSpan(mask: mask, width: width, y: y, minX: component.minX, maxX: component.maxX) else {
            continue
        }
        let spanWidth = span.maxX - span.minX + 1
        let spanCenterX = (span.minX + span.maxX) / 2
        guard spanWidth >= 2, spanWidth <= 18, abs(spanCenterX - centerX) <= 8 else {
            continue
        }
        if let previousSpanWidth, spanWidth > previousSpanWidth + 8 {
            continue
        }
        centeredNarrowRows += 1
        previousSpanWidth = spanWidth
    }

    return centeredNarrowRows >= 3
}

func whiteSpan(mask: [Bool], width: Int, y: Int, minX: Int, maxX: Int) -> (minX: Int, maxX: Int)? {
    var first: Int?
    var last: Int?
    for x in minX...maxX where mask[y * width + x] {
        first = first ?? x
        last = x
    }
    guard let first, let last else { return nil }
    return (first, last)
}
