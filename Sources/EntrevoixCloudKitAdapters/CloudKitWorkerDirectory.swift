import CloudKit
import Foundation
import EntrevoixCore

public actor CloudKitWorkerDirectory: WorkerDirectory {
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    public init(container: CKContainer = EntrevoixCloudKitConfiguration.container()) {
        database = container.privateCloudDatabase
        zoneID = EntrevoixCloudKitConfiguration.zoneID()
    }

    public func workers() async throws -> [MacWorkerDescriptor] {
        let query = CKQuery(recordType: EntrevoixCloudKitConfiguration.workerRecordType, predicate: NSPredicate(value: true))
        let records: [CKRecord] = try await withCheckedThrowingContinuation { continuation in
            var values: [CKRecord] = []
            let operation = CKQueryOperation(query: query)
            operation.zoneID = zoneID
            operation.recordMatchedBlock = { _, result in if case .success(let record) = result { values.append(record) } }
            operation.queryResultBlock = { result in
                switch result { case .success: continuation.resume(returning: values); case .failure: continuation.resume(throwing: CloudKitAdapterError.operationFailed) }
            }
            database.add(operation)
        }
        return records.compactMap(decode)
    }

    public func publish(_ worker: MacWorkerDescriptor) async throws {
        let record = CKRecord(recordType: EntrevoixCloudKitConfiguration.workerRecordType, recordID: CKRecord.ID(recordName: worker.id, zoneID: zoneID))
        record["displayName"] = worker.displayName as CKRecordValue
        record["appVersion"] = worker.appVersion as CKRecordValue
        record["protocolVersion"] = worker.protocolVersion as CKRecordValue
        record["supportsTranscription"] = worker.capabilities.supportsTranscription as CKRecordValue
        record["supportsCleanup"] = worker.capabilities.supportsCleanup as CKRecordValue
        record["favoriteLanguageCodes"] = worker.capabilities.favoriteLanguageCodes as CKRecordValue
        record["lastSeenAt"] = worker.lastSeenAt as CKRecordValue
        _ = try await database.modifyRecords(saving: [record], deleting: [])
    }

    private func decode(_ record: CKRecord) -> MacWorkerDescriptor? {
        guard let displayName = record["displayName"] as? String,
              let appVersion = record["appVersion"] as? String,
              let protocolVersion = record["protocolVersion"] as? Int,
              let lastSeenAt = record["lastSeenAt"] as? Date
        else { return nil }
        return MacWorkerDescriptor(
            id: record.recordID.recordName,
            displayName: displayName,
            appVersion: appVersion,
            protocolVersion: protocolVersion,
            capabilities: WorkerCapabilities(
                supportsTranscription: record["supportsTranscription"] as? Bool ?? false,
                supportsCleanup: record["supportsCleanup"] as? Bool ?? false,
                favoriteLanguageCodes: record["favoriteLanguageCodes"] as? [String] ?? []
            ),
            lastSeenAt: lastSeenAt
        )
    }
}

public actor CloudKitZoneCoordinator {
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    public init(container: CKContainer = EntrevoixCloudKitConfiguration.container()) {
        database = container.privateCloudDatabase
        zoneID = EntrevoixCloudKitConfiguration.zoneID()
    }

    public func prepareZoneAndSubscriptions() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
        let zoneSubscription = CKRecordZoneSubscription(
            zoneID: zoneID,
            subscriptionID: "entrevoix-zone"
        )
        zoneSubscription.notificationInfo = CKSubscription.NotificationInfo()
        zoneSubscription.notificationInfo?.shouldSendContentAvailable = true
        zoneSubscription.notificationInfo?.desiredKeys = ["status", "targetWorkerID", "updatedAt"]
        do {
            _ = try await database.modifySubscriptions(saving: [zoneSubscription], deleting: [])
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // The subscription already exists; reconciliation remains authoritative.
        }
    }
}
