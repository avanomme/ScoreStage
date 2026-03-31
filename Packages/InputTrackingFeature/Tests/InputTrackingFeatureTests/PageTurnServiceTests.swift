import XCTest
@testable import InputTrackingFeature
@testable import CoreDomain

final class PageTurnServiceTests: XCTestCase {
    func testKeyboardMappingTriggersTurnAction() {
        let service = PageTurnService()
        var capturedDirection: PageTurnService.TurnDirection?

        service.setHandler { direction in
            capturedDirection = direction
        }

        let handled = service.handleKeyboardKey(.rightArrow)

        XCTAssertTrue(handled)
        XCTAssertEqual(capturedDirection, .forward)
        XCTAssertEqual(service.lastAction, .nextPage)
    }

    func testPedalMappingUsesConfiguredAction() {
        let service = PageTurnService()
        var profile = ExternalControlProfile.stageDefault
        profile.setPedalAction(.togglePerformanceLock, for: .center)
        service.controlProfile = profile

        var capturedAction: ExternalControlAction?
        service.setActionHandler { action, _ in
            capturedAction = action
        }

        let handled = service.handlePedalInput(.center)

        XCTAssertTrue(handled)
        XCTAssertEqual(capturedAction, .togglePerformanceLock)
    }

    func testMidiControlChangeRouting() {
        let service = PageTurnService()
        var capturedDirection: PageTurnService.TurnDirection?

        service.setHandler { direction in
            capturedDirection = direction
        }

        let handled = service.handleMIDIInput(type: .controlChange, value: 64, channel: 0)

        XCTAssertTrue(handled)
        XCTAssertEqual(capturedDirection, .forward)
        XCTAssertEqual(service.lastTrigger, .midi)
    }
}
