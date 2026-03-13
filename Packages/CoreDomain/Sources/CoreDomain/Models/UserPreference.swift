import Foundation
import SwiftData

@Model
public final class UserPreference {
    public var id: UUID
    public var key: String
    public var value: String
    public var modifiedAt: Date

    public init(key: String, value: String) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.modifiedAt = Date()
    }
}
