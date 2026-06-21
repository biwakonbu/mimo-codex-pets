import ApplicationServices
import Foundation

struct Options {
    var pid: pid_t?
    var timeout = 8.0
    var identifier = "MimoDesktopPet.productionSurface"
    var requiredValueFragments: [String] = []
    var requiredChildValues: [String] = []
    var requiredChildDescriptions: [String] = []
    var requiredIdentifiers: [String] = []
    var requiredIdentifierDescriptionFragments: [(identifier: String, fragment: String)] = []
    var requiredIdentifierValueFragments: [(identifier: String, fragment: String)] = []
    var minimumRoleCounts: [String: Int] = [:]
}

struct AXNode {
    let role: String
    let identifier: String
    let description: String
    let value: String
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
        case "--pid":
            guard let value = arguments.first, let pid = Int32(value) else {
                fail("--pid requires an integer value")
            }
            options.pid = pid_t(pid)
            arguments.removeFirst()
        case "--timeout":
            guard let value = arguments.first, let timeout = Double(value) else {
                fail("--timeout requires a numeric value")
            }
            options.timeout = timeout
            arguments.removeFirst()
        case "--identifier":
            guard let value = arguments.first else { fail("--identifier requires a value") }
            options.identifier = value
            arguments.removeFirst()
        case "--value-contains":
            guard let value = arguments.first else { fail("--value-contains requires a value") }
            options.requiredValueFragments.append(value)
            arguments.removeFirst()
        case "--child-value":
            guard let value = arguments.first else { fail("--child-value requires a value") }
            options.requiredChildValues.append(value)
            arguments.removeFirst()
        case "--child-description":
            guard let value = arguments.first else { fail("--child-description requires a value") }
            options.requiredChildDescriptions.append(value)
            arguments.removeFirst()
        case "--node-identifier":
            guard let value = arguments.first else { fail("--node-identifier requires a value") }
            options.requiredIdentifiers.append(value)
            arguments.removeFirst()
        case "--node-description-contains":
            guard let value = arguments.first else { fail("--node-description-contains requires IDENTIFIER=FRAGMENT") }
            let parts = value.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                fail("--node-description-contains requires IDENTIFIER=FRAGMENT")
            }
            options.requiredIdentifierDescriptionFragments.append((identifier: parts[0], fragment: parts[1]))
            arguments.removeFirst()
        case "--node-value-contains":
            guard let value = arguments.first else { fail("--node-value-contains requires IDENTIFIER=FRAGMENT") }
            let parts = value.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                fail("--node-value-contains requires IDENTIFIER=FRAGMENT")
            }
            options.requiredIdentifierValueFragments.append((identifier: parts[0], fragment: parts[1]))
            arguments.removeFirst()
        case "--minimum-role-count":
            guard let value = arguments.first else { fail("--minimum-role-count requires ROLE:COUNT") }
            let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2, let count = Int(parts[1]), count >= 0 else {
                fail("--minimum-role-count requires ROLE:COUNT")
            }
            options.minimumRoleCounts[parts[0]] = count
            arguments.removeFirst()
        default:
            fail("unknown argument: \(argument)")
        }
    }

    guard options.pid != nil else {
        fail("--pid is required")
    }
    return options
}

func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard error == .success, let value else { return "" }
    return String(describing: value)
}

func children(of element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
    guard error == .success else { return [] }
    return value as? [AXUIElement] ?? []
}

func nodes(from element: AXUIElement, maxDepth: Int = 8) -> [AXNode] {
    var result: [AXNode] = []
    var queue: [(AXUIElement, Int)] = [(element, 0)]

    while !queue.isEmpty {
        let (current, depth) = queue.removeFirst()
        result.append(AXNode(
            role: stringAttribute(current, kAXRoleAttribute),
            identifier: stringAttribute(current, "AXIdentifier"),
            description: stringAttribute(current, kAXDescriptionAttribute),
            value: stringAttribute(current, kAXValueAttribute)
        ))

        guard depth < maxDepth else { continue }
        for child in children(of: current) {
            queue.append((child, depth + 1))
        }
    }

    return result
}

func windows(for pid: pid_t) -> [AXUIElement] {
    let app = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
    guard error == .success else { return [] }
    return value as? [AXUIElement] ?? []
}

func describe(_ nodes: [AXNode]) -> String {
    nodes.map { node in
        "role=\(node.role),id=\(node.identifier),description=\(node.description),value=\(node.value)"
    }
    .joined(separator: "\n")
}

let options = parseOptions()
let pid = options.pid!
let deadline = Date().addingTimeInterval(options.timeout)
var lastNodes: [AXNode] = []

while Date() < deadline {
    let allNodes = windows(for: pid).flatMap { nodes(from: $0) }
    lastNodes = allNodes

    if let surface = allNodes.first(where: { $0.identifier == options.identifier }) {
        let missingValueFragments = options.requiredValueFragments.filter { !surface.value.contains($0) }
        if !missingValueFragments.isEmpty {
            fail("accessibility surface value is missing fragments \(missingValueFragments): \(surface.value)")
        }

        let missingChildValues = options.requiredChildValues.filter { required in
            !allNodes.contains { $0.value == required }
        }
        if !missingChildValues.isEmpty {
            fail("accessibility tree is missing child values \(missingChildValues):\n\(describe(allNodes))")
        }

        let missingChildDescriptions = options.requiredChildDescriptions.filter { required in
            !allNodes.contains { $0.description == required }
        }
        if !missingChildDescriptions.isEmpty {
            fail("accessibility tree is missing child descriptions \(missingChildDescriptions):\n\(describe(allNodes))")
        }

        let missingIdentifiers = options.requiredIdentifiers.filter { required in
            !allNodes.contains { $0.identifier == required }
        }
        if !missingIdentifiers.isEmpty {
            fail("accessibility tree is missing identifiers \(missingIdentifiers):\n\(describe(allNodes))")
        }

        for requirement in options.requiredIdentifierDescriptionFragments {
            guard let node = allNodes.first(where: { $0.identifier == requirement.identifier }) else {
                fail("accessibility tree is missing identifier \(requirement.identifier):\n\(describe(allNodes))")
            }
            if !node.description.contains(requirement.fragment) {
                fail("accessibility node \(requirement.identifier) description is missing fragment \(requirement.fragment): \(node.description)\n\(describe(allNodes))")
            }
        }

        for requirement in options.requiredIdentifierValueFragments {
            guard let node = allNodes.first(where: { $0.identifier == requirement.identifier }) else {
                fail("accessibility tree is missing identifier \(requirement.identifier):\n\(describe(allNodes))")
            }
            if !node.value.contains(requirement.fragment) {
                fail("accessibility node \(requirement.identifier) value is missing fragment \(requirement.fragment): \(node.value)\n\(describe(allNodes))")
            }
        }

        for (role, minimumCount) in options.minimumRoleCounts {
            let count = allNodes.filter { $0.role == role }.count
            if count < minimumCount {
                fail("accessibility tree role \(role) count \(count) was below \(minimumCount):\n\(describe(allNodes))")
            }
        }

        print("Accessibility surface inspection passed: id=\(surface.identifier), value=\(surface.value)")
        exit(0)
    }

    Thread.sleep(forTimeInterval: 0.15)
}

fail("accessibility surface \(options.identifier) was not found:\n\(describe(lastNodes))")
