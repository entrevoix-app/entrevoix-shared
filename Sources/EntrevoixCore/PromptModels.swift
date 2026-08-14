import Foundation

public struct SyncedPrompt: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var systemImageName: String
    public var instructions: String
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(), name: String, systemImageName: String,
        instructions: String, updatedAt: Date = .now, deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.systemImageName = systemImageName
        self.instructions = instructions
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public enum PromptValidationError: Error, Equatable, Sendable {
    case emptyName
    case emptyInstructions
    case duplicateName
}

public enum PromptRules {
    public static func validate(_ prompt: SyncedPrompt, against existing: [SyncedPrompt]) -> Result<SyncedPrompt, PromptValidationError> {
        let name = prompt.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let instructions = prompt.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .failure(.emptyName) }
        guard !instructions.isEmpty else { return .failure(.emptyInstructions) }
        let normalized = name.filter { !$0.isWhitespace }.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !existing.contains(where: { $0.id != prompt.id && $0.deletedAt == nil && $0.name.filter { !$0.isWhitespace }.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalized }) else {
            return .failure(.duplicateName)
        }
        var result = prompt
        result.name = name
        result.instructions = instructions
        result.updatedAt = .now
        result.deletedAt = nil
        return .success(result)
    }
}
