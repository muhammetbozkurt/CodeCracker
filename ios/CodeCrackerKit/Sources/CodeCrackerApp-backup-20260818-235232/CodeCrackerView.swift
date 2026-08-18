import SwiftUI

private enum Phase: Equatable {
    case names
    case handoff(nextPlayerIndex: Int)
    case secret(playerIndex: Int)
    case playing
}

struct CodeCrackerView: View {
    @State private var game = GuessSecretGame()
    @State private var player1Name = ""
    @State private var player2Name = ""
    @State private var secretInput = ""
    @State private var guessInput = ""
    @State private var phase: Phase = .names
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack {
                Spacer(minLength: 0)
                card
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .navigationTitle("CodeCracker")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: phase)
    }

    private var card: some View {
        VStack(spacing: 20) {
            switch phase {
            case .names:
                namesSection
            case .handoff(let next):
                handoffSection(nextPlayerIndex: next)
            case .secret(let index):
                secretSection(playerIndex: index)
            case .playing:
                playingSection
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        }
        .cardBackground()
    }

    private var namesSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.purple.gradient)
            Text("Each player hides a 4-digit code with no repeated digits, then you take turns guessing each other's.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                AppTextField(title: "Player 1 name", text: $player1Name, systemImage: "person.fill")
                AppTextField(title: "Player 2 name", text: $player2Name, systemImage: "person.fill")
            }
            PrimaryButton(title: "Continue", systemImage: "arrow.right") { startSetup() }
        }
    }

    private func startSetup() {
        var newGame = GuessSecretGame()
        _ = try? newGame.addPlayer(named: player1Name.isEmpty ? "Player 1" : player1Name)
        _ = try? newGame.addPlayer(named: player2Name.isEmpty ? "Player 2" : player2Name)
        game = newGame
        errorMessage = nil
        phase = .handoff(nextPlayerIndex: 0)
    }

    private func handoffSection(nextPlayerIndex: Int) -> some View {
        let name = game.players[nextPlayerIndex].name
        return VStack(spacing: 16) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Pass the device to \(name)").font(.title3.bold())
            Text("Only they should see the next screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            PrimaryButton(title: "I'm \(name), let me in", systemImage: "hand.tap.fill") {
                secretInput = ""
                errorMessage = nil
                phase = .secret(playerIndex: nextPlayerIndex)
            }
        }
    }

    private func secretSection(playerIndex: Int) -> some View {
        let name = game.players[playerIndex].name
        return VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 44))
                .foregroundStyle(.purple.gradient)
            Text("\(name), choose your secret code").font(.title3.bold())
            Text("4 digits, all different.").font(.footnote).foregroundStyle(.secondary)
            AppTextField(
                title: "e.g. 5678",
                text: $secretInput,
                systemImage: "number",
                keyboard: .numberPad,
                isSecure: true
            )
            PrimaryButton(title: "Set Secret", systemImage: "lock.fill") { setSecret(playerIndex: playerIndex) }
        }
    }

    private func setSecret(playerIndex: Int) {
        do {
            let code = try SecretCode(validating: secretInput)
            try game.setSecret(code, for: game.players[playerIndex].id)
            errorMessage = nil
            phase = playerIndex == 0 ? .handoff(nextPlayerIndex: 1) : .playing
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var playingSection: some View {
        VStack(spacing: 18) {
            statusBanner

            if !game.isOver {
                HStack(spacing: 10) {
                    AppTextField(title: "Your guess", text: $guessInput, systemImage: "number", keyboard: .numberPad)
                    Button {
                        submitGuess()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill").font(.system(size: 32))
                    }
                }
            }

            historySection

            if game.isOver {
                SecondaryButton(title: "Play Again") { reset() }
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
                    StatusBadge(text: "\(player.name)'s turn", tint: .purple)
                }
            }
        }
    }

    private var historySection: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(game.players) { player in
                VStack(alignment: .leading, spacing: 8) {
                    Text(player.name).font(.subheadline.bold())
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(game.history(for: player.id).enumerated()), id: \.offset) { _, turn in
                            HStack(spacing: 6) {
                                Text(turn.guess.description).font(.callout.monospaced().bold())
                                Spacer()
                                Text("\(turn.feedback.correctPositions)\u{25cf}").foregroundStyle(.green)
                                Text("\(turn.feedback.correctDigits)\u{25cb}").foregroundStyle(.orange)
                            }
                            .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func submitGuess() {
        guard let turn = game.currentPlayerID else { return }
        do {
            let code = try SecretCode(validating: guessInput)
            try game.play(code, by: turn)
            guessInput = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reset() {
        game = GuessSecretGame()
        player1Name = ""
        player2Name = ""
        secretInput = ""
        guessInput = ""
        errorMessage = nil
        phase = .names
    }
}
