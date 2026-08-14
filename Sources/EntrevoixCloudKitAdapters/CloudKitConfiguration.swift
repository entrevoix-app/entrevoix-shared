import CloudKit
import Foundation
import EntrevoixCore

public enum EntrevoixCloudKitConfiguration {
    public static let containerIdentifier = "iCloud.com.d9beuD.Entrevoix"
    public static let zoneName = "EntrevoixZone"
    public static let promptRecordType = "EntrevoixPrompt"
    public static let workerRecordType = "EntrevoixWorker"
    public static let jobRecordType = "EntrevoixDictationJob"

    public static func container() -> CKContainer { CKContainer(identifier: containerIdentifier) }
    public static func zoneID() -> CKRecordZone.ID { CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName) }
}

public enum CloudKitAdapterError: Error, Equatable, Sendable {
    case accountUnavailable
    case recordNotFound
    case conflict
    case invalidRecord
    case operationFailed
}
