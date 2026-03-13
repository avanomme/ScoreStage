import Foundation
import SwiftData

public enum SyncStatus: String, Codable, Sendable {
    case pending
    case syncing
    case synced
    case conflict
    case error
}

@Model
public final class SyncRecord {
    public var id: UUID
    public var entityType: String
    public var entityID: UUID
    public var status: SyncStatus
    public var lastSyncedAt: Date?
    public var cloudRecordID: String?
    public var conflictData: Data?
    public var createdAt: Date

    public init(entityType: String, entityID: UUID) {
        self.id = UUID()
        self.entityType = entityType
        self.entityID = entityID
        self.status = .pending
        self.createdAt = Date()
    }
}
