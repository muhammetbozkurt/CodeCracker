import SwiftUI

/// The nearby-multiplayer entry point: pick a name, host or join, then hand off
/// to the game view once the two devices agree on seats.
struct LobbyView: View {
    let kind: GameKind

    @State private var name = ""
    @State private var session: MultiplayerSession?

    var body: some View {
        Group {
            if let session, session.phase == .playing {
                // The game view brings its own `GameShell`; nesting one inside
                // the lobby's would stack two backgrounds.
                gameView(session)
            } else {
                GameShell(kind: kind) {
                    Group {
                        if let session {
                            connected(session)
                        } else {
                            chooser
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .onDisappear {
            session?.leave()
            session = nil
        }
    }

    // MARK: Before a session exists

    private var chooser: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: String(localized: "nearby multiplayer"))

                Text("Two devices, same room. One hosts, the other joins.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.textSecondary)

                AppTextField(title: String(localized: "Your name"), text: $name, accent: kind.accent)

                PrimaryButton(title: String(localized: "Host a game"), systemImage: "antenna.radiowaves.left.and.right", gradient: kind.gradient) {
                    session = MultiplayerSession(kind: kind, role: .host, localName: name)
                }

                SecondaryButton(title: String(localized: "Join a game"), systemImage: "magnifyingglass") {
                    session = MultiplayerSession(kind: kind, role: .guest, localName: name)
                }
            }
            .padding(22)
            .glassSurface(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: kind.accent)
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.hairline, lineWidth: 1))

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    // MARK: With a session

    @ViewBuilder
    private func connected(_ session: MultiplayerSession) -> some View {
        switch session.phase {
        case .playing:
            EmptyView()
        case .ended(let reason):
            ended(reason)
        case .connecting, .handshaking:
            waiting(session)
        }
    }

    @ViewBuilder
    private func waiting(_ session: MultiplayerSession) -> some View {
        VStack(spacing: 18) {
            Group {
                if let peer = session.pendingInvitation {
                    invitation(from: peer, session)
                } else {
                    searching(session)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .glassSurface(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: kind.accent)
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.hairline, lineWidth: 1))

            SecondaryButton(title: String(localized: "Cancel"), systemImage: "xmark") {
                session.leave()
                self.session = nil
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func searching(_ session: MultiplayerSession) -> some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(kind.accent)

            Text(session.role == .host ? String(localized: "Waiting for a player") : String(localized: "Looking for nearby games"))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text(session.role == .host
                 ? String(localized: "Keep this screen open. Your opponent should tap Join on their device.")
                 : String(localized: "Pick the host below once their game shows up."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            if session.role == .guest {
                peerList(session)
            }
        }
    }

    /// Anyone in radio range can ask to join, and the name they show is their
    /// own choosing — so the player says yes, not the app.
    private func invitation(from peer: PeerHandle, _ session: MultiplayerSession) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(kind.accent)

            Text("\(peer.displayName) wants to join")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Text("Only let them in if that is the person sitting next to you.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: String(localized: "Let them in"), systemImage: "checkmark", gradient: kind.gradient) {
                session.respond(to: peer, accept: true)
            }

            SecondaryButton(title: String(localized: "Decline"), systemImage: "xmark") {
                session.respond(to: peer, accept: false)
            }
        }
    }

    @ViewBuilder
    private func peerList(_ session: MultiplayerSession) -> some View {
        VStack(spacing: 10) {
            ForEach(session.discoveredPeers) { peer in
                Button {
                    session.invite(peer)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "ipad.and.iphone")
                            .foregroundStyle(kind.accent)
                        Text(peer.displayName)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .glassSurface(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.hairline, lineWidth: 1))
                    // Without this the gap the `Spacer` opens up between the
                    // name and the chevron is not tappable.
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressableStyle(scale: 0.98))
            }
        }
        .padding(.top, 4)
    }

    private func ended(_ reason: String) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(kind.accent)
                Text("Game ended")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(reason)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .glassSurface(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: kind.accent)
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.hairline, lineWidth: 1))

            PrimaryButton(title: String(localized: "Back to lobby"), systemImage: "arrow.counterclockwise", gradient: kind.gradient) {
                session?.leave()
                session = nil
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func gameView(_ session: MultiplayerSession) -> some View {
        switch kind {
        case .ticTacToe:
            TicTacToeView(session: session)
        case .connect4:
            Connect4View(session: session)
        case .codeCracker:
            CodeCrackerView(session: session)
        }
    }
}
