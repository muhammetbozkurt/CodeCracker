import SwiftUI

struct TicTacToeView: View {
    @State private var game = TicTacToeGame()
    @State private var player1Name = ""
    @State private var player2Name = ""
    @State private var started = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack {
                Spacer(minLength: 0)
                if started {
                    boardSection
                } else {
                    setupSection
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .navigationTitle("Tic-Tac-Toe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var setupSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
            VStack(spacing: 12) {
                AppTextField(title: "Player X name", text: $player1Name, systemImage: "person.fill")
                AppTextField(title: "Player O name", text: $player2Name, systemImage: "person.fill")
            }
            PrimaryButton(title: "Start Game", systemImage: "play.fill") { startGame() }
        }
        .cardBackground()
    }

    private func startGame() {
        var newGame = TicTacToeGame()
        try? newGame.addPlayer(Player(name: player1Name.isEmpty ? "Player X" : player1Name, role: .x))
        try? newGame.addPlayer(Player(name: player2Name.isEmpty ? "Player O" : player2Name, role: .o))
        game = newGame
        errorMessage = nil
        started = true
    }

    private var boardSection: some View {
        VStack(spacing: 20) {
            statusBanner

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(0..<TicTacToeGame.cellCount, id: \.self) { cell in
                    cellButton(cell)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }

            if game.isOver {
                SecondaryButton(title: "Play Again") {
                    started = false
                    errorMessage = nil
                }
            }
        }
    }

    private var statusBanner: some View {
        Group {
            switch game.result {
            case .win(let id):
                StatusBadge(text: "\u{1f3c6} \(game.player(id: id)?.name ?? "Someone") wins!", tint: .green)
            case .draw:
                StatusBadge(text: "\u{1f91d} Draw", tint: .orange)
            case .ongoing:
                if let turn = game.currentPlayerID, let player = game.player(id: turn) {
                    StatusBadge(
                        text: "\(player.name)'s turn (\(player.role.rawValue))",
                        tint: player.role == .x ? .blue : .orange
                    )
                }
            }
        }
    }

    private func cellButton(_ cell: Int) -> some View {
        let isWinning = game.winningLine?.contains(cell) == true
        let mark = game.board[cell]
        return Button {
            playCell(cell)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isWinning ? Color.green.opacity(0.18) : Color(.secondarySystemBackground))
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isWinning ? Color.green : Color(.separator).opacity(0.35),
                        lineWidth: isWinning ? 2 : 1
                    )
                if let mark {
                    Text(mark.rawValue)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(color(for: mark, isWinning: isWinning))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(game.isOver || !game.canPlay(cell))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: mark)
    }

    private func color(for mark: Mark?, isWinning: Bool) -> Color {
        guard let mark else { return .clear }
        if isWinning { return .green }
        return mark == .x ? .blue : .orange
    }

    private func playCell(_ cell: Int) {
        guard let turn = game.currentPlayerID else { return }
        do {
            try game.play(cell, by: turn)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
