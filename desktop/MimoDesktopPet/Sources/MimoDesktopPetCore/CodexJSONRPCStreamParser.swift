import Foundation

public struct CodexJSONRPCStreamParser: Sendable {
    public enum Framing: Equatable, Sendable {
        case undecided
        case jsonLines
        case contentLength
    }

    public enum StreamError: Error, Equatable, Sendable {
        case invalidContentLengthHeader
    }

    public private(set) var framing: Framing
    private var buffer: Data

    public init(framing: Framing = .undecided) {
        self.framing = framing
        buffer = Data()
    }

    public mutating func append(_ data: Data) throws -> [Data] {
        guard !data.isEmpty else { return [] }
        buffer.append(data)

        var messages: [Data] = []
        while true {
            switch framing {
            case .undecided:
                guard decideFramingIfPossible() else { return messages }
            case .jsonLines:
                guard let message = consumeJSONLine() else { return messages }
                if !message.isEmpty {
                    messages.append(message)
                }
            case .contentLength:
                guard let message = try consumeContentLengthMessage() else { return messages }
                messages.append(message)
            }
        }
    }

    public mutating func reset(framing: Framing = .undecided) {
        self.framing = framing
        buffer.removeAll()
    }

    private mutating func decideFramingIfPossible() -> Bool {
        guard !buffer.isEmpty else { return false }
        if startsWithContentLengthPrefix() {
            framing = .contentLength
            return true
        }
        if couldStillBeContentLengthPrefix() {
            return false
        }
        framing = .jsonLines
        return true
    }

    private mutating func consumeJSONLine() -> Data? {
        guard let newlineIndex = buffer.firstIndex(of: 0x0A) else { return nil }
        var lineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
        buffer.removeSubrange(buffer.startIndex...newlineIndex)
        if lineData.last == 0x0D {
            lineData.removeLast()
        }
        return lineData
    }

    private mutating func consumeContentLengthMessage() throws -> Data? {
        let headerSeparator = Data([0x0D, 0x0A, 0x0D, 0x0A])
        guard let headerRange = buffer.range(of: headerSeparator) else { return nil }

        let headerData = buffer.subdata(in: buffer.startIndex..<headerRange.lowerBound)
        guard
            let headerText = String(data: headerData, encoding: .utf8),
            let contentLength = Self.parseContentLength(from: headerText)
        else {
            throw StreamError.invalidContentLengthHeader
        }

        let bodyStart = headerRange.upperBound
        let bodyEnd = bodyStart + contentLength
        guard buffer.count >= bodyEnd else { return nil }

        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        buffer.removeSubrange(buffer.startIndex..<bodyEnd)
        return body
    }

    private func startsWithContentLengthPrefix() -> Bool {
        let prefix = Self.contentLengthHeaderPrefix
        guard buffer.count >= prefix.count else { return false }
        return Self.asciiLowercased(Array(buffer.prefix(prefix.count))) == prefix
    }

    private func couldStillBeContentLengthPrefix() -> Bool {
        let prefix = Self.contentLengthHeaderPrefix
        let bytes = Self.asciiLowercased(Array(buffer.prefix(prefix.count)))
        guard bytes.count < prefix.count else { return false }
        return zip(bytes, prefix).allSatisfy { $0 == $1 }
    }

    private static let contentLengthHeaderPrefix = Array("content-length".utf8)

    private static func parseContentLength(from headerText: String) -> Int? {
        for line in headerText.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length"
            else {
                continue
            }
            return Int(parts[1].trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func asciiLowercased(_ bytes: [UInt8]) -> [UInt8] {
        bytes.map { byte in
            if byte >= 0x41, byte <= 0x5A {
                return byte + 0x20
            }
            return byte
        }
    }
}
