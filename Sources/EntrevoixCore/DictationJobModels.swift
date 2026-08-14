import Foundation

public enum DictationJobKind: String, Codable, Sendable {
    case transcribe
    case cleanup
    case transcribeAndCleanup
}

public enum DictationJobStatus: String, Codable, Sendable {
    case pending
    case processing
    case completed
    case failed
    case cancelled
    case expired
}

public enum DictationFailureCode: String, Codable, Sendable, Error {
    case iCloudAccountUnavailable
    case cloudKitUnavailable
    case cloudAssetUploadFailed
    case cloudAssetDownloadFailed
    case macUnavailable
    case providerInvalid
    case providerUnauthorized
    case networkUnavailable
    case modelUnavailable
    case invalidAudio
    case transcriptionFailed
    case cleanupFailed
    case jobExpired
    case cancelled
}

public struct DictationOptions: Codable, Equatable, Sendable {
    public var languageCode: String?
    public var dictionaryTerms: [String]
    public var cleanupPromptID: UUID?
    public var cleanupPromptName: String?
    public var cleanupPromptInstructions: String?

    public init(
        languageCode: String? = nil, dictionaryTerms: [String] = [],
        cleanupPromptID: UUID? = nil, cleanupPromptName: String? = nil,
        cleanupPromptInstructions: String? = nil
    ) {
        self.languageCode = languageCode
        self.dictionaryTerms = dictionaryTerms
        self.cleanupPromptID = cleanupPromptID
        self.cleanupPromptName = cleanupPromptName
        self.cleanupPromptInstructions = cleanupPromptInstructions
    }
}

public struct DictationJob: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let workflowID: UUID
    public let targetWorkerID: String
    public let kind: DictationJobKind
    public var status: DictationJobStatus
    public let createdAt: Date
    public var updatedAt: Date
    public var expiresAt: Date
    public var options: DictationOptions
    public var inputTranscript: String?
    public var transcript: String?
    public var errorCode: DictationFailureCode?
    public var errorMessage: String?
    public var claimedBy: String?
    public var leaseExpiresAt: Date?
    public var attemptCount: Int
    public var clientAcknowledgedAt: Date?

    public init(
        id: UUID = UUID(), workflowID: UUID = UUID(), targetWorkerID: String,
        kind: DictationJobKind, options: DictationOptions, createdAt: Date = .now,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.workflowID = workflowID
        self.targetWorkerID = targetWorkerID
        self.kind = kind
        self.status = .pending
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.expiresAt = expiresAt ?? createdAt.addingTimeInterval(24 * 60 * 60)
        self.options = options
        self.inputTranscript = nil
        self.transcript = nil
        self.errorCode = nil
        self.errorMessage = nil
        self.claimedBy = nil
        self.leaseExpiresAt = nil
        self.attemptCount = 0
        self.clientAcknowledgedAt = nil
    }

    public mutating func claim(workerID: String, now: Date, lease: TimeInterval = 15 * 60) -> Bool {
        guard status == .pending || (status == .processing && (leaseExpiresAt ?? .distantFuture) < now) else { return false }
        status = .processing
        claimedBy = workerID
        leaseExpiresAt = now.addingTimeInterval(lease)
        attemptCount += 1
        updatedAt = now
        return true
    }

    public mutating func complete(transcript: String, now: Date) {
        guard status == .processing else { return }
        self.transcript = transcript
        status = .completed
        leaseExpiresAt = nil
        updatedAt = now
    }

    public mutating func fail(code: DictationFailureCode, message: String, now: Date) {
        guard status != .completed else { return }
        status = .failed
        errorCode = code
        errorMessage = message
        leaseExpiresAt = nil
        updatedAt = now
    }
}
