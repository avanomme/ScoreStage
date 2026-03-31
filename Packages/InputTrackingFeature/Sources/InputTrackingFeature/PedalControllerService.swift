import Foundation
import GameController
import CoreDomain

@MainActor
@Observable
public final class PedalControllerService {
    public struct ConnectedPedal: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public private(set) var connectedPedals: [ConnectedPedal] = []
    public private(set) var lastTriggeredRole: PedalInputRole?
    public var onPedalInput: ((PedalInputRole) -> Void)?

    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func startMonitoring() {
        guard observers.isEmpty else { return }
        scanConnectedControllers()

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.scanConnectedControllers()
                }
            }
        )
        observers.append(
            center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.scanConnectedControllers()
                }
            }
        )
    }

    public func stopMonitoring() {
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers.removeAll()
        connectedPedals.removeAll()
        GCController.controllers().forEach { controller in
            clearHandlers(for: controller)
        }
    }

    private func scanConnectedControllers() {
        connectedPedals = []
        GCController.controllers().forEach { register($0) }
    }

    private func register(_ controller: GCController) {
        let id = controller.vendorName ?? UUID().uuidString
        let name = controller.vendorName ?? "Bluetooth Pedal"
        if !connectedPedals.contains(where: { $0.id == id }) {
            connectedPedals.append(ConnectedPedal(id: id, name: name))
        }

        if let extended = controller.extendedGamepad {
            extended.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.left) }
            }
            extended.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.right) }
            }
            extended.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.center) }
            }
            extended.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.auxiliary) }
            }
            extended.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.left) }
            }
            extended.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.right) }
            }
        } else if let micro = controller.microGamepad {
            micro.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.left) }
            }
            micro.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.right) }
            }
            micro.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.center) }
            }
            micro.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { self?.emit(.auxiliary) }
            }
        }
    }

    private func clearHandlers(for controller: GCController) {
        if let extended = controller.extendedGamepad {
            extended.dpad.left.pressedChangedHandler = nil
            extended.dpad.right.pressedChangedHandler = nil
            extended.buttonA.pressedChangedHandler = nil
            extended.buttonB.pressedChangedHandler = nil
            extended.leftShoulder.pressedChangedHandler = nil
            extended.rightShoulder.pressedChangedHandler = nil
        }
        if let micro = controller.microGamepad {
            micro.dpad.left.pressedChangedHandler = nil
            micro.dpad.right.pressedChangedHandler = nil
            micro.buttonA.pressedChangedHandler = nil
            micro.buttonX.pressedChangedHandler = nil
        }
    }

    private func emit(_ role: PedalInputRole) {
        lastTriggeredRole = role
        onPedalInput?(role)
    }
}
