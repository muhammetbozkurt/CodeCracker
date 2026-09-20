import Foundation
import MultipeerConnectivity

/// A `Sendable` stand-in for `MCPeerID`.
///
/// MultipeerConnectivity predates `Sendable` and its types are not safe to move
/// between isolation domains, so `MCPeerID` never leaves the transport. This
/// token is what the rest of the app holds and hands back.
struct PeerHandle: Hashable, Sendable, Identifiable {
    let id: UUID
    let displayName: String
}

enum TransportEvent: Sendable {
    case discovered([PeerHandle])
    /// Host side: somebody wants the second seat. Nothing happens until the
    /// player answers through `respond(to:accept:)`.
    case invitationReceived(PeerHandle)
    case connected(PeerHandle)
    case disconnected(PeerHandle)
    case received(Data, from: PeerHandle)
    /// Already localized — `Error` is not `Sendable`.
    case failed(String)
}

/// Moves `Data` between two nearby devices over Wi-Fi/Bluetooth. Knows nothing
/// about games; `MultiplayerSession` layers the rules on top.
final class MultipeerTransport: NSObject, @unchecked Sendable {
    /// Bonjour service type: 1–15 characters, lowercase/digits/hyphen. Must
    /// match `NSBonjourServices` in Info.plist or discovery silently fails.
    static let serviceType = "codecracker"

    let events: AsyncStream<TransportEvent>

    private let continuation: AsyncStream<TransportEvent>.Continuation
    private let localPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// `handles` and `discovered` are touched both from the main actor and from
    /// MultipeerConnectivity's private delegate queues, so they are lock-guarded.
    /// `advertiser` and `browser` are only ever set from the calling side.
    private let lock = NSLock()
    private var handles: [MCPeerID: PeerHandle] = [:]
    private var discovered: [MCPeerID] = []
    private var pendingInvitations: [PeerHandle: InvitationBox] = [:]

    /// MultipeerConnectivity hands over a non-`Sendable` completion. It is only
    /// ever stored and called under `lock`, never copied elsewhere.
    private struct InvitationBox: @unchecked Sendable {
        let respond: (Bool, MCSession?) -> Void
    }

    init(displayName: String) {
        let stream = AsyncStream.makeStream(of: TransportEvent.self)
        events = stream.stream
        continuation = stream.continuation
        localPeer = MCPeerID(displayName: Self.sanitize(displayName))
        session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    deinit { continuation.finish() }

    // MARK: Lifecycle

    func startHosting() {
        let advertiser = MCNearbyServiceAdvertiser(
            peer: localPeer, discoveryInfo: nil, serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    func startBrowsing() {
        let browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func invite(_ handle: PeerHandle) {
        guard let peer = peer(for: handle) else { return }
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    /// Host side: answer an invitation the player was actually asked about.
    func respond(to handle: PeerHandle, accept: Bool) {
        let pending = lock.withLock { pendingInvitations.removeValue(forKey: handle) }
        pending?.respond(accept, accept ? session : nil)
    }

    func stop() {
        // Anything still waiting on the player gets a no, or MultipeerConnectivity
        // holds the invitation open until it times out.
        let outstanding: [InvitationBox] = lock.withLock {
            let boxes = Array(pendingInvitations.values)
            pendingInvitations.removeAll()
            return boxes
        }
        for invitation in outstanding { invitation.respond(false, nil) }

        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session.disconnect()
        lock.withLock {
            discovered.removeAll()
            handles.removeAll()
        }
        continuation.finish()
    }

    // MARK: Sending

    func send(_ data: Data) {
        let peers = session.connectedPeers
        guard !peers.isEmpty else { return }
        do {
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            continuation.yield(.failed(error.localizedDescription))
        }
    }

    // MARK: Peer bookkeeping

    private func handle(for peer: MCPeerID) -> PeerHandle {
        lock.withLock {
            if let existing = handles[peer] { return existing }
            let handle = PeerHandle(id: UUID(), displayName: peer.displayName)
            handles[peer] = handle
            return handle
        }
    }

    private func peer(for handle: PeerHandle) -> MCPeerID? {
        lock.withLock { handles.first { $0.value == handle }?.key }
    }

    /// Takes the lock twice on purpose: `handle(for:)` locks, so the snapshot
    /// has to be copied out first.
    private func discoveredHandles() -> [PeerHandle] {
        lock.withLock { discovered }.map { handle(for: $0) }
    }

    private static func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Player" }
        // MCPeerID rejects display names longer than 63 UTF-8 bytes.
        return String(trimmed.prefix(60))
    }
}

// MARK: - MCSessionDelegate

extension MultipeerTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let handle = handle(for: peerID)
        switch state {
        case .connected: continuation.yield(.connected(handle))
        case .notConnected: continuation.yield(.disconnected(handle))
        case .connecting: break
        @unknown default: break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        continuation.yield(.received(data, from: handle(for: peerID)))
    }

    // Unused: this game only ever sends small JSON payloads.
    func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {}
    func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {}
    func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {}
}

// MARK: - Advertising (host)

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Two seats only, and the player decides who takes the second one.
        // Auto-accepting hands the game to whoever is in radio range first.
        let handle = handle(for: peerID)
        let queued: Bool = lock.withLock {
            guard session.connectedPeers.isEmpty, pendingInvitations.isEmpty else { return false }
            pendingInvitations[handle] = InvitationBox(respond: invitationHandler)
            return true
        }

        if queued {
            continuation.yield(.invitationReceived(handle))
        } else {
            invitationHandler(false, nil)
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        continuation.yield(.failed(error.localizedDescription))
    }
}

// MARK: - Browsing (guest)

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        lock.withLock {
            if !discovered.contains(peerID) { discovered.append(peerID) }
        }
        continuation.yield(.discovered(discoveredHandles()))
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        lock.withLock { discovered.removeAll { $0 == peerID } }
        continuation.yield(.discovered(discoveredHandles()))
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        continuation.yield(.failed(error.localizedDescription))
    }
}
