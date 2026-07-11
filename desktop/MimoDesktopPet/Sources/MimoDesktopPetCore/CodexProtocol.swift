import Foundation

public enum CodexTimestampParser {
    public static func decodeIfPresent(from decoder: Decoder) -> Date? {
        guard let container = try? decoder.singleValueContainer() else { return nil }
        if let string = try? container.decode(String.self) {
            return date(from: string)
        }
        if let number = try? container.decode(Double.self) {
            return date(from: number)
        }
        return nil
    }

    public static func date(from string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: string) {
            return date
        }

        return Double(string.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap(date(from:))
    }

    public static func date(from number: Double) -> Date? {
        guard number.isFinite else { return nil }
        let seconds = abs(number) >= 100_000_000_000 ? number / 1_000 : number
        return Date(timeIntervalSince1970: seconds)
    }
}

public enum CodexThreadActiveFlag: String, Codable, Equatable, Sendable {
    case waitingOnApproval
    case waitingOnUserInput
}

public enum CodexThreadStatus: Equatable, Sendable {
    case notLoaded
    case idle
    case systemError
    case active(activeFlags: [CodexThreadActiveFlag])
}

extension CodexThreadStatus: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case activeFlags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "notLoaded":
            self = .notLoaded
        case "idle":
            self = .idle
        case "systemError":
            self = .systemError
        case "active":
            let rawFlags = (try? container.decodeIfPresent([String].self, forKey: .activeFlags)) ?? []
            let flags = rawFlags.compactMap(CodexThreadActiveFlag.init(rawValue:))
            self = .active(activeFlags: flags)
        default:
            self = .idle
        }
    }
}

public enum CodexTurnStatus: String, Codable, Equatable, Sendable {
    case completed
    case interrupted
    case failed
    case inProgress
}

extension CodexTurnStatus {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CodexTurnStatus(rawValue: rawValue) ?? .inProgress
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct CodexTurnSnapshot: Decodable, Equatable, Sendable {
    public let id: String
    public let status: CodexTurnStatus
    public let startedAt: Date?
    public let completedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case startedAt
        case completedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decodeIfPresent(CodexTurnStatus.self, forKey: .status) ?? .inProgress
        startedAt = Self.decodeDate(.startedAt, from: container)
        completedAt = Self.decodeDate(.completedAt, from: container)
    }

    private static func decodeDate(
        _ key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> Date? {
        guard container.contains(key), let decoder = try? container.superDecoder(forKey: key) else {
            return nil
        }
        return CodexTimestampParser.decodeIfPresent(from: decoder)
    }
}

public struct CodexThreadSnapshot: Decodable, Equatable, Sendable {
    public let id: String
    public let isEphemeral: Bool
    public let status: CodexThreadStatus
    public let turns: [CodexTurnSnapshot]
    public let createdAt: Date?
    public let updatedAt: Date?
    public let recencyAt: Date?

    public var lastActivityDate: Date? {
        recencyAt ?? updatedAt ?? turns.last?.completedAt ?? turns.last?.startedAt ?? createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ephemeral
        case status
        case turns
        case createdAt
        case updatedAt
        case recencyAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        isEphemeral = try container.decodeIfPresent(Bool.self, forKey: .ephemeral) ?? false
        status = try container.decodeIfPresent(CodexThreadStatus.self, forKey: .status) ?? .idle
        turns = try container.decodeIfPresent([CodexTurnSnapshot].self, forKey: .turns) ?? []
        createdAt = Self.decodeDate(.createdAt, from: container)
        updatedAt = Self.decodeDate(.updatedAt, from: container)
        recencyAt = Self.decodeDate(.recencyAt, from: container)
    }

    private static func decodeDate(
        _ key: CodingKeys,
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> Date? {
        guard container.contains(key), let decoder = try? container.superDecoder(forKey: key) else {
            return nil
        }
        return CodexTimestampParser.decodeIfPresent(from: decoder)
    }
}

public enum CodexNotificationMethod: String, CaseIterable, Equatable, Sendable {
    case error = "error"
    case threadStarted = "thread/started"
    case threadStatusChanged = "thread/status/changed"
    case threadNameUpdated = "thread/name/updated"
    case threadGoalUpdated = "thread/goal/updated"
    case threadGoalCleared = "thread/goal/cleared"
    case threadArchived = "thread/archived"
    case threadClosed = "thread/closed"
    case threadDeleted = "thread/deleted"
    case threadUnarchived = "thread/unarchived"
    case threadCompacted = "thread/compacted"
    case hookStarted = "hook/started"
    case hookCompleted = "hook/completed"
    case turnStarted = "turn/started"
    case turnCompleted = "turn/completed"
    case turnPlanUpdated = "turn/plan/updated"
    case turnDiffUpdated = "turn/diff/updated"
    case turnModerationMetadata = "turn/moderationMetadata"
    case itemStarted = "item/started"
    case itemCompleted = "item/completed"
    case autoApprovalReviewStarted = "item/autoApprovalReview/started"
    case autoApprovalReviewCompleted = "item/autoApprovalReview/completed"
    case agentMessageDelta = "item/agentMessage/delta"
    case planDelta = "item/plan/delta"
    case reasoningSummaryPartAdded = "item/reasoning/summaryPartAdded"
    case reasoningSummaryTextDelta = "item/reasoning/summaryTextDelta"
    case reasoningTextDelta = "item/reasoning/textDelta"
    case commandExecutionOutputDelta = "item/commandExecution/outputDelta"
    case commandExecutionTerminalInteraction = "item/commandExecution/terminalInteraction"
    case fileChangeOutputDelta = "item/fileChange/outputDelta"
    case fileChangePatchUpdated = "item/fileChange/patchUpdated"
    case mcpToolCallProgress = "item/mcpToolCall/progress"
    case serverRequestResolved = "serverRequest/resolved"
    case mcpServerStartupStatusUpdated = "mcpServer/startupStatus/updated"
    case modelRerouted = "model/rerouted"
    case modelVerification = "model/verification"
    case warning = "warning"
    case guardianWarning = "guardianWarning"
}

public enum CodexIgnoredNotificationMethod: String, CaseIterable, Equatable, Sendable {
    case skillsChanged = "skills/changed"
    case threadSettingsUpdated = "thread/settings/updated"
    case threadTokenUsageUpdated = "thread/tokenUsage/updated"
    case commandExecOutputDelta = "command/exec/outputDelta"
    case processOutputDelta = "process/outputDelta"
    case processExited = "process/exited"
    case mcpServerOAuthLoginCompleted = "mcpServer/oauthLogin/completed"
    case accountUpdated = "account/updated"
    case accountRateLimitsUpdated = "account/rateLimits/updated"
    case appListUpdated = "app/list/updated"
    case remoteControlStatusChanged = "remoteControl/status/changed"
    case externalAgentConfigImportProgress = "externalAgentConfig/import/progress"
    case externalAgentConfigImportCompleted = "externalAgentConfig/import/completed"
    case modelSafetyBufferingUpdated = "model/safetyBuffering/updated"
    case fsChanged = "fs/changed"
    case deprecationNotice = "deprecationNotice"
    case configWarning = "configWarning"
    case fuzzyFileSearchSessionUpdated = "fuzzyFileSearch/sessionUpdated"
    case fuzzyFileSearchSessionCompleted = "fuzzyFileSearch/sessionCompleted"
    case threadRealtimeStarted = "thread/realtime/started"
    case threadRealtimeItemAdded = "thread/realtime/itemAdded"
    case threadRealtimeTranscriptDelta = "thread/realtime/transcript/delta"
    case threadRealtimeTranscriptDone = "thread/realtime/transcript/done"
    case threadRealtimeOutputAudioDelta = "thread/realtime/outputAudio/delta"
    case threadRealtimeSDP = "thread/realtime/sdp"
    case threadRealtimeError = "thread/realtime/error"
    case threadRealtimeClosed = "thread/realtime/closed"
    case windowsWorldWritableWarning = "windows/worldWritableWarning"
    case windowsSandboxSetupCompleted = "windowsSandbox/setupCompleted"
    case accountLoginCompleted = "account/login/completed"
}

public struct CodexJSONRPCNotification<Params: Decodable>: Decodable {
    public let method: String
    public let params: Params
}

public struct ThreadStatusChangedNotification: Decodable, Equatable, Sendable {
    public let threadId: String
    public let status: CodexThreadStatus
}

public struct ThreadStartedNotification: Decodable, Equatable, Sendable {
    public let thread: CodexThreadSnapshot
}

public struct ThreadIdNotification: Decodable, Equatable, Sendable {
    public let threadId: String
}

public struct ThreadNameUpdatedNotification: Decodable, Equatable, Sendable {
    public let threadId: String
    public let threadName: String?
}

public struct TurnNotification: Decodable, Equatable, Sendable {
    public let threadId: String
    public let turn: CodexTurnSnapshot
}

public struct ThreadTurnNotification: Decodable, Equatable, Sendable {
    public let threadId: String
    public let turnId: String?
}

public struct ItemLifecycleNotification: Decodable, Equatable, Sendable {
    public let threadId: String
    public let turnId: String
}

public struct ItemTextDeltaNotification: Decodable, Equatable, Sendable {
    public let threadId: String
    public let turnId: String
    public let itemId: String
    public let delta: String
}

public struct McpToolCallProgressNotification: Decodable, Equatable, Sendable {
    public let threadId: String
    public let turnId: String
    public let itemId: String
    public let message: String
}
