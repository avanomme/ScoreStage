// StoreService — StoreKit 2 in-app purchase and subscription management.

import Foundation
import StoreKit
import CoreDomain

/// Maintains feature access based on account role and optional subscription state.
@MainActor
@Observable
public final class StoreService {

    // MARK: - Product IDs

    enum ProductID {
        static let proLifetime = "com.scorestage.pro.lifetime"
        static let proMonthly = "com.scorestage.pro.monthly"
        static let proYearly = "com.scorestage.pro.yearly"

        static let all = [proLifetime, proMonthly, proYearly]
    }

    // MARK: - Public State

    /// Whether the current signed-in account has full access.
    public private(set) var isPro: Bool = false

    /// Current access status description.
    public private(set) var subscriptionStatus: String = "Free"

    /// Available products for purchase.
    public private(set) var products: [Product] = []

    /// Whether a purchase is in progress.
    public private(set) var isPurchasing: Bool = false

    /// Error message from last failed operation.
    public private(set) var errorMessage: String?

    /// Whether products have been loaded.
    public private(set) var isLoaded: Bool = false

    public init() {
        isLoaded = true
        applyRoleAccess()
    }

    // MARK: - Load Products

    public func loadProducts() async {
        products = []
        isLoaded = true
        errorMessage = nil
    }

    // MARK: - Purchase

    public func purchase(_ product: Product) async {
        _ = product
        isPurchasing = false
        errorMessage = nil
    }

    // MARK: - Restore

    public func restorePurchases() async {
        applyRoleAccess()
    }

    // MARK: - Status

    public func updatePurchaseStatus() async {
        applyRoleAccess()
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }

    // MARK: - Pro Feature Gating

    /// Check if a feature requires Pro. Returns true if accessible.
    public func canAccess(feature: ProFeature) -> Bool {
        AccountAuthorization.canAccess(
            feature: feature,
            role: AccountAuthorization.activeRole(),
            hasSubscription: isPro
        )
    }

    private func applyRoleAccess() {
        let role = AccountAuthorization.activeRole()
        if role.grantsFullAccess {
            isPro = true
            subscriptionStatus = "\(role.displayName) Access"
        } else {
            isPro = false
            subscriptionStatus = "Free"
        }
    }
}

// MARK: - Pro Features

public enum ProFeature: String, CaseIterable, Sendable {
    case unlimitedScores
    case annotations
    case playback
    case headTracking
    case cloudSync
    case scoreFollowing
    case deviceLink
    case exportAnnotations

    /// Whether this feature is available in the free tier.
    public var isFree: Bool {
        switch self {
        case .unlimitedScores: false  // Free tier: 5 scores
        case .annotations: true       // Basic annotations are free
        case .playback: false
        case .headTracking: false
        case .cloudSync: false
        case .scoreFollowing: false
        case .deviceLink: false
        case .exportAnnotations: false
        }
    }

    public var displayName: String {
        switch self {
        case .unlimitedScores: "Unlimited Scores"
        case .annotations: "Annotations"
        case .playback: "Notation Playback"
        case .headTracking: "Head/Eye Tracking"
        case .cloudSync: "iCloud Sync"
        case .scoreFollowing: "Score Following"
        case .deviceLink: "Device Linking"
        case .exportAnnotations: "Export Annotations"
        }
    }
}
