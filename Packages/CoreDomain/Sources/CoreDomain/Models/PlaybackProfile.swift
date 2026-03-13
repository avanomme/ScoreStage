import Foundation
import SwiftData

@Model
public final class PlaybackProfile {
    public var id: UUID
    public var name: String
    public var tempo: Double
    public var transposeSemitones: Int
    public var loopStartMeasure: Int?
    public var loopEndMeasure: Int?
    public var isCountInEnabled: Bool
    public var isMetronomeEnabled: Bool
    public var mutedPartIndices: [Int]
    public var soloPartIndex: Int?
    public var partVolumes: [Double]
    public var createdAt: Date

    public var score: Score?

    public init(name: String = "Default", tempo: Double = 120.0) {
        self.id = UUID()
        self.name = name
        self.tempo = tempo
        self.transposeSemitones = 0
        self.isCountInEnabled = false
        self.isMetronomeEnabled = false
        self.mutedPartIndices = []
        self.partVolumes = []
        self.createdAt = Date()
    }
}
