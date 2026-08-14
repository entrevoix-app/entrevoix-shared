import Foundation

public enum ProviderAuthentication: String, Codable, CaseIterable, Sendable {
    case bearer
    case apiKey
    case none
}

public struct APIProviderConfiguration: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var baseURL: String
    public var path: String
    public var model: String
    public var authentication: ProviderAuthentication
    public var customHeaderName: String
    public var timeout: TimeInterval

    public init(
        id: UUID = UUID(), name: String, baseURL: String, path: String, model: String,
        authentication: ProviderAuthentication = .bearer,
        customHeaderName: String = "Authorization", timeout: TimeInterval = 60
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.path = path
        self.model = model
        self.authentication = authentication
        self.customHeaderName = customHeaderName
        self.timeout = timeout
    }

    public var endpointURL: URL? {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: base),
              components.scheme == "https" || components.scheme == "http"
        else { return nil }
        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if ["audio/transcriptions", "responses", "chat/completions"].contains(suffix.lowercased()),
           !path.split(separator: "/").contains("v1"), !path.hasSuffix(suffix) {
            path = path.isEmpty ? "v1" : "\(path)/v1"
        }
        if !path.hasSuffix(suffix) { path = path.isEmpty ? suffix : "\(path)/\(suffix)" }
        components.path = "/" + path
        return components.url
    }
}

public struct MacWorkerDescriptor: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var displayName: String
    public var appVersion: String
    public var protocolVersion: Int
    public var capabilities: WorkerCapabilities
    public var lastSeenAt: Date

    public init(
        id: String, displayName: String, appVersion: String, protocolVersion: Int = 1,
        capabilities: WorkerCapabilities, lastSeenAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.appVersion = appVersion
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.lastSeenAt = lastSeenAt
    }

    public func isAvailable(at date: Date, freshness: TimeInterval = 120) -> Bool {
        date.timeIntervalSince(lastSeenAt) <= freshness
    }
}

public struct WorkerCapabilities: Codable, Equatable, Sendable {
    public var supportsTranscription: Bool
    public var supportsCleanup: Bool
    public var favoriteLanguageCodes: [String]

    public init(
        supportsTranscription: Bool = true,
        supportsCleanup: Bool = true,
        favoriteLanguageCodes: [String] = []
    ) {
        self.supportsTranscription = supportsTranscription
        self.supportsCleanup = supportsCleanup
        self.favoriteLanguageCodes = favoriteLanguageCodes
    }
}

public enum STTProviderKind: Codable, Equatable, Sendable {
    case api(APIProviderConfiguration)
    case mac(MacWorkerDescriptor)
}

public struct STTProviderProfile: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var kind: STTProviderKind

    public init(id: UUID = UUID(), name: String, kind: STTProviderKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public enum CleanupProviderKind: Codable, Equatable, Sendable {
    case api(APIProviderConfiguration, format: CleanupAPIFormat)
    case mac(MacWorkerDescriptor)
}

public enum CleanupAPIFormat: String, Codable, Sendable {
    case responses
    case chatCompletions
}

public struct CleanupProviderProfile: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var kind: CleanupProviderKind

    public init(id: UUID = UUID(), name: String, kind: CleanupProviderKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public struct AudioFile: Equatable, Sendable {
    public let url: URL
    public let fileName: String
    public let mimeType: String

    public init(url: URL, fileName: String, mimeType: String) {
        self.url = url
        self.fileName = fileName
        self.mimeType = mimeType
    }
}
