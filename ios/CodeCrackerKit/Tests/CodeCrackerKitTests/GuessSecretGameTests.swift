import Testing

@testable import CodeCrackerKit

@Suite("GuessSecretGame")
struct GuessSecretGameTests {
    @Test("is not playable until both players have chosen a secret")
    func setupAndStart() throws {
        var game = try makeGuessSecretGame()
        #expect(!game.isReadyToPlay)
        #expect(game.status == .waitingForSetup)
        #expect(game.currentPlayerID == nil)

        try game.setSecret(code("1234"), for: player1ID)
        #expect(!game.isReadyToPlay)

        try game.setSecret(code("5678"), for: player2ID)
        #expect(game.isReadyToPlay)
        #expect(game.status == .inProgress)
        #expect(game.currentPlayerID == player1ID)
    }

    @Test("reports waiting for players before the second seat is filled")
    func waitingForPlayers() throws {
        var game = GuessSecretGame(id: "solo")
        try game.addPlayer(Player(id: player1ID, name: "Player1", role: nil))
        #expect(game.status == .waitingForPlayers)
    }

    @Test("refuses a third player")
    func gameIsFull() throws {
        var game = try makeGuessSecretGame()
        #expect(throws: GameError.gameIsFull) {
            try game.addPlayer(Player(name: "Player3", role: nil))
        }
    }

    @Test("a secret can only be set once")
    func secretIsWriteOnce() throws {
        var game = try makeGuessSecretGame()
        try game.setSecret(code("1234"), for: player1ID)
        #expect(throws: GameError.secretAlreadySet) {
            try game.setSecret(code("4321"), for: player1ID)
        }
        #expect(game.player1?.role == (try? code("1234")))
    }

    @Test("rejects a secret for an unknown player")
    func unknownPlayerSecret() throws {
        var game = try makeGuessSecretGame()
        #expect(throws: GameError.unknownPlayer) {
            try game.setSecret(code("1234"), for: PlayerID())
        }
    }

    @Test("the second player cannot open")
    func turnEnforcement() throws {
        var game = try makeGuessSecretGame()
        try game.setSecret(code("1234"), for: player1ID)
        try game.setSecret(code("5678"), for: player2ID)

        #expect(throws: GameError.notYourTurn) {
            try game.play(code("1234"), by: player2ID)
        }
    }

    @Test("turns alternate strictly")
    func turnsAlternate() throws {
        var game = try makeGuessSecretGame()
        try game.setSecret(code("1234"), for: player1ID)
        try game.setSecret(code("5678"), for: player2ID)

        try game.play(code("1357"), by: player1ID)
        #expect(game.currentPlayerID == player2ID)

        #expect(throws: GameError.notYourTurn) {
            try game.play(code("2468"), by: player1ID)
        }

        try game.play(code("2468"), by: player2ID)
        #expect(game.currentPlayerID == player1ID)
    }

    @Test("guessing the opponent's secret exactly wins")
    func winningGuess() throws {
        var game = try makeGuessSecretGame()
        try game.setSecret(code("1234"), for: player1ID)
        try game.setSecret(code("5678"), for: player2ID)

        let outcome = try game.play(code("5678"), by: player1ID)

        #expect(outcome == .win(player1ID))
        #expect(game.result == .win(player1ID))
        #expect(game.isOver)
        #expect(game.winner == game.player1)
        #expect(game.status == .over)
        #expect(game.currentPlayerID == nil)
    }

    @Test("a wrong guess records feedback and keeps the game going")
    func losingGuessRecordsHistory() throws {
        var game = try makeGuessSecretGame()
        try game.setSecret(code("1234"), for: player1ID)
        try game.setSecret(code("5678"), for: player2ID)

        let outcome = try game.play(code("5687"), by: player1ID)

        #expect(outcome == .ongoing)
        #expect(!game.isOver)
        #expect(game.turnHistory.count == 1)

        let turn = try #require(game.turnHistory.first)
        #expect(turn.playerID == player1ID)
        #expect(turn.playerName == "Player1")
        #expect(turn.guess.description == "5687")
        #expect(turn.feedback.correctPositions == 2)
        #expect(turn.feedback.correctDigits == 2)
        #expect(!turn.isWinning)
        #expect(game.history(for: player2ID).isEmpty)
    }

    @Test("no move is accepted before both secrets are in")
    func cannotPlayBeforeSetup() throws {
        var game = try makeGuessSecretGame()
        try game.setSecret(code("1234"), for: player1ID)

        #expect(throws: GameError.gameIsNotReady) {
            try game.play(code("5678"), by: player1ID)
        }
    }

    @Test("no move is accepted after the game ends")
    func cannotPlayAfterGameOver() throws {
        var game = try makeGuessSecretGame()
        try game.setSecret(code("1234"), for: player1ID)
        try game.setSecret(code("5678"), for: player2ID)
        try game.play(code("5678"), by: player1ID)

        #expect(throws: GameError.gameIsAlreadyOver) {
            try game.play(code("1234"), by: player2ID)
        }
    }
}
