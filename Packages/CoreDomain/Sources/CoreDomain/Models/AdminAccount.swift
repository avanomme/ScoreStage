import Foundation
import SwiftData

public enum AccountRole: String, Codable, CaseIterable, Sendable, Identifiable {
    case owner
    case admin
    case user

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .owner: "Owner"
        case .admin: "Admin"
        case .user: "User"
        }
    }

    public var grantsFullAccess: Bool {
        switch self {
        case .owner, .admin: true
        case .user: false
        }
    }
}

@Model
public final class AdminAccount {
    @Attribute(.unique) public var username: String
    public var roleRawValue: String
    public var passwordSaltBase64: String
    public var passwordHashBase64: String
    public var isActive: Bool
    public var requiresPasswordSetup: Bool
    public var createdAt: Date
    public var lastUpdatedAt: Date
    public var lastAuthenticatedAt: Date?

    public var role: AccountRole {
        get { AccountRole(rawValue: roleRawValue) ?? .user }
        set { roleRawValue = newValue.rawValue }
    }

    public init(
        username: String,
        role: AccountRole = .owner,
        passwordSaltBase64: String = "",
        passwordHashBase64: String = "",
        isActive: Bool = true,
        requiresPasswordSetup: Bool = true,
        createdAt: Date = .now,
        lastUpdatedAt: Date = .now,
        lastAuthenticatedAt: Date? = nil
    ) {
        self.username = username
        self.roleRawValue = role.rawValue
        self.passwordSaltBase64 = passwordSaltBase64
        self.passwordHashBase64 = passwordHashBase64
        self.isActive = isActive
        self.requiresPasswordSetup = requiresPasswordSetup
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.lastAuthenticatedAt = lastAuthenticatedAt
    }
}
