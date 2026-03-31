import Foundation
import CryptoKit
import SwiftData
import CoreDomain

enum AccountSessionStorage {
    static let usernameKey = "active-account-username"
    static let roleKey = "active-account-role"
}

enum AccountAuthorization {
    static func activeRole() -> AccountRole {
        guard let raw = UserDefaults.standard.string(forKey: AccountSessionStorage.roleKey),
              let role = AccountRole(rawValue: raw) else {
            return .user
        }
        return role
    }

    static func activeUsername() -> String? {
        UserDefaults.standard.string(forKey: AccountSessionStorage.usernameKey)
    }

    static func setActiveAccount(username: String, role: AccountRole) {
        UserDefaults.standard.set(username, forKey: AccountSessionStorage.usernameKey)
        UserDefaults.standard.set(role.rawValue, forKey: AccountSessionStorage.roleKey)
    }

    static func clearActiveAccount() {
        UserDefaults.standard.removeObject(forKey: AccountSessionStorage.usernameKey)
        UserDefaults.standard.removeObject(forKey: AccountSessionStorage.roleKey)
    }

    static func canAccess(feature: ProFeature, role: AccountRole, hasSubscription: Bool) -> Bool {
        if role.grantsFullAccess {
            return true
        }
        if hasSubscription {
            return true
        }
        return feature.isFree
    }
}

enum AccountPasswordHasher {
    static func makeSalt() -> Data {
        Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
    }

    static func hash(password: String, salt: Data) -> Data {
        let passwordData = Data(password.utf8)
        return Data(SHA256.hash(data: salt + passwordData))
    }
}

enum AccountBootstrap {
    static let ownerUsername = "offbyone"
    static let ownerPassword = "dontpanic43!"

    @discardableResult
    static func seedOwnerAccount(in modelContext: ModelContext) -> AdminAccount {
        let descriptor = FetchDescriptor<AdminAccount>(
            predicate: #Predicate { $0.username == ownerUsername }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            let needsCredentialSeed = existing.passwordSaltBase64.isEmpty || existing.passwordHashBase64.isEmpty
            if !existing.role.grantsFullAccess || needsCredentialSeed || existing.requiresPasswordSetup {
                let salt = AccountPasswordHasher.makeSalt()
                let passwordHash = AccountPasswordHasher.hash(password: ownerPassword, salt: salt)
                existing.role = .owner
                existing.passwordSaltBase64 = salt.base64EncodedString()
                existing.passwordHashBase64 = passwordHash.base64EncodedString()
                existing.requiresPasswordSetup = false
                existing.lastUpdatedAt = .now
            }
            try? modelContext.save()
            return existing
        }

        let salt = AccountPasswordHasher.makeSalt()
        let passwordHash = AccountPasswordHasher.hash(password: ownerPassword, salt: salt)
        let owner = AdminAccount(
            username: ownerUsername,
            role: .owner,
            passwordSaltBase64: salt.base64EncodedString(),
            passwordHashBase64: passwordHash.base64EncodedString(),
            isActive: true,
            requiresPasswordSetup: false,
            createdAt: .now,
            lastUpdatedAt: .now,
            lastAuthenticatedAt: .distantPast
        )

        modelContext.insert(owner)
        try? modelContext.save()
        return owner
    }

    static func authenticate(username: String, password: String, in modelContext: ModelContext) -> AdminAccount? {
        let descriptor = FetchDescriptor<AdminAccount>(
            predicate: #Predicate { $0.username == username }
        )
        guard let account = try? modelContext.fetch(descriptor).first,
              account.isActive,
              let salt = Data(base64Encoded: account.passwordSaltBase64),
              !account.passwordHashBase64.isEmpty else {
            return nil
        }

        let candidateHash = AccountPasswordHasher.hash(password: password, salt: salt).base64EncodedString()
        guard candidateHash == account.passwordHashBase64 else {
            return nil
        }

        account.lastAuthenticatedAt = .now
        account.lastUpdatedAt = .now
        AccountAuthorization.setActiveAccount(username: account.username, role: account.role)
        try? modelContext.save()
        return account
    }
}
