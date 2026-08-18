import SwiftUI

struct TicTacToeView: View {
    @State private var game = TicTacToeGame()
    @State private var playerXName = ""
    @State private var playerOName = ""
    @State private var started = false
    @State private var showResult = false
    @State private var errorMessage: String?

    private let kind = GameKind.ticTacToe

    var body: some View {
        GameShell(kind: kind) {
            VStack(spacing: 22) {
                if started {
                    boardScreen
                } else {
                    SetupCard(
                        kind: kind,
                        firstLabel: "Player X",
                        secondLabel: "Player O",
                        firstName: $playerXName,
                        secondName: $playerOName,
                        blurb: "X opens. Three in a row — across, down or corner to corner — wins.",
                        action: startGame
                    )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .overlay {
            if showResult {
                WinOverlay(
                    headline: resultHeadline,
                    detail: resultDetail,
                    accent: resultAccent,
                    onPlayAgain: playAgain,
                    onDismiss: { showResult = false }
                )
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: game.turnHistory.count)
        .sensoryFeedback(.success, trigger: game.isOver)
        .onChange(of: game.isOver) { _, isOver in
            if isOver {
                withAnimation(.easeInOut.delay(0.45)) { showResult = true }
            }
        }
    }

    // MARK: Setup

    private func startGame() {
        var newGame = TicTacToeGame()
        try? newGame.addPlayer(Player(name: playerXName.isEmpty ? "Player X" : playerXName, role: .x))
        try? newGame.addPlayer(Player(name: playerOName.isEmpty ? "Player O" : playerOName, role: .o))
        game = newGame
        errorMessage = nil
        showResult = false
        started = true
    }

    private func playAgain() {
        showResult = false
        startGame()
    }

    // MARK: Board

    private var boardScreen: some View {
        VStack(spacing: 20) {
            TurnBar(seats: seats, activeIndex: activeSeatIndex)

            board

            ErrorLine(message: errorMessage)

            if game.isOver {
                SecondaryButton(title: "New game", systemImage: "arrow.counterclockwise") {
                    started = false
                    errorMessage = nil
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    private var seats: [TurnBar.Seat] {
        game.players.map { player in
            TurnBar.Seat(name: player.name, symbol: player.role.rawValue, color: player.role.color)
        }
    }

    private var activeSeatIndex: Int? {
        guard let current = game.currentPlayerID else { return nil }
        return game.players.firstIndex { $0.id == current }
    }

    private var board: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(0..<TicTacToeGame.cellCount, id: \.self) { cell in
                cellView(cell)
            }
        }
        .padding(14)
        .glassSurface(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Color.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 26, y: 14)
    }

    private func cellView(_ cell: Int) -> some View {
        let mark = game.board[cell]
        let isWinning = game.winningLine?.contains(cell) == true

        return Button {
            play(cell)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(isWinning ? 0.14 : 0.05))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isWinning ? (mark?.color ?? Color.hairline) : Color.hairline,
                        lineWidth: isWinning ? 2 : 1
                    )

                if let mark {
                    MarkGlyph(mark: mark, color: mark.color, lineWidth: 9)
                        .padding(6)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PressableStyle(scale: 0.93))
        .disabled(game.isOver || !game.canPlay(cell))
        .animation(.spring(response: 0.32, dampingFraction: 0.62), value: mark)
    }

    private func play(_ cell: Int) {
        guard let turn = game.currentPlayerID else { return }
        do {
            try game.play(cell, by: turn)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Result copy

    private var resultHeadline: String {
        switch game.result {
        case .win(let id): "\(game.player(id: id)?.name ?? "Someone") wins"
        case .draw: "Dead heat"
        case .ongoing: ""
        }
    }

    private var resultDetail: String {
        switch game.result {
        case .win: "Three in a row in \(game.turnHistory.count) moves."
        case .draw: "Nine squares, no winner. Again?"
        case .ongoing: ""
        }
    }

    private var resultAccent: Color {
        if case .win(let id) = game.result, let player = game.player(id: id) {
            return player.role.color
        }
        return .discYellow
    }
}

/// The name-entry card shared by Tic-Tac-Toe and Connect 4.
struct SetupCard: View {
    let kind: GameKind
    let firstLabel: String
    let secondLabel: String
    @Binding var firstName: String
    @Binding var secondName: String
    let blurb: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            GameThumbnail(kind: kind)

            VStack(spacing: 8) {
                Text(kind.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(blurb)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                AppTextField(title: firstLabel, text: $firstName, accent: kind.accent)
                AppTextField(title: secondLabel, text: $secondName, accent: kind.secondaryAccent)
            }

            PrimaryButton(
                title: "Start game",
                systemImage: "play.fill",
                gradient: kind.gradient,
                action: action
            )
        }
        .glassCard(tint: kind.accent)
    }
}
