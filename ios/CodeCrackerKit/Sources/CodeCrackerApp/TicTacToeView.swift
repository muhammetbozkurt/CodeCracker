import SwiftUI

struct TicTacToeView: View {
    /// `nil` for pass-and-play; otherwise the board lives on the session and is
    /// mirrored to the other device.
    var session: MultiplayerSession?
    /// Single player against the computer. Ignored when `session` is set.
    var vsComputer = false

    @State private var localGame = TicTacToeGame()
    @State private var difficulty: Difficulty = .medium
    @State private var humanOpens = true
    /// The computer's seat in a single-player game, `nil` otherwise.
    @State private var computerID: PlayerID?
    @State private var playerXName = ""
    @State private var playerOName = ""
    @State private var started = false
    @State private var showResult = false
    @State private var errorMessage: String?

    @Environment(StatsStore.self) private var stats
    /// The board whose result is already counted, so a re-fired `isOver` or a
    /// redrawn view cannot count the same game twice.
    @State private var recordedGameID: String?

    private let kind = GameKind.ticTacToe

    /// Derived rather than passed in: `ContentView` sets `session`/`vsComputer`
    /// from the same enum, so re-reading them here cannot disagree with it.
    private var mode: PlayMode {
        if session != nil { return .nearby }
        return vsComputer ? .solo : .passAndPlay
    }

    private var game: TicTacToeGame { session?.ticTacToe ?? localGame }
    /// A networked game is already set up by the time this view appears.
    private var isPlaying: Bool { session != nil || started }
    private var displayError: String? { session?.errorMessage ?? errorMessage }
    /// Pass-and-play lets whoever holds the phone move; over the network you
    /// only get to touch the board on your own turn.
    private var canMove: Bool {
        if let session { return session.isMyTurn }
        if let computerID { return game.currentPlayerID != computerID }
        return true
    }

    var body: some View {
        GameShell(kind: kind) {
            VStack(spacing: 22) {
                if isPlaying {
                    boardScreen
                } else if vsComputer {
                    SoloSetupCard(
                        kind: kind,
                        blurb: String(localized: "X opens. Three in a row — across, down or corner to corner — wins."),
                        difficulty: $difficulty,
                        humanOpens: $humanOpens,
                        action: startGame
                    )
                } else {
                    SetupCard(
                        kind: kind,
                        firstLabel: String(localized: "Player X"),
                        secondLabel: String(localized: "Player O"),
                        firstName: $playerXName,
                        secondName: $playerOName,
                        blurb: String(localized: "X opens. Three in a row — across, down or corner to corner — wins."),
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
                recordResult()
                withAnimation(.easeInOut.delay(0.45)) { showResult = true }
            }
        }
        .task(id: computerTurnKey) { await playComputerTurn() }
    }

    // MARK: Setup

    private func startGame() {
        if let session {
            session.requestRematch()
            showResult = false
            return
        }
        var newGame = TicTacToeGame()
        if vsComputer {
            // Seat 0 opens and plays X, so going second means the computer sits first.
            let you = Player(name: String(localized: "You"), role: humanOpens ? Mark.x : .o)
            let computer = Player(name: String(localized: "Computer"), role: humanOpens ? Mark.o : .x)
            for player in humanOpens ? [you, computer] : [computer, you] {
                try? newGame.addPlayer(player)
            }
            computerID = computer.id
        } else {
            try? newGame.addPlayer(Player(name: playerXName.isEmpty ? String(localized: "Player X") : playerXName, role: .x))
            try? newGame.addPlayer(Player(name: playerOName.isEmpty ? String(localized: "Player O") : playerOName, role: .o))
            computerID = nil
        }
        localGame = newGame
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
        GeometryReader { proxy in
            VStack(spacing: 20) {
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

                board
                    .frame(maxWidth: boardSide(in: proxy.size))

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
        }
    }

    /// Room kept below and above the board for the turn bar, hint, error line
    /// and "New game" button, so a short window shrinks the board instead of
    /// pushing the button off screen.
    private let reservedHeight: CGFloat = 250

    /// The board is square, so it takes whichever runs out first: the width,
    /// or the height left once everything around it has its room.
    private func boardSide(in size: CGSize) -> CGFloat {
        max(180, min(size.width, size.height - reservedHeight))
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
        .disabled(game.isOver || !game.canPlay(cell) || !canMove)
        .animation(.spring(response: 0.32, dampingFraction: 0.62), value: mark)
    }

    private func play(_ cell: Int) {
        if let session {
            session.submit(.cell(cell))
            return
        }
        guard let turn = game.currentPlayerID else { return }
        do {
            try localGame.play(cell, by: turn)
            errorMessage = nil
        } catch {
            errorMessage = userMessage(for: error)
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
        let cell = await Task.detached(priority: .userInitiated) {
            ComputerPlayer.move(in: snapshot, for: computerID, difficulty: level)
        }.value

        guard !Task.isCancelled,
            localGame.id == snapshot.id,
            localGame.turnHistory.count == snapshot.turnHistory.count,
            let cell
        else { return }
        try? localGame.play(cell, by: computerID)
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
        case .draw: String(localized: "Dead heat")
        case .ongoing: ""
        }
    }

    private var resultDetail: String {
        switch game.result {
        case .win: String(localized: "Three in a row in \(game.turnHistory.count) moves.")
        case .draw: String(localized: "Nine squares, no winner. Again?")
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
                title: String(localized: "Start game"),
                systemImage: "play.fill",
                gradient: kind.gradient,
                action: action
            )
        }
        .glassCard(tint: kind.accent)
    }
}

/// The single-player setup card shared by all three games: difficulty and who
/// opens, no names.
struct SoloSetupCard<Accessory: View>: View {
    let kind: GameKind
    let blurb: String
    @Binding var difficulty: Difficulty
    @Binding var humanOpens: Bool
    let action: () -> Void
    /// Extra content under the blurb, where the pass-and-play card puts it —
    /// CodeCracker's peg legend.
    @ViewBuilder var accessory: Accessory

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

            accessory

            VStack(spacing: 14) {
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("You go first", isOn: $humanOpens)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(kind.accent)
            }

            PrimaryButton(
                title: String(localized: "Start game"),
                systemImage: "play.fill",
                gradient: kind.gradient,
                action: action
            )
        }
        .glassCard(tint: kind.accent)
    }
}

extension SoloSetupCard where Accessory == EmptyView {
    init(
        kind: GameKind,
        blurb: String,
        difficulty: Binding<Difficulty>,
        humanOpens: Binding<Bool>,
        action: @escaping () -> Void
    ) {
        self.init(
            kind: kind,
            blurb: blurb,
            difficulty: difficulty,
            humanOpens: humanOpens,
            action: action,
            accessory: { EmptyView() }
        )
    }
}

extension Difficulty {
    /// The level's name as the player reads it. The raw value is a storage key
    /// (stats keys use it), so it stays English.
    var title: String {
        switch self {
        case .easy: String(localized: "Easy")
        case .medium: String(localized: "Medium")
        case .hard: String(localized: "Hard")
        }
    }
}
