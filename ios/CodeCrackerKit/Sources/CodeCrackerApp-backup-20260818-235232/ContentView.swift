import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.indigo.opacity(0.18), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CodeCracker").font(.largeTitle.bold())
                        Text("Pass-and-play games for two.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    VStack(spacing: 14) {
                        GameCard(
                            title: "Tic-Tac-Toe",
                            subtitle: "Classic 3\u{d7}3 grid",
                            systemImage: "xmark",
                            tint: .blue
                        ) { TicTacToeView() }

                        GameCard(
                            title: "Connect 4",
                            subtitle: "Drop discs, connect four",
                            systemImage: "circle.grid.3x3.fill",
                            tint: .red
                        ) { Connect4View() }

                        GameCard(
                            title: "CodeCracker",
                            subtitle: "Crack your opponent's code",
                            systemImage: "lock.fill",
                            tint: .purple
                        ) { CodeCrackerView() }
                    }

                    Spacer()
                }
                .padding(20)
            }
        }
    }
}

private struct GameCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tint.gradient)
                        .frame(width: 52, height: 52)
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(.separator).opacity(0.3))
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
