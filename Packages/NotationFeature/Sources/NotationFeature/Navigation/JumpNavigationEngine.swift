// JumpNavigationEngine — resolves D.C., D.S., Coda, repeats into a linear playback order.

import Foundation

/// Resolves structural navigation markers (D.C., D.S., Coda, repeats, endings)
/// in a NormalizedScore into a flattened linear measure sequence for playback.
public struct JumpNavigationEngine: Sendable {

    /// A resolved step in the playback sequence.
    public struct PlaybackStep: Sendable, Equatable {
        /// The measure number to play.
        public let measureNumber: Int
        /// Whether this is a repeated visit (for UI highlighting).
        public let isRepeat: Bool
        /// Label describing why we're here (e.g., "D.C.", "Coda", "Repeat").
        public let reason: String

        public init(measureNumber: Int, isRepeat: Bool = false, reason: String = "") {
            self.measureNumber = measureNumber
            self.isRepeat = isRepeat
            self.reason = reason
        }
    }

    /// Hotspot on a score page that the user can tap to navigate.
    public struct NavigationHotspot: Sendable, Identifiable {
        public let id: String
        public let measureNumber: Int
        public let type: DirectionType
        public let label: String
        /// Destination measure number when tapped.
        public let destinationMeasure: Int?

        public init(measureNumber: Int, type: DirectionType, label: String, destinationMeasure: Int?) {
            self.id = "\(measureNumber)-\(type.rawValue)"
            self.measureNumber = measureNumber
            self.type = type
            self.label = label
            self.destinationMeasure = destinationMeasure
        }
    }

    public init() {}

    // MARK: - Resolve Playback Order

    /// Flatten the score's navigation structure into a linear sequence of measures.
    /// Handles repeats, D.C., D.S., Coda, Fine, and endings.
    public func resolvePlaybackOrder(from score: NormalizedScore) -> [PlaybackStep] {
        guard let part = score.parts.first, !part.measures.isEmpty else { return [] }

        let measures = part.measures
        var steps: [PlaybackStep] = []
        var index = 0
        var repeatStack: [(startIndex: Int, timesLeft: Int)] = []
        var hasTakenDC = false
        var hasTakenDS = false
        var jumpedToCoda = false

        while index < measures.count {
            let measure = measures[index]

            // Check for Fine (end marker)
            if measure.directions.contains(where: { $0.type == .fine }) && (hasTakenDC || hasTakenDS) {
                steps.append(PlaybackStep(
                    measureNumber: measure.number,
                    isRepeat: hasTakenDC || hasTakenDS,
                    reason: "Fine"
                ))
                break
            }

            // Add current measure
            steps.append(PlaybackStep(
                measureNumber: measure.number,
                isRepeat: hasTakenDC || hasTakenDS || jumpedToCoda,
                reason: jumpedToCoda ? "Coda" : ""
            ))

            // Check for repeat start
            if measure.repeatStart {
                repeatStack.append((startIndex: index, timesLeft: measure.repeatTimes - 1))
            }

            // Check for repeat end
            if measure.repeatEnd {
                if let last = repeatStack.last, last.timesLeft > 0 {
                    repeatStack[repeatStack.count - 1].timesLeft -= 1
                    index = last.startIndex
                    continue
                } else if !repeatStack.isEmpty {
                    repeatStack.removeLast()
                }
            }

            // Check for D.C. (Da Capo) — go back to beginning
            if measure.directions.contains(where: { $0.type == .daCapo }) && !hasTakenDC {
                hasTakenDC = true
                index = 0
                continue
            }

            // Check for D.S. (Dal Segno) — go back to segno
            if measure.directions.contains(where: { $0.type == .dalSegno }) && !hasTakenDS {
                hasTakenDS = true
                if let segnoIndex = measures.firstIndex(where: { m in
                    m.directions.contains(where: { $0.type == .segno })
                }) {
                    index = segnoIndex
                    continue
                }
            }

            // Check for Coda — jump to coda symbol
            if measure.directions.contains(where: { $0.type == .coda }) && (hasTakenDC || hasTakenDS) && !jumpedToCoda {
                jumpedToCoda = true
                // Find the coda destination (second coda mark, or a coda after current position)
                if let codaIndex = measures[(index + 1)...].firstIndex(where: { m in
                    m.directions.contains(where: { $0.type == .coda })
                }) {
                    index = codaIndex
                    continue
                }
            }

            index += 1
        }

        return steps
    }

    // MARK: - Extract Navigation Hotspots

    /// Extract tappable navigation hotspots from the score.
    /// Each hotspot represents a coda, segno, D.C., D.S., or repeat marker
    /// that the user can tap to jump to its destination.
    public func extractHotspots(from score: NormalizedScore) -> [NavigationHotspot] {
        guard let part = score.parts.first else { return [] }

        var hotspots: [NavigationHotspot] = []
        let measures = part.measures

        // Find segno and coda locations for resolving destinations
        let segnoMeasure = measures.first(where: { m in
            m.directions.contains(where: { $0.type == .segno })
        })?.number

        let codaMeasures = measures.filter { m in
            m.directions.contains(where: { $0.type == .coda })
        }.map(\.number)

        for measure in measures {
            for direction in measure.directions {
                switch direction.type {
                case .segno:
                    hotspots.append(NavigationHotspot(
                        measureNumber: measure.number,
                        type: .segno,
                        label: direction.text.isEmpty ? "𝄋" : direction.text,
                        destinationMeasure: nil // Segno is a target, not a jump
                    ))

                case .coda:
                    // First coda is "jump from here", second is "jump to here"
                    let codaDestination = codaMeasures.first(where: { $0 > measure.number })
                    hotspots.append(NavigationHotspot(
                        measureNumber: measure.number,
                        type: .coda,
                        label: direction.text.isEmpty ? "𝄌" : direction.text,
                        destinationMeasure: codaDestination
                    ))

                case .daCapo:
                    hotspots.append(NavigationHotspot(
                        measureNumber: measure.number,
                        type: .daCapo,
                        label: direction.text.isEmpty ? "D.C." : direction.text,
                        destinationMeasure: measures.first?.number
                    ))

                case .dalSegno:
                    hotspots.append(NavigationHotspot(
                        measureNumber: measure.number,
                        type: .dalSegno,
                        label: direction.text.isEmpty ? "D.S." : direction.text,
                        destinationMeasure: segnoMeasure
                    ))

                case .fine:
                    hotspots.append(NavigationHotspot(
                        measureNumber: measure.number,
                        type: .fine,
                        label: direction.text.isEmpty ? "Fine" : direction.text,
                        destinationMeasure: nil // Fine = stop
                    ))

                default:
                    break
                }
            }

            // Repeat markers
            if measure.repeatStart {
                hotspots.append(NavigationHotspot(
                    measureNumber: measure.number,
                    type: .rehearsalMark, // reuse for repeat start
                    label: "𝄆",
                    destinationMeasure: nil
                ))
            }
            if measure.repeatEnd {
                // Find the matching repeat start
                let repeatStart = measures
                    .prefix(while: { $0.number <= measure.number })
                    .last(where: { $0.repeatStart })?.number ?? measures.first?.number
                hotspots.append(NavigationHotspot(
                    measureNumber: measure.number,
                    type: .rehearsalMark,
                    label: "𝄇",
                    destinationMeasure: repeatStart
                ))
            }
        }

        return hotspots
    }

    // MARK: - Jump Link Resolution

    /// Resolve a manual JumpLink (from CoreDomain) into a destination measure,
    /// given a MeasureMap for timing context.
    public func resolveDestination(
        fromMeasure sourceMeasure: Int,
        jumpType: String,
        score: NormalizedScore
    ) -> Int? {
        guard let part = score.parts.first else { return nil }
        let measures = part.measures

        switch jumpType {
        case "daCapo":
            return measures.first?.number

        case "dalSegno":
            return measures.first(where: { m in
                m.directions.contains(where: { $0.type == .segno })
            })?.number

        case "coda":
            return measures.first(where: { m in
                m.number > sourceMeasure && m.directions.contains(where: { $0.type == .coda })
            })?.number

        default:
            return nil
        }
    }
}
