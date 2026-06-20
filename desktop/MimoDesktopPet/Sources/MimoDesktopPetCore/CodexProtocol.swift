import Foundation

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

    private enum CodingKeys: String, CodingKey {
        case id
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decodeIfPresent(CodexTurnStatus.self, forKey: .status) ?? .inProgress
    }
}

public struct CodexThreadSnapshot: Decodable, Equatable, Sendable {
    public let id: String
    public let status: CodexThreadStatus
    public let turns: [CodexTurnSnapshot]

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case turns
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decodeIfPresent(CodexThreadStatus.self, forKey: .status) ?? .idle
        turns = try container.decodeIfPresent([CodexTurnSnapshot].self, forKey: .turns) ?? []
    }
}

public enum CodexNotificationMethod: String, CaseIterable, Equatable, Sendable {
    case threadStatusChanged = "thread/status/changed"
    case threadNameUpdated = "thread/name/updated"
    case threadArchived = "thread/archived"
    case threadClosed = "thread/closed"
    case threadDeleted = "thread/deleted"
    case threadUnarchived = "thread/unarchived"
    case turnStarted = "turn/started"
    case turnCompleted = "turn/completed"
    case turnPlanUpdated = "turn/plan/updated"
    case itemStarted = "item/started"
    case itemCompleted = "item/completed"
    case agentMessageDelta = "item/agentMessage/delta"
    case planDelta = "item/plan/delta"
    case reasoningSummaryPartAdded = "item/reasoning/summaryPartAdded"
    case reasoningSummaryTextDelta = "item/reasoning/summaryTextDelta"
    case reasoningTextDelta = "item/reasoning/textDelta"
    case commandExecutionOutputDelta = "item/commandExecution/outputDelta"
    case fileChangeOutputDelta = "item/fileChange/outputDelta"
    case mcpToolCallProgress = "item/mcpToolCall/progress"
}

public struct CodexJSONRPCNotification<Params: Decodable>: Decodable {
    public let method: String
    public let params: Params
}

public struct ThreadStatusChangedNotification: Decodable, Equatable, Sendable {
    public let threadId: String
    public let status: CodexThreadStatus
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
