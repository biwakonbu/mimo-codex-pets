import Foundation

public struct CommandInvocation: Equatable, Sendable {
    public let executableURL: URL
    public let argumentsPrefix: [String]

    public init(executableURL: URL, argumentsPrefix: [String]) {
        self.executableURL = executableURL
        self.argumentsPrefix = argumentsPrefix
    }
}

public enum CodexCommandLocator {
    public static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment) -> CommandInvocation {
        if let explicit = explicitCodexExecutablePath(environment: environment) {
            return CommandInvocation(executableURL: URL(fileURLWithPath: explicit), argumentsPrefix: [])
        }

        let home = environment["HOME"] ?? NSHomeDirectory()
        let standalonePath = "\(home)/.codex/packages/standalone/current/codex"
        if FileManager.default.isExecutableFile(atPath: standalonePath) {
            return CommandInvocation(executableURL: URL(fileURLWithPath: standalonePath), argumentsPrefix: [])
        }

        return CommandInvocation(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            argumentsPrefix: ["codex"]
        )
    }

    public static func launchEnvironment(base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = base
        let home = environment["HOME"] ?? NSHomeDirectory()
        let extraPath = [
            "\(home)/.volta/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")

        if let existing = environment["PATH"], !existing.isEmpty {
            environment["PATH"] = "\(extraPath):\(existing)"
        } else {
            environment["PATH"] = extraPath
        }
        return environment
    }

    private static func explicitCodexExecutablePath(environment: [String: String]) -> String? {
        for key in ["MIMO_CODEX_EXECUTABLE", "CODEX_BIN"] {
            guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                continue
            }
            return value
        }
        return nil
    }
}
