import Foundation
import SwiftData
import CoreDomain

/// Conflict resolution strategy for annotation sync.
public enum AnnotationConflictStrategy: String, CaseIterable, Sendable {
    case localWins = "Keep Local"
    case remoteWins = "Keep Remote"
    case merge = "Merge Both"
    case askUser = "Ask Each Time"
}

/// Sync status for individual annotation layers.
public enum LayerSyncStatus: Sendable {
    case synced
    case pendingUpload
    case pendingDownload
    case conflict
    case error(String)
}

/// Service for syncing annotation layers, strokes, and objects via CloudKit.
/// Extends the base CloudKitSyncService with annotation-specific logic.
@MainActor
@Observable
public final class AnnotationSyncService {
    public var conflictStrategy: AnnotationConflictStrategy = .merge
    public var layerSyncStatuses: [UUID: LayerSyncStatus] = [:]
    public var pendingConflicts: [AnnotationConflict] = []
    public var isSyncing = false
    public var lastAnnotationSyncDate: Date?

    public init() {}

    /// Sync annotation data for a specific score.
    public func syncAnnotations(
        scoreID: UUID,
        modelContext: ModelContext
    ) async {
        isSyncing = true
        defer { isSyncing = false }

        // CloudKit annotation sync placeholder:
        // 1. Serialize local annotation layers/strokes/objects
        // 2. Fetch remote annotation records for this score
        // 3. Detect conflicts (same layer modified on multiple devices)
        // 4. Apply conflict resolution strategy
        // 5. Push merged result

        do {
            try await Task.sleep(for: .milliseconds(300))

            // Mark all layers as synced (placeholder)
            let descriptor = FetchDescriptor<AnnotationLayer>(
                predicate: #Predicate { $0.score?.id == scoreID }
            )
            let layers = (try? modelContext.fetch(descriptor)) ?? []
            for layer in layers {
                layerSyncStatuses[layer.id] = .synced
            }

            lastAnnotationSyncDate = Date()
        } catch {
            // Sync interrupted
        }
    }

    /// Resolve a pending conflict with the chosen strategy.
    public func resolveConflict(_ conflict: AnnotationConflict, with resolution: ConflictResolution) {
        pendingConflicts.removeAll { $0.id == conflict.id }

        switch resolution {
        case .keepLocal:
            layerSyncStatuses[conflict.layerID] = .pendingUpload
        case .keepRemote:
            layerSyncStatuses[conflict.layerID] = .pendingDownload
        case .mergeBoth:
            layerSyncStatuses[conflict.layerID] = .pendingUpload
        }
    }

    /// Status description for display.
    public var statusDescription: String {
        if isSyncing { return "Syncing annotations..." }
        if !pendingConflicts.isEmpty { return "\(pendingConflicts.count) conflict(s) need resolution" }
        if let date = lastAnnotationSyncDate {
            return "Annotations synced \(date.formatted(.relative(presentation: .named)))"
        }
        return "Annotation sync ready"
    }
}

/// Represents a sync conflict on an annotation layer.
public struct AnnotationConflict: Identifiable, Sendable {
    public let id: UUID
    public let layerID: UUID
    public let layerName: String
    public let localModifiedAt: Date
    public let remoteModifiedAt: Date

    public init(layerID: UUID, layerName: String, localModifiedAt: Date, remoteModifiedAt: Date) {
        self.id = UUID()
        self.layerID = layerID
        self.layerName = layerName
        self.localModifiedAt = localModifiedAt
        self.remoteModifiedAt = remoteModifiedAt
    }
}

/// Resolution choice for a single conflict.
public enum ConflictResolution: Sendable {
    case keepLocal
    case keepRemote
    case mergeBoth
}
