import Foundation
import SwiftData
import CoreDomain

@MainActor
@Observable
public final class CloudKitSyncService {
    public enum SyncState: Sendable {
        case idle
        case syncing
        case synced
        case error(String)
        case disabled
    }

    public var state: SyncState = .disabled
    public var lastSyncDate: Date?
    public var pendingConflicts: [UUID] = []
    public var isEnabled: Bool = false {
        didSet {
            state = isEnabled ? .idle : .disabled
        }
    }

    public init() {}

    public func syncNow(modelContext: ModelContext) async {
        guard isEnabled else {
            state = .disabled
            return
        }

        state = .syncing

        do {
            let snapshot = try buildSnapshot(modelContext: modelContext)
            let mirrorURL = try syncMirrorURL()
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: mirrorURL, options: .atomic)
            try updateSyncRecords(modelContext: modelContext, snapshot: snapshot)
            lastSyncDate = Date()
            pendingConflicts = []
            state = .synced
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func importMirror(from url: URL, modelContext: ModelContext) async {
        guard isEnabled else {
            state = .disabled
            return
        }

        state = .syncing
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder().decode(LibrarySyncSnapshot.self, from: data)
            try merge(snapshot: snapshot, modelContext: modelContext)
            lastSyncDate = Date()
            state = .synced
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public var statusDescription: String {
        switch state {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing library mirror..."
        case .synced:
            if let date = lastSyncDate {
                return "Last synced \(date.formatted(.relative(presentation: .named)))"
            }
            return "Synced"
        case .error(let message):
            return message
        case .disabled:
            return "Sync disabled"
        }
    }

    // MARK: - Snapshot

    private func buildSnapshot(modelContext: ModelContext) throws -> LibrarySyncSnapshot {
        let scores = try modelContext.fetch(FetchDescriptor<Score>())
        let setlists = try modelContext.fetch(FetchDescriptor<SetList>())

        return LibrarySyncSnapshot(
            createdAt: Date(),
            scores: scores.map {
                SyncScoreRecord(
                    id: $0.id,
                    title: $0.title,
                    composer: $0.composer,
                    fileHash: $0.fileHash,
                    modifiedAt: $0.modifiedAt
                )
            },
            setlists: setlists.map {
                SyncSetlistRecord(
                    id: $0.id,
                    name: $0.name,
                    modifiedAt: $0.modifiedAt
                )
            }
        )
    }

    private func merge(snapshot: LibrarySyncSnapshot, modelContext: ModelContext) throws {
        let localScores = try modelContext.fetch(FetchDescriptor<Score>())
        let localSetlists = try modelContext.fetch(FetchDescriptor<SetList>())

        pendingConflicts = []

        for remoteScore in snapshot.scores {
            if let local = localScores.first(where: { $0.fileHash == remoteScore.fileHash }) {
                if remoteScore.modifiedAt > local.modifiedAt {
                    local.title = remoteScore.title
                    local.composer = remoteScore.composer
                    local.modifiedAt = remoteScore.modifiedAt
                } else if local.modifiedAt > remoteScore.modifiedAt {
                    pendingConflicts.append(local.id)
                }
            }
        }

        for remoteSetlist in snapshot.setlists {
            if let local = localSetlists.first(where: { $0.name == remoteSetlist.name }) {
                if remoteSetlist.modifiedAt > local.modifiedAt {
                    local.modifiedAt = remoteSetlist.modifiedAt
                } else if local.modifiedAt > remoteSetlist.modifiedAt {
                    pendingConflicts.append(local.id)
                }
            }
        }

        try updateSyncRecords(modelContext: modelContext, snapshot: snapshot)
        try modelContext.save()
    }

    private func updateSyncRecords(modelContext: ModelContext, snapshot: LibrarySyncSnapshot) throws {
        let existingRecords = try modelContext.fetch(FetchDescriptor<SyncRecord>())

        for score in snapshot.scores {
            let record = existingRecords.first(where: { $0.entityID == score.id && $0.entityType == "score" }) ?? {
                let newRecord = SyncRecord(entityType: "score", entityID: score.id)
                modelContext.insert(newRecord)
                return newRecord
            }()
            record.status = pendingConflicts.contains(score.id) ? .conflict : .synced
            record.lastSyncedAt = lastSyncDate ?? Date()
            record.conflictData = pendingConflicts.contains(score.id) ? Data(score.fileHash.utf8) : nil
        }

        for setlist in snapshot.setlists {
            let record = existingRecords.first(where: { $0.entityID == setlist.id && $0.entityType == "setlist" }) ?? {
                let newRecord = SyncRecord(entityType: "setlist", entityID: setlist.id)
                modelContext.insert(newRecord)
                return newRecord
            }()
            record.status = pendingConflicts.contains(setlist.id) ? .conflict : .synced
            record.lastSyncedAt = lastSyncDate ?? Date()
        }

        try modelContext.save()
    }

    private func syncMirrorURL() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let syncDirectory = appSupport.appendingPathComponent("SyncMirror")
        if !FileManager.default.fileExists(atPath: syncDirectory.path) {
            try FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        }
        return syncDirectory.appendingPathComponent("library-sync.json")
    }
}

public struct LibrarySyncSnapshot: Codable, Sendable {
    public let createdAt: Date
    public let scores: [SyncScoreRecord]
    public let setlists: [SyncSetlistRecord]
}

public struct SyncScoreRecord: Codable, Sendable {
    public let id: UUID
    public let title: String
    public let composer: String
    public let fileHash: String
    public let modifiedAt: Date
}

public struct SyncSetlistRecord: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let modifiedAt: Date
}
