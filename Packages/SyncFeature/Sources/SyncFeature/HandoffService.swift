// HandoffService — NSUserActivity-based Handoff for cross-device session continuity.

import Foundation
import CoreDomain

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages NSUserActivity-based Handoff for seamless session transfer between
/// iPhone, iPad, and Mac. Enables picking up where you left off — including
/// current score, page position, and active setlist session.
@MainActor
@Observable
public final class HandoffService {

    // MARK: - Activity Types

    public enum ActivityType: String, Sendable {
        case viewingScore = "com.scorestage.viewing-score"
        case setlistSession = "com.scorestage.setlist-session"
        case browsing = "com.scorestage.browsing"
    }

    // MARK: - Session State

    /// The current user activity being advertised for Handoff.
    public private(set) var currentActivity: NSUserActivity?

    /// The last received Handoff state from another device.
    public private(set) var receivedState: HandoffState?

    /// Whether Handoff is enabled.
    public var isEnabled: Bool = true

    // MARK: - Handoff State

    /// Serializable state for Handoff transfer.
    public struct HandoffState: Codable, Sendable {
        public var scoreID: UUID?
        public var pageIndex: Int
        public var setlistID: UUID?
        public var setlistItemIndex: Int?
        public var displayMode: String?
        public var timestamp: Date

        public init(
            scoreID: UUID? = nil,
            pageIndex: Int = 0,
            setlistID: UUID? = nil,
            setlistItemIndex: Int? = nil,
            displayMode: String? = nil
        ) {
            self.scoreID = scoreID
            self.pageIndex = pageIndex
            self.setlistID = setlistID
            self.setlistItemIndex = setlistItemIndex
            self.displayMode = displayMode
            self.timestamp = Date()
        }
    }

    // MARK: - Callbacks

    /// Called when Handoff state is received from another device.
    public var onHandoffReceived: ((HandoffState) -> Void)?

    public init() {}

    // MARK: - Advertise Activities

    /// Advertise that the user is viewing a specific score.
    public func advertiseScoreViewing(scoreID: UUID, pageIndex: Int, displayMode: String? = nil) {
        guard isEnabled else { return }

        let activity = NSUserActivity(activityType: ActivityType.viewingScore.rawValue)
        activity.title = "Viewing Score"
        activity.isEligibleForHandoff = true
        activity.needsSave = true

        let state = HandoffState(
            scoreID: scoreID,
            pageIndex: pageIndex,
            displayMode: displayMode
        )

        if let data = try? JSONEncoder().encode(state) {
            activity.userInfo = [
                "state": data,
                "scoreID": scoreID.uuidString,
                "pageIndex": pageIndex
            ]
        }

        activity.becomeCurrent()
        currentActivity = activity
    }

    /// Advertise an active setlist session.
    public func advertiseSetlistSession(setlistID: UUID, scoreID: UUID?, pageIndex: Int, itemIndex: Int) {
        guard isEnabled else { return }

        let activity = NSUserActivity(activityType: ActivityType.setlistSession.rawValue)
        activity.title = "Setlist Session"
        activity.isEligibleForHandoff = true
        activity.needsSave = true

        let state = HandoffState(
            scoreID: scoreID,
            pageIndex: pageIndex,
            setlistID: setlistID,
            setlistItemIndex: itemIndex
        )

        if let data = try? JSONEncoder().encode(state) {
            activity.userInfo = [
                "state": data,
                "setlistID": setlistID.uuidString,
                "itemIndex": itemIndex
            ]
        }

        activity.becomeCurrent()
        currentActivity = activity
    }

    /// Advertise general library browsing.
    public func advertiseBrowsing() {
        guard isEnabled else { return }

        let activity = NSUserActivity(activityType: ActivityType.browsing.rawValue)
        activity.title = "Browsing Library"
        activity.isEligibleForHandoff = true
        activity.becomeCurrent()
        currentActivity = activity
    }

    /// Stop advertising the current activity.
    public func stopAdvertising() {
        currentActivity?.invalidate()
        currentActivity = nil
    }

    // MARK: - Receive Handoff

    /// Handle a received NSUserActivity from Handoff.
    /// Call this from the app's `onContinueUserActivity` handler.
    public func handleIncomingActivity(_ activity: NSUserActivity) -> HandoffState? {
        guard let userInfo = activity.userInfo,
              let data = userInfo["state"] as? Data,
              let state = try? JSONDecoder().decode(HandoffState.self, from: data) else {
            return nil
        }

        receivedState = state
        onHandoffReceived?(state)
        return state
    }

    /// Update the current page position (for continuous updates during reading).
    public func updatePagePosition(_ pageIndex: Int) {
        guard let activity = currentActivity,
              var userInfo = activity.userInfo else { return }

        userInfo["pageIndex"] = pageIndex
        activity.userInfo = userInfo
        activity.needsSave = true
    }

    // MARK: - Supported Activity Types

    /// Activity type strings to register with the app.
    /// Add these to Info.plist under NSUserActivityTypes.
    public static var supportedActivityTypes: [String] {
        ActivityType.allCases.map(\.rawValue)
    }
}

extension HandoffService.ActivityType: CaseIterable {}
