import AppKit
import CoreGraphics
import Foundation

struct Options {
    var ownerName = "MimoDesktopPet"
    var pid: Int?
    var timeout = 8.0
    var maxWidth: Double?
    var maxHeight: Double?
}

func fail(_ message: String) -> Never {
    fputs("\(message)\n", stderr)
    exit(1)
}

func parseOptions() -> Options {
    var options = Options()
    var arguments = Array(CommandLine.arguments.dropFirst())

    while !arguments.isEmpty {
        let argument = arguments.removeFirst()
        switch argument {
        case "--owner-name":
            guard let value = arguments.first else { fail("--owner-name requires a value") }
            options.ownerName = value
            arguments.removeFirst()
        case "--pid":
            guard let value = arguments.first, let pid = Int(value) else { fail("--pid requires an integer value") }
            options.pid = pid
            arguments.removeFirst()
        case "--timeout":
            guard let value = arguments.first, let timeout = Double(value) else { fail("--timeout requires a numeric value") }
            options.timeout = timeout
            arguments.removeFirst()
        case "--max-width":
            guard let value = arguments.first, let width = Double(value) else { fail("--max-width requires a numeric value") }
            options.maxWidth = width
            arguments.removeFirst()
        case "--max-height":
            guard let value = arguments.first, let height = Double(value) else { fail("--max-height requires a numeric value") }
            options.maxHeight = height
            arguments.removeFirst()
        default:
            fail("unknown argument: \(argument)")
        }
    }

    return options
}

func number(from any: Any?) -> Double? {
    switch any {
    case let value as Double:
        return value
    case let value as Int:
        return Double(value)
    case let value as CGFloat:
        return Double(value)
    default:
        return nil
    }
}

let options = parseOptions()
let expectedLayer = Int(CGWindowLevelForKey(.screenSaverWindow))
let deadline = Date().addingTimeInterval(options.timeout)
var lastCandidates: [String] = []

while Date() < deadline {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    let matchingName = windows.filter {
        ($0[kCGWindowOwnerName as String] as? String ?? "") == options.ownerName
    }
    lastCandidates = matchingName.map { window in
        let id = window[kCGWindowNumber as String] ?? "?"
        let pid = window[kCGWindowOwnerPID as String] ?? "?"
        let layer = window[kCGWindowLayer as String] ?? "?"
        let bounds = window[kCGWindowBounds as String] ?? [:]
        return "id=\(id),pid=\(pid),layer=\(layer),bounds=\(bounds)"
    }

    let candidates = matchingName.filter { window in
        guard let pid = options.pid else { return true }
        return (window[kCGWindowOwnerPID as String] as? Int) == pid
    }

    if let window = candidates.first,
       let id = window[kCGWindowNumber as String],
       let layer = window[kCGWindowLayer as String] as? Int,
       let bounds = window[kCGWindowBounds as String] as? [String: Any] {
        guard layer == expectedLayer else {
            fail("unexpected Mimo window layer \(layer), expected screen-saver layer \(expectedLayer)")
        }
        if let maxWidth = options.maxWidth,
           let width = number(from: bounds["Width"]),
           width > maxWidth {
            fail("unexpected production window width \(width), max \(maxWidth)")
        }
        if let maxHeight = options.maxHeight,
           let height = number(from: bounds["Height"]),
           height > maxHeight {
            fail("unexpected production window height \(height), max \(maxHeight)")
        }
        print(id)
        exit(0)
    }

    Thread.sleep(forTimeInterval: 0.25)
}

let pidText = options.pid.map { " pid=\($0)" } ?? ""
let candidatesText = lastCandidates.isEmpty ? "none" : lastCandidates.joined(separator: "; ")
fail("Mimo window not found for owner=\(options.ownerName)\(pidText); candidates=\(candidatesText)")
