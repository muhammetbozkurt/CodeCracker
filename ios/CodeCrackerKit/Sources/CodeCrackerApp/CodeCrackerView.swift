import SwiftUI

/// Pass-and-play has a shape the other two games don't: each player has to
/// enter a secret without the other seeing it, so the screen walks through
/// names -> hand over -> pick secret -> hand over -> play.
private enum Stage: Equatable {
    case names
    case handoff(seat: Int)
    case secret(seat: Int)
    /// Nearby games only: your code is in, theirs isn't yet.
    case waitingForOpponent
    case playing
}

struct CodeCrackerView: View {
    /// `nil` for pass-and-play; otherwise the board lives on the session and is
    /// mirrored to the other device.
    var session: MultiplayerSession?
    /// Single player against the computer. Ignored when `session` is set.
    var vsComputer = false

    @State private var localGame = GuessSecretGame()
    @State private var difficulty: Difficulty = .medium
    @State private var humanOpens = true
    /// The computer's seat in a single-player game, `nil` otherwise.
    @State private var computerID: PlayerID?
    @State private var firstName = ""
    @State private var secondName = ""
    @State private var entry = ""
    @State private var stage: Stage = .names
    @State private var historySeat = 0
    @State private var showResult = false
    @State private var errorMessage: String?

    @Environment(StatsStore.self) private var stats
    /// The board whose result is already counted, so a re-fired hook or a
    /// redrawn view cannot count the same game twice.
    @State private var recordedGameID: String?

    private let kind = GameKind.codeCracker

    /// Derived rather than passed in: `ContentView` sets `session`/`vsComputer`
    /// from the same enum, so re-reading them here cannot disagree with it.
    private var mode: PlayMode {
        if session != nil { return .nearby }
        return vsComputer ? .solo : .passAndPlay
    }

    /// A nearby game ends twice over: the board finishes, and then the reveal
    /// either checks out or exposes a cheat. Counting on the first step would
    /// credit a result the commitment check has not vouched for yet.
    ///
    /// An opponent who never reveals — they quit, or the connection drops —
    /// leaves this false, and the game goes uncounted. That is the honest
    /// answer: nothing about the result was ever verified.
    private var revealSettled: Bool {
        guard let session else { return true }
        return session.revealedOpponentCode != nil || session.opponentCheated
    }

    private var game: GuessSecretGame { session?.codeCracker ?? localGame }
    private var displayError: String? { session?.errorMessage ?? errorMessage }
    /// Over the network you only get to guess on your own turn — and not while
    /// a guess is away being scored by the player who owns the code.
    private var canMove: Bool {
        if let session { return session.isMyTurn && !session.isAwaitingFeedback }
        if let computerID { return game.currentPlayerID != computerID }
        return true
    }
    private var mySeat: Int? {
        guard let session else { return nil }
        return game.players.firstIndex { $0.id == session.localPlayerID }
    }

    /// Nearby games skip names and hand-off entirely — each device is already
    /// private to one player — so the stage follows the board instead of the
    /// buttons the player pressed.
    private var effectiveStage: Stage {
        guard let session else { return stage }
        guard let seat = mySeat else { return .waitingForOpponent }
        if !game.hasChosenSecret(session.localPlayerID) { return .secret(seat: seat) }
        return game.isReadyToPlay ? .playing : .waitingForOpponent
    }

    var body: some View {
        GameShell(kind: kind, scrolls: true) {
            VStack(spacing: 18) {
                switch effectiveStage {
                case .names:
                    if vsComputer {
                        soloSetup
                    } else {
                        namesCard
                    }
                case .handoff(let seat):
                    handoffCard(seat: seat)
                case .secret(let seat):
                    secretCard(seat: seat)
                case .waitingForOpponent:
                    waitingCard
                case .playing:
                    playingScreen
                }
            }
            .padding(.vertical, 16)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: effectiveStage)
        }
        .overlay {
            if showResult {
                WinOverlay(
                    headline: resultHeadline,
                    detail: resultDetail,
                    accent: kind.accent,
                    onPlayAgain: playAgain,
                    onDismiss: { showResult = false }
                )
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: entry.count)
        .sensoryFeedback(.success, trigger: game.isOver)
        .onChange(of: game.isOver) { _, isOver in
            if isOver {
                recordResult()
                withAnimation(.easeInOut.delay(0.3)) { showResult = true }
            }
        }
        // Nearby games finish counting here instead, once the reveal lands.
        .onChange(of: revealSettled) { _, _ in recordResult() }
        .onChange(of: game.id) { _, _ in
            // A rematch dealt by the host replaces the board underneath us.
            entry = ""
            errorMessage = nil
            showResult = false
            historySeat = mySeat ?? 0
        }
        .onAppear {
            historySeat = mySeat ?? historySeat
        }
        .task(id: computerTurnKey) { await playComputerTurn() }
    }

    // MARK: Waiting (nearby games)

    private var waitingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(kind.accent)
            Text("Code locked in")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Waiting for \(session?.opponentName ?? "your opponent") to pick theirs.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .glassCard(tint: kind.accent)
        .frame(maxHeight: .infinity)
    }

    // MARK: Names

    private var namesCard: some View {
        VStack(spacing: 20) {
            GameThumbnail(kind: kind)

            VStack(spacing: 8) {
                Text("CodeCracker")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("You each hide a four-digit code with no repeated digits, then take turns guessing the other's.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            legend

            VStack(spacing: 10) {
                AppTextField(title: "Player 1", text: $firstName, accent: kind.accent)
                AppTextField(title: "Player 2", text: $secondName, accent: kind.secondaryAccent)
            }

            PrimaryButton(title: "Continue", systemImage: "arrow.right", gradient: kind.gradient) {
                beginSetup()
            }
        }
        .glassCard(tint: kind.accent)
    }

    private var soloSetup: some View {
        SoloSetupCard(
            kind: kind,
            blurb: "You and the computer each hide a four-digit code with no repeated digits, then take turns guessing the other's.",
            difficulty: $difficulty,
            humanOpens: $humanOpens,
            action: beginSetup,
            accessory: { legend }
        )
    }

    /// What the two peg colours mean — the one rule that isn't obvious.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle().fill(Color.codeMint).frame(width: 9, height: 9)
                Text("Right digit, right place")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
            }
            HStack(spacing: 10) {
                Circle().strokeBorder(Color.discYellow, lineWidth: 2).frame(width: 9, height: 9)
                Text("Right digit, wrong place")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func beginSetup() {
        var newGame = GuessSecretGame()
        if vsComputer {
            // Seat 0 opens, so going second means the computer sits first.
            let computer = PlayerID()
            let names = humanOpens ? ["You", "Computer"] : ["Computer", "You"]
            for name in names {
                _ = try? newGame.addPlayer(named: name, id: name == "Computer" ? computer : PlayerID())
            }
            try? newGame.setSecret(ComputerPlayer.secret(), for: computer)
            computerID = computer
        } else {
            _ = try? newGame.addPlayer(named: firstName.isEmpty ? "Player 1" : firstName)
            _ = try? newGame.addPlayer(named: secondName.isEmpty ? "Player 2" : secondName)
            computerID = nil
        }
        localGame = newGame
        entry = ""
        errorMessage = nil
        showResult = false
        // Against the computer there is nobody to hide the screen from.
        stage = vsComputer ? .secret(seat: humanOpens ? 0 : 1) : .handoff(seat: 0)
    }

    // MARK: Hand over

    private func handoffCard(seat: Int) -> some View {
        let name = game.players.indices.contains(seat) ? game.players[seat].name : "the next player"

        return VStack(spacing: 18) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 42))
                .foregroundStyle(kind.accent.gradient)
                .glow(kind.accent, radius: 18)

            VStack(spacing: 6) {
                Text("Pass the device to \(name)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Nobody else should look at the next screen.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
            }

            PrimaryButton(title: "I'm \(name)", systemImage: "lock.open.fill", gradient: kind.gradient) {
                entry = ""
                errorMessage = nil
                stage = .secret(seat: seat)
            }
        }
        .glassCard(tint: kind.accent)
        .frame(maxHeight: .infinity)
    }

    // MARK: Secret entry

    private func secretCard(seat: Int) -> some View {
        let name = game.players.indices.contains(seat) ? game.players[seat].name : ""

        return VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(computerID != nil ? "Pick your code" : "\(name), pick your code")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("Four digits, all different, no leading zero.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
            }

            CodeBoxes(digits: entry, accent: kind.accent, isMasked: true)

            ErrorLine(message: errorMessage)

            Keypad(
                accent: kind.accent,
                canSubmit: entry.count == SecretCode.length,
                submitLabel: "Set code",
                onDigit: append,
                onDelete: deleteDigit,
                onSubmit: { setSecret(seat: seat) }
            )
        }
        .glassCard(tint: kind.accent)
    }

    private func setSecret(seat: Int) {
        guard game.players.indices.contains(seat) else { return }
        if let session {
            do {
                session.submitSecret(try SecretCode(validating: entry))
                entry = ""
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }
        do {
            let code = try SecretCode(validating: entry)
            try localGame.setSecret(code, for: game.players[seat].id)
            entry = ""
            errorMessage = nil
            if computerID != nil {
                historySeat = seat
                stage = .playing
            } else if seat == 0 {
                stage = .handoff(seat: 1)
            } else {
                historySeat = 0
                stage = .playing
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Playing

    private var playingScreen: some View {
        VStack(spacing: 16) {
            TurnBar(seats: seats, activeIndex: activeSeatIndex)

            if session != nil || computerID != nil {
                NetworkTurnHint(
                    isMyTurn: canMove,
                    accent: kind.accent,
                    waitingText: computerID != nil ? "Computer is thinking…" : "Waiting for your opponent"
                )
            }

            if !game.isOver {
                VStack(spacing: 14) {
                    CodeBoxes(digits: entry, accent: currentAccent)
                    Keypad(
                        accent: currentAccent,
                        canSubmit: entry.count == SecretCode.length && canMove,
                        submitLabel: "Submit guess",
                        onDigit: append,
                        onDelete: deleteDigit,
                        onSubmit: submitGuess
                    )
                }
                .glassCard(tint: currentAccent)
            }

            ErrorLine(message: displayError)

            historyCard

            if game.isOver {
                SecondaryButton(title: "New game", systemImage: "arrow.counterclockwise") {
                    reset()
                }
            }
        }
    }

    /// The seat colour of whoever is guessing, so the entry pad matches the
    /// turn bar instead of staying on player one's purple all game.
    private var currentAccent: Color {
        activeSeatIndex == 1 ? kind.secondaryAccent : kind.accent
    }

    private var seats: [TurnBar.Seat] {
        game.players.enumerated().map { index, player in
            TurnBar.Seat(
                name: player.name,
                symbol: "\(index + 1)",
                color: index == 0 ? kind.accent : kind.secondaryAccent
            )
        }
    }

    private var activeSeatIndex: Int? {
        guard let current = game.currentPlayerID else { return nil }
        return game.players.firstIndex { $0.id == current }
    }

    /// Both players' guesses, one at a time — a picker rather than two cramped
    /// columns, so a long game stays readable.
    private var historyCard: some View {
        VStack(spacing: 14) {
            if game.players.count == 2 {
                Picker("", selection: $historySeat) {
                    ForEach(Array(game.players.enumerated()), id: \.offset) { index, player in
                        Text(player.name).tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }

            let turns = visibleTurns

            if turns.isEmpty {
                Text("No guesses yet.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(turns.enumerated().reversed()), id: \.offset) { index, turn in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 18, alignment: .trailing)

                            Text(turn.guess.description)
                                .font(.system(size: 19, weight: .bold, design: .monospaced))
                                .foregroundStyle(turn.isWinning ? Color.codeMint : .white)
                                .tracking(3)

                            Spacer(minLength: 0)

                            FeedbackPegs(feedback: turn.feedback)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            Color.white.opacity(turn.isWinning ? 0.10 : 0.04),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                }
            }
        }
        .glassCard(cornerRadius: 24)
    }

    private var visibleTurns: [GuessTurn] {
        guard game.players.indices.contains(historySeat) else { return [] }
        return game.history(for: game.players[historySeat].id)
    }

    // MARK: Entry

    private func append(_ digit: Int) {
        guard entry.count < SecretCode.length else { return }
        entry.append(String(digit))
    }

    private func deleteDigit() {
        guard !entry.isEmpty else { return }
        entry.removeLast()
    }

    private func submitGuess() {
        guard let turn = game.currentPlayerID else { return }
        if let session {
            do {
                session.submit(.guess(try SecretCode(validating: entry)))
                entry = ""
                errorMessage = nil
                historySeat = mySeat ?? historySeat
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }
        do {
            let code = try SecretCode(validating: entry)
            try localGame.play(code, by: turn)
            entry = ""
            errorMessage = nil
            // Show the guesser their own board after they move.
            if let seat = game.players.firstIndex(where: { $0.id == turn }) {
                historySeat = seat
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func playAgain() {
        showResult = false
        if session != nil {
            reset()
        } else {
            beginSetup()
        }
    }

    private func reset() {
        if let session {
            session.requestRematch()
            entry = ""
            errorMessage = nil
            showResult = false
            return
        }
        localGame = GuessSecretGame()
        computerID = nil
        firstName = ""
        secondName = ""
        entry = ""
        errorMessage = nil
        showResult = false
        stage = .names
    }

    // MARK: Computer

    /// Changes whenever a guess lands, a new board is dealt, or setup finishes.
    /// The last matters when the computer opens: locking in your code changes
    /// nothing else, and its first guess would never come.
    private var computerTurnKey: String {
        "\(game.id)#\(game.turnHistory.count)#\(game.isReadyToPlay)"
    }

    private func playComputerTurn() async {
        guard let computerID, localGame.currentPlayerID == computerID else { return }
        let snapshot = localGame
        let level = difficulty

        // A beat before answering, so the guess reads as a reply.
        try? await Task.sleep(for: .milliseconds(500))
        let guess = await Task.detached(priority: .userInitiated) {
            // Sees only its own guesses and their feedback, never your code.
            ComputerPlayer.move(in: snapshot, for: computerID, difficulty: level)
        }.value

        guard !Task.isCancelled,
            localGame.id == snapshot.id,
            localGame.turnHistory.count == snapshot.turnHistory.count,
            let guess
        else { return }
        do {
            try localGame.play(guess, by: computerID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Stats

    private func recordResult() {
        guard let outcome, revealSettled, recordedGameID != game.id else { return }
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
                // A proven cheat makes the result meaningless — they could have
                // answered every guess as they pleased. Count that the game
                // happened and credit nobody.
                session.opponentCheated
                    ? .decided
                    : (id == session.localPlayerID ? .won : .lost)
            } else {
                .decided
            }
        }
    }

    // MARK: Result copy

    private var resultHeadline: String {
        if case .win(let id) = game.result, computerID != nil {
            return id == computerID ? "Computer cracked it" : "You cracked it"
        }
        if case .win(let id) = game.result {
            return "\(game.player(id: id)?.name ?? "Someone") cracked it"
        }
        return ""
    }

    private var resultDetail: String {
        guard case .win(let winner) = game.result else { return "" }
        let guesses = game.history(for: winner).count
        var detail = "Code broken in \(guesses) guess\(guesses == 1 ? "" : "es")."

        if let computerID, winner == computerID, let code = game.player(id: computerID)?.role {
            detail += " Its code was \(code)."
        }

        if let session {
            if session.opponentCheated {
                detail += " Their reveal didn't match what they committed to — that code moved during the game."
            } else if let revealed = session.revealedOpponentCode {
                detail += " Their code was \(revealed)."
            }
        }

        return detail
    }
}
