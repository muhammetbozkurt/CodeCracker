import SwiftUI

struct ContentView: View {
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(tint: .codeAccent, secondary: .markX)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
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
            SectionLabel(text: "two players, one device")

            Text("CodeCracker")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Pick a game, pass the phone, settle it properly.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.top, 24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
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
            Image(systemName: "wifi.slash")
            Text("No account, no server, no internet.")
        }
        .font(.system(.footnote, design: .rounded, weight: .medium))
        .foregroundStyle(Color.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func destination(for kind: GameKind) -> some View {
        switch kind {
        case .ticTacToe: TicTacToeView()
        case .connect4: Connect4View()
        case .codeCracker: CodeCrackerView()
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
