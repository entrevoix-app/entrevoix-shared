import Foundation

public protocol PromptRepository: Sendable {
    func list() async throws -> [SyncedPrompt]
    func save(_ prompt: SyncedPrompt) async throws
    func delete(id: UUID) async throws
}

public protocol DictationJobRepository: Sendable {
    func create(_ job: DictationJob, audio: AudioFile?) async throws
    func get(id: UUID) async throws -> DictationJob?
    func pendingJobs(for workerID: String) async throws -> [DictationJob]
    func update(_ job: DictationJob) async throws
}

public protocol WorkerDirectory: Sendable {
    func workers() async throws -> [MacWorkerDescriptor]
}

public protocol SpeechTranscribing: Sendable {
    func transcribe(audio: AudioFile, configuration: APIProviderConfiguration, apiKey: String, prompt: String?, language: String?) async throws -> String
}

public protocol TextCleaning: Sendable {
    func clean(text: String, configuration: APIProviderConfiguration, apiKey: String, format: CleanupAPIFormat, prompt: String) async throws -> String
}

public protocol AudioRecording: Sendable {
    func prepareSession() async throws
    func start() async throws
    func stop() async throws -> AudioFile
    func cancel()
}

public protocol KeyboardSessionCommunicating: Sendable {
    func readState() async -> KeyboardSessionState
    func writeCommand(_ command: KeyboardCommand) async throws
}

public enum KeyboardSessionState: String, Codable, Sendable {
    case sessionInactive
    case ready
    case recording
    case processing
    case completed
    case failed
}

public enum KeyboardCommand: Codable, Sendable {
    case prepare
    case startRecording(sessionID: UUID)
    case stopRecording(sessionID: UUID)
    case cancel(sessionID: UUID)
    case openSettings
}
