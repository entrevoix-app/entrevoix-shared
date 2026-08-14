import CloudKit
import Foundation
import EntrevoixCore

public actor CloudKitDictationJobRepository: DictationJobRepository {
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    public init(container: CKContainer = EntrevoixCloudKitConfiguration.container()) {
        self.database = container.privateCloudDatabase
        self.zoneID = EntrevoixCloudKitConfiguration.zoneID()
    }

    public func create(_ job: DictationJob, audio: AudioFile?) async throws {
        let record = encode(job)
        if let audio {
            record["audioAsset"] = CKAsset(fileURL: audio.url)
            record["audioFileName"] = audio.fileName as CKRecordValue
            record["audioMimeType"] = audio.mimeType as CKRecordValue
        }
        try await database.modifyRecords(saving: [record], deleting: [])
    }

    public func get(id: UUID) async throws -> DictationJob? {
        do { return decode(try await database.record(for: CKRecord.ID(recordName: id.uuidString, zoneID: zoneID))) }
        catch { return nil }
    }

    public func pendingJobs(for workerID: String) async throws -> [DictationJob] {
        let query = CKQuery(recordType: EntrevoixCloudKitConfiguration.jobRecordType, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "status == %@", DictationJobStatus.pending.rawValue), NSPredicate(format: "targetWorkerID == %@", workerID)]))
        let records = try await withCheckedThrowingContinuation { continuation in
            var result: [CKRecord] = []
            let operation = CKQueryOperation(query: query)
            operation.zoneID = zoneID
            operation.recordMatchedBlock = { _, recordResult in if case .success(let record) = recordResult { result.append(record) } }
            operation.queryResultBlock = { queryResult in
                switch queryResult { case .success: continuation.resume(returning: result); case .failure: continuation.resume(throwing: CloudKitAdapterError.operationFailed) }
            }
            database.add(operation)
        }
        return records.compactMap(decode)
    }

    public func update(_ job: DictationJob) async throws { try await database.modifyRecords(saving: [encode(job)], deleting: []) }

    private func encode(_ job: DictationJob) -> CKRecord {
        let record = CKRecord(recordType: EntrevoixCloudKitConfiguration.jobRecordType, recordID: CKRecord.ID(recordName: job.id.uuidString, zoneID: zoneID))
        record["workflowID"] = job.workflowID.uuidString as CKRecordValue
        record["targetWorkerID"] = job.targetWorkerID as CKRecordValue
        record["kind"] = job.kind.rawValue as CKRecordValue
        record["status"] = job.status.rawValue as CKRecordValue
        record["createdAt"] = job.createdAt as CKRecordValue
        record["updatedAt"] = job.updatedAt as CKRecordValue
        record["expiresAt"] = job.expiresAt as CKRecordValue
        record["languageCode"] = job.options.languageCode as CKRecordValue?
        record["dictionaryTerms"] = job.options.dictionaryTerms as CKRecordValue
        record["cleanupPromptID"] = job.options.cleanupPromptID?.uuidString as CKRecordValue?
        record["cleanupPromptName"] = job.options.cleanupPromptName as CKRecordValue?
        record["cleanupPromptInstructions"] = job.options.cleanupPromptInstructions as CKRecordValue?
        record["inputTranscript"] = job.inputTranscript as CKRecordValue?
        record["transcript"] = job.transcript as CKRecordValue?
        record["errorCode"] = job.errorCode?.rawValue as CKRecordValue?
        record["errorMessage"] = job.errorMessage as CKRecordValue?
        record["claimedBy"] = job.claimedBy as CKRecordValue?
        record["leaseExpiresAt"] = job.leaseExpiresAt as CKRecordValue?
        record["attemptCount"] = job.attemptCount as CKRecordValue
        record["clientAcknowledgedAt"] = job.clientAcknowledgedAt as CKRecordValue?
        return record
    }

    private func decode(_ record: CKRecord) -> DictationJob? {
        guard let workflowString = record["workflowID"] as? String, let workflowID = UUID(uuidString: workflowString), let target = record["targetWorkerID"] as? String, let kindString = record["kind"] as? String, let kind = DictationJobKind(rawValue: kindString), let statusString = record["status"] as? String, let status = DictationJobStatus(rawValue: statusString), let createdAt = record["createdAt"] as? Date, let updatedAt = record["updatedAt"] as? Date, let expiresAt = record["expiresAt"] as? Date else { return nil }
        var job = DictationJob(id: UUID(uuidString: record.recordID.recordName) ?? UUID(), workflowID: workflowID, targetWorkerID: target, kind: kind, options: DictationOptions(languageCode: record["languageCode"] as? String, dictionaryTerms: record["dictionaryTerms"] as? [String] ?? [], cleanupPromptID: (record["cleanupPromptID"] as? String).flatMap(UUID.init(uuidString:)), cleanupPromptName: record["cleanupPromptName"] as? String, cleanupPromptInstructions: record["cleanupPromptInstructions"] as? String), createdAt: createdAt, expiresAt: expiresAt)
        job.status = status; job.updatedAt = updatedAt; job.inputTranscript = record["inputTranscript"] as? String; job.transcript = record["transcript"] as? String; job.errorCode = (record["errorCode"] as? String).flatMap(DictationFailureCode.init(rawValue:)); job.errorMessage = record["errorMessage"] as? String; job.claimedBy = record["claimedBy"] as? String; job.leaseExpiresAt = record["leaseExpiresAt"] as? Date; job.attemptCount = record["attemptCount"] as? Int ?? 0; job.clientAcknowledgedAt = record["clientAcknowledgedAt"] as? Date
        return job
    }
}
