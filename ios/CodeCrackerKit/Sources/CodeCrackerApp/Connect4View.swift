import SwiftUI

struct Connect4View: View {
    /// `nil` for pass-and-play; otherwise the board lives on the session and is
    /// mirrored to the other device.
    var session: MultiplayerSession?

    @State private var localGame = Connect4Game()
    @State private var redName = ""
    @State private var yellowName = ""
    @State private var started = false
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var falling: FallingDisc?
    @State private var fallOffset: CGFloat = 0

    private let kind = GameKind.connect4

    private var game: Connect4Game { session?.connect4 ?? localGame }
    /// A networked game is already set up by the time this view appears.
    private var isPlaying: Bool { session != nil || started }
    private var displayError: String? { session?.errorMessage ?? errorMessage }
    /// Over the network you only get to touch the board on your own turn.
    private var canMove: Bool { session.map(\.isMyTurn) ?? true }
    private let spacing: CGFloat = 6
    private let framePadding: CGFloat = 10

    private struct FallingDisc: Identifiable {
        let id = UUID()
        let column: Int
        let row: Int
        let disc: Disc
    }

    var body: some View {
        GameShell(kind: kind) {
            if isPlaying {
                GeometryReader { proxy in
                    let cell = cellSize(in: proxy.size)
                    VStack(spacing: 16) {
                        TurnBar(seats: seats, activeIndex: activeSeatIndex)
                        if session != nil {
                            NetworkTurnHint(isMyTurn: canMove, accent: kind.accent)
                        }
                        // Capped: the board should settle just under the turn
                        // bar, not float in the middle of the screen.
                        Spacer(minLength: 0).frame(maxHeight: 28)
                        dropRow(cell: cell)
                        board(cell: cell)
                        ErrorLine(message: displayError)
                        if game.isOver {
                            SecondaryButton(title: "New game", systemImage: "arrow.counterclockwise") {
                                if let session {
                                    session.requestRematch()
                                } else {
                                    started = false
                                }
                                errorMessage = nil
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
            } else {
                SetupCard(
                    kind: kind,
                    firstLabel: "Red player",
                    secondLabel: "Yellow player",
                    firstName: $redName,
                    secondName: $yellowName,
                    blurb: "Red opens. Four in a line — any direction — takes it.",
                    action: startGame
                )
                .frame(maxHeight: .infinity)
            }
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
                withAnimation(.easeInOut.delay(0.6)) { showResult = true }
            }
        }
    }

    // MARK: Layout

    /// Fits the 7×6 grid to whatever space the device gives us, rather than the
    /// fixed 40pt cells the first version used.
    private func cellSize(in size: CGSize) -> CGFloat {
        let byWidth = (size.width - framePadding * 2 - spacing * CGFloat(Connect4Game.columns - 1))
            / CGFloat(Connect4Game.columns)
        let byHeight = (size.height * 0.66 - framePadding * 2 - spacing * CGFloat(Connect4Game.rows - 1))
            / CGFloat(Connect4Game.rows)
        return max(28, min(byWidth, byHeight))
    }

    private var seats: [TurnBar.Seat] {
        game.players.map { player in
            TurnBar.Seat(name: player.name, symbol: "●", color: player.role.color)
        }
    }

    private var activeSeatIndex: Int? {
        guard let current = game.currentPlayerID else { return nil }
        return game.players.firstIndex { $0.id == current }
    }

    private var currentDisc: Disc? {
        guard let id = game.currentPlayerID else { return nil }
        return game.player(id: id)?.role
    }

    // MARK: Board

    /// Arrows above each column — the clearest affordance for "drop here".
    private func dropRow(cell: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<Connect4Game.columns, id: \.self) { column in
                Button {
                    drop(column, cell: cell)
                } label: {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: max(11, cell * 0.3)))
                        .foregroundStyle(
                            game.canPlay(column) && !game.isOver
                                ? (currentDisc?.color ?? Color.textTertiary)
                                : Color.white.opacity(0.10)
                        )
                        .frame(width: cell, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.85))
                .disabled(game.isOver || !game.canPlay(column))
            }
        }
        .padding(.horizontal, framePadding)
        .animation(.easeInOut(duration: 0.25), value: activeSeatIndex)
    }

    private func board(cell: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: spacing) {
                ForEach(0..<Connect4Game.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<Connect4Game.columns, id: \.self) { column in
                            socket(row: row, column: column, cell: cell)
                        }
                    }
                }
            }

            if let falling {
                DiscView(color: falling.disc.color)
                    .frame(width: cell, height: cell)
                    .offset(
                        x: CGFloat(falling.column) * (cell + spacing),
                        y: CGFloat(falling.row) * (cell + spacing) + fallOffset
                    )
                    .allowsHitTesting(false)
            }
        }
        .padding(framePadding)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.18, blue: 0.42),
                            Color(red: 0.09, green: 0.10, blue: 0.26),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
        .shadow(color: .black.opacity(0.5), radius: 24, y: 14)
    }

    private func socket(row: Int, column: Int, cell: CGFloat) -> some View {
        let disc = game.disc(row: row, column: column)
        let isMidFlight = falling?.column == column && falling?.row == row
        let isWinning = game.winningCells?.contains(game.index(row: row, column: column)) == true
        let isLandingSpot = !game.isOver && game.landingRow(inColumn: column) == row

        return Group {
            if let disc, !isMidFlight {
                DiscView(color: disc.color, isWinning: isWinning)
            } else {
                EmptySocket(highlight: isLandingSpot ? currentDisc?.color : nil)
            }
        }
        .frame(width: cell, height: cell)
        .contentShape(Rectangle())
        .onTapGesture { drop(column, cell: cell) }
    }

    // MARK: Moves

    private func startGame() {
        if let session {
            session.requestRematch()
            showResult = false
            falling = nil
            return
        }
        var newGame = Connect4Game()
        try? newGame.addPlayer(Player(name: redName.isEmpty ? "Red" : redName, role: .red))
        try? newGame.addPlayer(Player(name: yellowName.isEmpty ? "Yellow" : yellowName, role: .yellow))
        localGame = newGame
        errorMessage = nil
        falling = nil
        showResult = false
        started = true
    }

    private func playAgain() {
        showResult = false
        startGame()
    }

    private func drop(_ column: Int, cell: CGFloat) {
        guard !game.isOver, canMove, let turn = game.currentPlayerID else { return }
        guard let disc = game.player(id: turn)?.role else { return }
        guard let landingRow = game.landingRow(inColumn: column) else {
            errorMessage = GameError.columnIsFull.localizedDescription
            return
        }

        if let session {
            // The session reports rejections through `errorMessage`, so animate
            // only if the move actually landed. A disc dropped on the other
            // device simply appears — the fall is a local flourish.
            let before = game.turnHistory.count
            session.submit(.column(column))
            if game.turnHistory.count > before {
                animateDrop(column: column, row: landingRow, disc: disc, cell: cell)
            }
            return
        }

        do {
            try localGame.play(column, by: turn)
            errorMessage = nil
            animateDrop(column: column, row: landingRow, disc: disc, cell: cell)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func animateDrop(column: Int, row: Int, disc: Disc, cell: CGFloat) {
        let piece = FallingDisc(column: column, row: row, disc: disc)
        falling = piece
        // Start one row above the top of the board and let it fall in.
        fallOffset = -CGFloat(row + 1) * (cell + spacing)

        withAnimation(.spring(response: 0.42, dampingFraction: 1.0)) {
            fallOffset = 0
        } completion: {
            if falling?.id == piece.id { falling = nil }
        }
    }


    // MARK: Result copy

    private var resultHeadline: String {
        switch game.result {
        case .win(let id): "\(game.player(id: id)?.name ?? "Someone") wins"
        case .draw: "Board full"
        case .ongoing: ""
        }
    }

    private var resultDetail: String {
        switch game.result {
        case .win: "Four connected in \(game.turnHistory.count) moves."
        case .draw: "All 42 sockets filled, nobody connected four."
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
