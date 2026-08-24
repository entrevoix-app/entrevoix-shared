import CloudKit
import Foundation
import EntrevoixCore

public actor CloudKitPromptRepository: PromptRepository {
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    public init(container: CKContainer = EntrevoixCloudKitConfiguration.container()) {
        self.database = container.privateCloudDatabase
        self.zoneID = EntrevoixCloudKitConfiguration.zoneID()
    }

    public func list() async throws -> [SyncedPrompt] {
        let records = try await query(recordType: EntrevoixCloudKitConfiguration.promptRecordType)
        return records.compactMap(Self.decode).filter { $0.deletedAt == nil }
    }

    public func save(_ prompt: SyncedPrompt) async throws {
        let record = CKRecord(recordType: EntrevoixCloudKitConfiguration.promptRecordType, recordID: CKRecord.ID(recordName: prompt.id.uuidString, zoneID: zoneID))
        record["name"] = prompt.name as CKRecordValue
        record["systemImageName"] = prompt.systemImageName as CKRecordValue
        record["instructions"] = prompt.instructions as CKRecordValue
        record["updatedAt"] = prompt.updatedAt as CKRecordValue
        record["deletedAt"] = prompt.deletedAt as CKRecordValue?
        _ = try await database.modifyRecords(saving: [record], deleting: [])
    }

    public func delete(id: UUID) async throws {
        let prompt = SyncedPrompt(id: id, name: "", systemImageName: "doc.text", instructions: "", updatedAt: .now, deletedAt: .now)
        try await save(prompt)
    }

    private func query(recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        return try await withCheckedThrowingContinuation { continuation in
            var result: [CKRecord] = []
            let operation = CKQueryOperation(query: query)
            operation.zoneID = zoneID
            operation.recordMatchedBlock = { _, recordResult in if case .success(let record) = recordResult { result.append(record) } }
            operation.queryResultBlock = { queryResult in
                switch queryResult { case .success: continuation.resume(returning: result); case .failure: continuation.resume(throwing: CloudKitAdapterError.operationFailed) }
            }
            database.add(operation)
        }
    }

    private static func decode(_ record: CKRecord) -> SyncedPrompt? {
        guard let id = UUID(uuidString: record.recordID.recordName), let name = record["name"] as? String, let icon = record["systemImageName"] as? String, let instructions = record["instructions"] as? String, let updatedAt = record["updatedAt"] as? Date else { return nil }
        return SyncedPrompt(id: id, name: name, systemImageName: icon, instructions: instructions, updatedAt: updatedAt, deletedAt: record["deletedAt"] as? Date)
    }
}
