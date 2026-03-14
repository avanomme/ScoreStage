// StoreService — StoreKit 2 in-app purchase and subscription management.

import Foundation
import StoreKit

/// Manages ScoreStage Pro unlock and optional cloud subscription via StoreKit 2.
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

    /// Whether the user has Pro access (lifetime or active subscription).
    public private(set) var isPro: Bool = false

    /// Current subscription status description.
    public private(set) var subscriptionStatus: String = "Free"

    /// Available products for purchase.
    public private(set) var products: [Product] = []

    /// Whether a purchase is in progress.
    public private(set) var isPurchasing: Bool = false

    /// Error message from last failed operation.
    public private(set) var errorMessage: String?

    /// Whether products have been loaded.
    public private(set) var isLoaded: Bool = false

    // MARK: - Private

    private nonisolated(unsafe) var updateListenerTask: Task<Void, Never>?

    public init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchaseStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    public func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: ProductID.all)
            // Sort: monthly, yearly, lifetime
            products = storeProducts.sorted { a, b in
                let order = [ProductID.proMonthly, ProductID.proYearly, ProductID.proLifetime]
                let ai = order.firstIndex(of: a.id) ?? 99
                let bi = order.firstIndex(of: b.id) ?? 99
                return ai < bi
            }
            isLoaded = true
        } catch {
            errorMessage = "Unable to load products."
            isLoaded = true
        }
    }

    // MARK: - Purchase

    public func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchaseStatus()

            case .userCancelled:
                break

            case .pending:
                subscriptionStatus = "Purchase pending"

            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - Restore

    public func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchaseStatus()
    }

    // MARK: - Status

    public func updatePurchaseStatus() async {
        var hasProAccess = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if ProductID.all.contains(transaction.productID) {
                if transaction.revocationDate == nil {
                    hasProAccess = true

                    if transaction.productID == ProductID.proLifetime {
                        subscriptionStatus = "Pro (Lifetime)"
                    } else if transaction.productID == ProductID.proYearly {
                        if let expirationDate = transaction.expirationDate {
                            subscriptionStatus = "Pro (Yearly) — renews \(expirationDate.formatted(.dateTime.month().day()))"
                        } else {
                            subscriptionStatus = "Pro (Yearly)"
                        }
                    } else if transaction.productID == ProductID.proMonthly {
                        if let expirationDate = transaction.expirationDate {
                            subscriptionStatus = "Pro (Monthly) — renews \(expirationDate.formatted(.dateTime.month().day()))"
                        } else {
                            subscriptionStatus = "Pro (Monthly)"
                        }
                    }
                }
            }
        }

        isPro = hasProAccess
        if !hasProAccess {
            subscriptionStatus = "Free"
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let _ = try? self.checkVerified(result) {
                    await self.updatePurchaseStatus()
                }
            }
        }
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
        if isPro { return true }
        return feature.isFree
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
