import Darwin
import Foundation

public final class ProcessSingleInstanceLock: @unchecked Sendable {
    public let path: String
    private let fileDescriptor: Int32

    private init(path: String, fileDescriptor: Int32) {
        self.path = path
        self.fileDescriptor = fileDescriptor
    }

    deinit {
        _ = flock(fileDescriptor, LOCK_UN)
        _ = close(fileDescriptor)
    }

    public static func acquire(
        identifier: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        temporaryDirectory: String = NSTemporaryDirectory()
    ) -> ProcessSingleInstanceLock? {
        let path = lockPath(
            identifier: identifier,
            environment: environment,
            temporaryDirectory: temporaryDirectory
        )
        let fileDescriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else { return nil }

        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            _ = close(fileDescriptor)
            return nil
        }

        let pidText = "\(getpid())\n"
        _ = ftruncate(fileDescriptor, 0)
        if let data = pidText.data(using: .utf8) {
            data.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                _ = write(fileDescriptor, baseAddress, buffer.count)
            }
        }

        return ProcessSingleInstanceLock(path: path, fileDescriptor: fileDescriptor)
    }

    public static func lockPath(
        identifier: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        temporaryDirectory: String = NSTemporaryDirectory()
    ) -> String {
        if let override = environment["MIMO_SINGLE_INSTANCE_LOCK_PATH"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }

        let sanitizedIdentifier = identifier.map { character -> Character in
            if character.isLetter || character.isNumber || character == "." || character == "-" || character == "_" {
                return character
            }
            return "-"
        }
        .reduce(into: "") { result, character in
            result.append(character)
        }
        let directory = temporaryDirectory.hasSuffix("/") ? temporaryDirectory : temporaryDirectory + "/"
        return "\(directory)\(sanitizedIdentifier)-\(getuid()).lock"
    }
}
