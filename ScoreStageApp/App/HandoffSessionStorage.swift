import Foundation
import SyncFeature

enum HandoffSessionStorage {
    static let pendingStateKey = "pending-handoff-state"

    static func store(_ state: HandoffService.HandoffState) {
        guard let data = try? JSONEncoder().encode(state),
              let string = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(string, forKey: pendingStateKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: pendingStateKey)
    }

    static func decode(_ rawValue: String) -> HandoffService.HandoffState? {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(HandoffService.HandoffState.self, from: data)
    }
}
