// AnalyticsService — Privacy-first, on-device analytics for product decisions.

import Foundation

/// Minimal, privacy-respecting analytics service.
/// - All data stays on-device (no network calls, no telemetry servers)
/// - Tracks feature usage counts only — no PII, no content, no timing
/// - Data used solely for product decisions (which features to invest in)
/// - Users can disable completely via Settings
@MainActor
@Observable
public final class AnalyticsService {

    // MARK: - Public State

    /// Whether analytics collection is enabled.
    public var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "analyticsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "analyticsEnabled") }
    }

    /// Feature usage counts (read-only for display in settings).
    public private(set) var usageCounts: [String: Int] = [:]

    // MARK: - Events

    public enum Event: String, CaseIterable, Sendable {
        // Core actions
        case scoreOpened
        case scoreImported
        case annotationCreated
        case setlistPlayed

        // Feature usage
        case playbackStarted
        case headTrackingUsed
        case eyeGazeUsed
        case pedalUsed
        case midiInputUsed
        case scoreFollowingUsed

        // Navigation
        case jumpLinkTapped
        case rehearsalMarkNavigated
        case scoreFamilySwitched

        // Modes
        case performanceModeEntered
        case deviceLinkStarted
        case handoffUsed

        public var displayName: String {
            switch self {
            case .scoreOpened: "Scores Opened"
            case .scoreImported: "Scores Imported"
            case .annotationCreated: "Annotations Created"
            case .setlistPlayed: "Setlists Played"
            case .playbackStarted: "Playback Sessions"
            case .headTrackingUsed: "Head Tracking Uses"
            case .eyeGazeUsed: "Eye Gaze Uses"
            case .pedalUsed: "Pedal Uses"
            case .midiInputUsed: "MIDI Input Sessions"
            case .scoreFollowingUsed: "Score Following Sessions"
            case .jumpLinkTapped: "Jump Links Tapped"
            case .rehearsalMarkNavigated: "Rehearsal Mark Navigations"
            case .scoreFamilySwitched: "Score Family Switches"
            case .performanceModeEntered: "Performance Mode Entries"
            case .deviceLinkStarted: "Device Link Sessions"
            case .handoffUsed: "Handoff Transfers"
            }
        }
    }

    // MARK: - Private

    private let storageKey = "analytics_usage_counts"

    public init() {
        loadCounts()
    }

    // MARK: - Track

    /// Record a single occurrence of an event.
    public func track(_ event: Event) {
        guard isEnabled else { return }
        usageCounts[event.rawValue, default: 0] += 1
        saveCounts()
    }

    // MARK: - Queries

    /// Get the count for a specific event.
    public func count(for event: Event) -> Int {
        usageCounts[event.rawValue] ?? 0
    }

    /// Get all non-zero usage stats as (displayName, count) pairs.
    public func usageReport() -> [(name: String, count: Int)] {
        Event.allCases.compactMap { event in
            let c = count(for: event)
            guard c > 0 else { return nil }
            return (name: event.displayName, count: c)
        }
    }

    // MARK: - Reset

    /// Clear all collected analytics data.
    public func resetAll() {
        usageCounts.removeAll()
        saveCounts()
    }

    // MARK: - Persistence (UserDefaults — on-device only)

    private func loadCounts() {
        if let data = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] {
            usageCounts = data
        }
    }

    private func saveCounts() {
        UserDefaults.standard.set(usageCounts, forKey: storageKey)
    }
}
