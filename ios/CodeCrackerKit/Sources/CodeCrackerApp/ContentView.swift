import SwiftUI

struct ContentView: View {
    @State private var appeared = false
    @State private var mode: PlayMode = .passAndPlay

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(tint: .codeAccent, secondary: .markX)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        modePicker
                        tiles
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
        }
        .tint(.white)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: mode.sectionLabel)

            Text("CodeCracker")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(mode.blurb)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var modePicker: some View {
        Picker("How to play", selection: $mode) {
            ForEach(PlayMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .opacity(appeared ? 1 : 0)
    }

    private var tiles: some View {
        VStack(spacing: 14) {
            ForEach(Array(GameKind.allCases.enumerated()), id: \.element.id) { index, kind in
                NavigationLink {
                    destination(for: kind)
                } label: {
                    GameTile(kind: kind)
                }
                .buttonStyle(PressableStyle(scale: 0.975))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.82).delay(0.06 * Double(index + 1)),
                    value: appeared
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: mode.footerIcon)
            Text(mode.footerText)
        }
        .font(.system(.footnote, design: .rounded, weight: .medium))
        .foregroundStyle(Color.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func destination(for kind: GameKind) -> some View {
        switch mode {
        case .passAndPlay:
            switch kind {
            case .ticTacToe: TicTacToeView()
            case .connect4: Connect4View()
            case .codeCracker: CodeCrackerView()
            }
        case .nearby:
            LobbyView(kind: kind)
        }
    }
}

/// One row on the home screen: board art, name, tagline.
private struct GameTile: View {
    let kind: GameKind

    var body: some View {
        HStack(spacing: 16) {
            GameThumbnail(kind: kind)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(kind.tagline)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(kind.accent)
        }
        .padding(18)
        .glassSurface(RoundedRectangle(cornerRadius: 26, style: .continuous), tint: kind.accent)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
    }
}

/// Pass the phone, or play against a second device in the same room.
enum PlayMode: String, CaseIterable, Identifiable {
    case passAndPlay
    case nearby

    var id: String { rawValue }

    var title: String {
        switch self {
        case .passAndPlay: "Pass & play"
        case .nearby: "Nearby"
        }
    }

    var sectionLabel: String {
        switch self {
        case .passAndPlay: "two players, one device"
        case .nearby: "two players, two devices"
        }
    }

    var blurb: String {
        switch self {
        case .passAndPlay: "Pick a game, pass the phone, settle it properly."
        case .nearby: "Pick a game, then host or join from the device next to you."
        }
    }

    var footerIcon: String {
        switch self {
        case .passAndPlay: "wifi.slash"
        case .nearby: "antenna.radiowaves.left.and.right"
        }
    }

    var footerText: String {
        switch self {
        case .passAndPlay: "No account, no server, no internet."
        case .nearby: "Device to device. No account, no server, no internet."
        }
    }
}
