// DeviceLinkFeature — peer-to-peer device pairing, two-page spread, mirrored mode

import Foundation
import CoreDomain
import MultipeerConnectivity
import Combine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Device Role

/// Role of a device in a linked session.
public enum DeviceRole: String, Codable, Sendable {
    case primary    // Controls navigation
    case secondary  // Follows primary
    case conductor  // Conductor mode (full score)
    case performer  // Performer mode (part view)
}

/// Display mode for linked-device sessions.
public enum LinkedDisplayMode: String, Codable, Sendable {
    case twoPageSpread   // Left page on one device, right page on other
    case mirroredSync    // Both show same page, synced navigation
    case conductorPerformer // Conductor sees full score, performer sees part
}

// MARK: - Peer Info

/// Information about a discovered or connected peer device.
public struct PeerDevice: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public var role: DeviceRole
    public var isConnected: Bool

    public init(id: String, displayName: String, role: DeviceRole = .secondary, isConnected: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.isConnected = isConnected
    }
}

// MARK: - Link Messages

/// Messages exchanged between linked devices.
public enum LinkMessage: Codable, Sendable {
    case pageChanged(pageIndex: Int)
    case displayModeChanged(mode: String)
    case roleAssignment(role: String)
    case scoreOpened(scoreID: UUID)
    case sessionEnded
    case ping

    enum CodingKeys: String, CodingKey {
        case type, pageIndex, mode, role, scoreID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "pageChanged":
            self = .pageChanged(pageIndex: try container.decode(Int.self, forKey: .pageIndex))
        case "displayModeChanged":
            self = .displayModeChanged(mode: try container.decode(String.self, forKey: .mode))
        case "roleAssignment":
            self = .roleAssignment(role: try container.decode(String.self, forKey: .role))
        case "scoreOpened":
            self = .scoreOpened(scoreID: try container.decode(UUID.self, forKey: .scoreID))
        case "sessionEnded":
            self = .sessionEnded
        default:
            self = .ping
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pageChanged(let pageIndex):
            try container.encode("pageChanged", forKey: .type)
            try container.encode(pageIndex, forKey: .pageIndex)
        case .displayModeChanged(let mode):
            try container.encode("displayModeChanged", forKey: .type)
            try container.encode(mode, forKey: .mode)
        case .roleAssignment(let role):
            try container.encode("roleAssignment", forKey: .type)
            try container.encode(role, forKey: .role)
        case .scoreOpened(let scoreID):
            try container.encode("scoreOpened", forKey: .type)
            try container.encode(scoreID, forKey: .scoreID)
        case .sessionEnded:
            try container.encode("sessionEnded", forKey: .type)
        case .ping:
            try container.encode("ping", forKey: .type)
        }
    }
}

// MARK: - Session Holder (thread-safe reference for delegate callbacks)

final class SessionHolder: @unchecked Sendable {
    var session: MCSession?
}

// MARK: - Multipeer Session Manager

/// Manages Multipeer Connectivity sessions for device linking.
@MainActor
@Observable
public final class DeviceLinkService: NSObject {
    public var discoveredPeers: [PeerDevice] = []
    public var connectedPeers: [PeerDevice] = []
    public var localRole: DeviceRole = .primary
    public var displayMode: LinkedDisplayMode = .twoPageSpread
    public var isAdvertising = false
    public var isBrowsing = false
    public var currentPageIndex: Int = 0
    public var openedScoreID: UUID?

    /// Callback for received link messages.
    public var onMessageReceived: ((LinkMessage) -> Void)?

    private let serviceType = "scorestage-lnk"
    private var localPeerID: MCPeerID
    private var session: MCSession?
    /// Thread-safe reference for delegate callbacks that need the session.
    private let sessionHolder = SessionHolder()
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    public override init() {
        #if canImport(UIKit)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        self.localPeerID = MCPeerID(displayName: deviceName)
        super.init()
    }

    // MARK: - Session Lifecycle

    public func startSession() {
        let session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        self.sessionHolder.session = session
    }

    public func startAdvertising() {
        if session == nil { startSession() }
        advertiser = MCNearbyServiceAdvertiser(peer: localPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        isAdvertising = true
    }

    public func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
    }

    public func startBrowsing() {
        if session == nil { startSession() }
        browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        isBrowsing = true
    }

    public func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
    }

    public func invitePeer(_ peer: PeerDevice) {
        guard let session else { return }
        let peerID = MCPeerID(displayName: peer.displayName)
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    public func disconnect() {
        sendMessage(.sessionEnded)
        session?.disconnect()
        stopAdvertising()
        stopBrowsing()
        connectedPeers.removeAll()
        discoveredPeers.removeAll()
        currentPageIndex = 0
        openedScoreID = nil
    }

    // MARK: - Messaging

    public func sendMessage(_ message: LinkMessage) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            // Message send failed
        }
    }

    public func sendPageChange(to pageIndex: Int) {
        currentPageIndex = pageIndex
        sendMessage(.pageChanged(pageIndex: pageIndex))
    }

    public func sendOpenedScore(_ scoreID: UUID, pageIndex: Int = 0) {
        openedScoreID = scoreID
        currentPageIndex = pageIndex
        sendMessage(.scoreOpened(scoreID: scoreID))
        sendMessage(.pageChanged(pageIndex: pageIndex))
    }

    public func configureLinkedSession(
        displayMode: LinkedDisplayMode,
        localRole: DeviceRole,
        remoteRole: DeviceRole
    ) {
        self.displayMode = displayMode
        self.localRole = localRole
        sendMessage(.displayModeChanged(mode: displayMode.rawValue))
        sendMessage(.roleAssignment(role: remoteRole.rawValue))
    }

    public var isLinked: Bool {
        !connectedPeers.isEmpty
    }

    public var connectionSummary: String {
        if connectedPeers.isEmpty {
            return isBrowsing || isAdvertising ? "Scanning for devices" : "Not linked"
        }

        let peerNames = connectedPeers.map(\.displayName).joined(separator: ", ")
        return "Linked with \(peerNames)"
    }
}

// MARK: - MCSessionDelegate

extension DeviceLinkService: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let name = peerID.displayName
        Task { @MainActor in
            switch state {
            case .connected:
                let peer = PeerDevice(id: name, displayName: name, isConnected: true)
                if !connectedPeers.contains(where: { $0.id == peer.id }) {
                    connectedPeers.append(peer)
                }
                discoveredPeers.removeAll { $0.id == peer.id }
            case .notConnected:
                connectedPeers.removeAll { $0.id == name }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(LinkMessage.self, from: data) else { return }
        Task { @MainActor in
            handleReceivedMessage(message)
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    @MainActor
    private func handleReceivedMessage(_ message: LinkMessage) {
        switch message {
        case .pageChanged(let pageIndex):
            currentPageIndex = pageIndex
        case .displayModeChanged(let mode):
            if let linkedMode = LinkedDisplayMode(rawValue: mode) {
                displayMode = linkedMode
            }
        case .roleAssignment(let role):
            if let assignedRole = DeviceRole(rawValue: role) {
                localRole = assignedRole
            }
        case .scoreOpened(let scoreID):
            openedScoreID = scoreID
        case .sessionEnded:
            connectedPeers.removeAll()
            openedScoreID = nil
        default:
            break
        }
        onMessageReceived?(message)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension DeviceLinkService: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, sessionHolder.session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension DeviceLinkService: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let name = peerID.displayName
        Task { @MainActor in
            let peer = PeerDevice(id: name, displayName: name)
            if !discoveredPeers.contains(where: { $0.id == peer.id }) && !connectedPeers.contains(where: { $0.id == peer.id }) {
                discoveredPeers.append(peer)
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let name = peerID.displayName
        Task { @MainActor in
            discoveredPeers.removeAll { $0.id == name }
        }
    }
}
