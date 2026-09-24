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

    @State private var localGame = GuessSecretGame()
    @State private var firstName = ""
    @State private var secondName = ""
    @State private var entry = ""
    @State private var stage: Stage = .names
    @State private var historySeat = 0
    @State private var showResult = false
    @State private var errorMessage: String?

    private let kind = GameKind.codeCracker

    private var game: GuessSecretGame { session?.codeCracker ?? localGame }
    private var displayError: String? { session?.errorMessage ?? errorMessage }
    /// Over the network you only get to guess on your own turn — and not while
    /// a guess is away being scored by the player who owns the code.
    private var canMove: Bool { session.map { $0.isMyTurn && !$0.isAwaitingFeedback } ?? true }
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
                    namesCard
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
                withAnimation(.easeInOut.delay(0.3)) { showResult = true }
            }
        }
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
        _ = try? newGame.addPlayer(named: firstName.isEmpty ? "Player 1" : firstName)
        _ = try? newGame.addPlayer(named: secondName.isEmpty ? "Player 2" : secondName)
        localGame = newGame
        entry = ""
        errorMessage = nil
        showResult = false
        stage = .handoff(seat: 0)
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
                Text("\(name), pick your code")
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
            if seat == 0 {
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

            if session != nil {
                NetworkTurnHint(isMyTurn: canMove, accent: kind.accent)
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
        firstName = ""
        secondName = ""
        entry = ""
        errorMessage = nil
        showResult = false
        stage = .names
    }

    // MARK: Result copy

    private var resultHeadline: String {
        if case .win(let id) = game.result {
            return "\(game.player(id: id)?.name ?? "Someone") cracked it"
        }
        return ""
    }

    private var resultDetail: String {
        let guesses = visibleTurns.count
        var detail = "Code broken in \(guesses) guess\(guesses == 1 ? "" : "es")."

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
