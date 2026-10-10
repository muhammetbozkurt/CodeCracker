import SwiftUI

struct Connect4View: View {
    /// `nil` for pass-and-play; otherwise the board lives on the session and is
    /// mirrored to the other device.
    var session: MultiplayerSession?
    /// Single player against the computer. Ignored when `session` is set.
    var vsComputer = false

    @State private var localGame = Connect4Game()
    @State private var difficulty: Difficulty = .medium
    @State private var humanOpens = true
    /// The computer's seat in a single-player game, `nil` otherwise.
    @State private var computerID: PlayerID?
    /// The board's current cell size, so a computer move animates like a tap.
    @State private var boardCell: CGFloat = 40
    @State private var redName = ""
    @State private var yellowName = ""
    @State private var started = false
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var falling: FallingDisc?
    @State private var fallOffset: CGFloat = 0

    @Environment(StatsStore.self) private var stats
    /// The board whose result is already counted, so a re-fired `isOver` or a
    /// redrawn view cannot count the same game twice.
    @State private var recordedGameID: String?

    private let kind = GameKind.connect4

    /// Derived rather than passed in: `ContentView` sets `session`/`vsComputer`
    /// from the same enum, so re-reading them here cannot disagree with it.
    private var mode: PlayMode {
        if session != nil { return .nearby }
        return vsComputer ? .solo : .passAndPlay
    }

    private var game: Connect4Game { session?.connect4 ?? localGame }
    /// A networked game is already set up by the time this view appears.
    private var isPlaying: Bool { session != nil || started }
    private var displayError: String? { session?.errorMessage ?? errorMessage }
    /// Over the network, or against the computer, you only get to touch the
    /// board on your own turn.
    private var canMove: Bool {
        if let session { return session.isMyTurn }
        if let computerID { return game.currentPlayerID != computerID }
        return true
    }
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
                        if session != nil || computerID != nil {
                            NetworkTurnHint(
                                isMyTurn: canMove,
                                accent: kind.accent,
                                waitingText: computerID != nil
                                    ? String(localized: "Computer is thinking…")
                                    : String(localized: "Waiting for your opponent")
                            )
                        }
                        // Capped: the board should settle just under the turn
                        // bar, not float in the middle of the screen.
                        Spacer(minLength: 0).frame(maxHeight: 28)
                        dropRow(cell: cell)
                        board(cell: cell)
                        ErrorLine(message: displayError)
                        if game.isOver {
                            SecondaryButton(title: String(localized: "New game"), systemImage: "arrow.counterclockwise") {
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
                    .onChange(of: cell, initial: true) { _, size in boardCell = size }
                }
            } else if vsComputer {
                SoloSetupCard(
                    kind: kind,
                    blurb: String(localized: "Red opens. Four in a line — any direction — takes it."),
                    difficulty: $difficulty,
                    humanOpens: $humanOpens,
                    action: startGame
                )
                .frame(maxHeight: .infinity)
            } else {
                SetupCard(
                    kind: kind,
                    firstLabel: String(localized: "Red player"),
                    secondLabel: String(localized: "Yellow player"),
                    firstName: $redName,
                    secondName: $yellowName,
                    blurb: String(localized: "Red opens. Four in a line — any direction — takes it."),
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
                recordResult()
                withAnimation(.easeInOut.delay(0.6)) { showResult = true }
            }
        }
        .task(id: computerTurnKey) { await playComputerTurn() }
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
        if vsComputer {
            // Seat 0 opens and plays red, so going second means the computer sits first.
            let you = Player(name: String(localized: "You"), role: humanOpens ? Disc.red : .yellow)
            let computer = Player(name: String(localized: "Computer"), role: humanOpens ? Disc.yellow : .red)
            for player in humanOpens ? [you, computer] : [computer, you] {
                try? newGame.addPlayer(player)
            }
            computerID = computer.id
        } else {
            try? newGame.addPlayer(Player(name: redName.isEmpty ? String(localized: "Red") : redName, role: .red))
            try? newGame.addPlayer(Player(name: yellowName.isEmpty ? String(localized: "Yellow") : yellowName, role: .yellow))
            computerID = nil
        }
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
            errorMessage = userMessage(for: GameError.columnIsFull)
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

        playLocally(column, by: turn, landingRow: landingRow, disc: disc, cell: cell)
    }

    /// Plays a column on this device's board and animates the disc falling in.
    /// Shared by a tap and the computer's turn.
    private func playLocally(_ column: Int, by turn: PlayerID, landingRow: Int, disc: Disc, cell: CGFloat) {
        do {
            try localGame.play(column, by: turn)
            errorMessage = nil
            animateDrop(column: column, row: landingRow, disc: disc, cell: cell)
        } catch {
            errorMessage = userMessage(for: error)
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

    // MARK: Computer

    /// Changes whenever a move lands or a new board is dealt, restarting the
    /// computer's turn and cancelling a stale one.
    private var computerTurnKey: String { "\(game.id)#\(game.turnHistory.count)" }

    private func playComputerTurn() async {
        guard let computerID, localGame.currentPlayerID == computerID else { return }
        let snapshot = localGame
        let level = difficulty

        // A beat before answering, so the move reads as a reply.
        try? await Task.sleep(for: .milliseconds(500))
        let column = await Task.detached(priority: .userInitiated) {
            ComputerPlayer.move(in: snapshot, for: computerID, difficulty: level)
        }.value

        guard !Task.isCancelled,
            localGame.id == snapshot.id,
            localGame.turnHistory.count == snapshot.turnHistory.count,
            let column,
            let disc = localGame.player(id: computerID)?.role,
            let landingRow = localGame.landingRow(inColumn: column)
        else { return }
        playLocally(column, by: computerID, landingRow: landingRow, disc: disc, cell: boardCell)
    }

    // MARK: Stats

    private func recordResult() {
        guard let outcome, recordedGameID != game.id else { return }
        recordedGameID = game.id
        stats.record(
            outcome,
            kind: kind,
            mode: mode,
            difficulty: mode == .solo ? difficulty : nil
        )
    }

    /// Who "you" are depends on the mode: the seat the computer does not hold,
    /// the seat this device owns over the network, or nobody at all when both
    /// players share the phone. `nil` while the game is still running, so an
    /// unfinished board cannot be counted as anything.
    private var outcome: GameOutcome? {
        switch game.result {
        case .ongoing:
            nil
        case .draw:
            .drawn
        case .win(let id):
            if let computerID {
                id == computerID ? .lost : .won
            } else if let session {
                id == session.localPlayerID ? .won : .lost
            } else {
                .decided
            }
        }
    }

    // MARK: Result copy

    private var resultHeadline: String {
        switch game.result {
        case .win(let id) where computerID != nil:
            id == computerID ? String(localized: "Computer wins") : String(localized: "You win")
        case .win(let id):
            String(localized: "\(game.player(id: id)?.name ?? String(localized: "Someone")) wins")
        case .draw: String(localized: "Board full")
        case .ongoing: ""
        }
    }

    private var resultDetail: String {
        switch game.result {
        case .win: String(localized: "Four connected in \(game.turnHistory.count) moves.")
        case .draw: String(localized: "All 42 sockets filled, nobody lined up four.")
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
