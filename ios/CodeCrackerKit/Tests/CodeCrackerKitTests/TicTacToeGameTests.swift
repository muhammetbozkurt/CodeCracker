import Testing

@testable import CodeCrackerKit

@Suite("TicTacToeGame")
struct TicTacToeGameTests {
    @Test("is playable as soon as both seats are filled")
    func setupAndStart() throws {
        let game = try makeTicTacToeGame()
        #expect(game.isReadyToPlay)
        #expect(game.currentPlayerID == player1ID)
        #expect(game.board.count == 9)
        #expect(game.availableCells.count == 9)
        #expect(game.status == .inProgress)
    }

    @Test("the second player cannot open")
    func turnEnforcement() throws {
        var game = try makeTicTacToeGame()
        #expect(throws: GameError.notYourTurn) {
            try game.play(0, by: player2ID)
        }
    }

    @Test("an occupied cell is rejected")
    func occupiedCell() throws {
        var game = try makeTicTacToeGame()
        try game.play(0, by: player1ID)

        #expect(throws: GameError.cellOccupied) {
            try game.play(0, by: player2ID)
        }
        // The rejected move must not have consumed the turn.
        #expect(game.currentPlayerID == player2ID)
    }

    @Test("an out-of-bounds cell is rejected", arguments: [9, -1, 100])
    func outOfBounds(_ cell: Int) throws {
        var game = try makeTicTacToeGame()
        #expect(throws: GameError.cellOccupied) {
            try game.play(cell, by: player1ID)
        }
    }

    @Test("a move by someone not in the game is rejected")
    func unknownPlayer() throws {
        var game = try makeTicTacToeGame()
        #expect(throws: GameError.unknownPlayer) {
            try game.play(0, by: PlayerID())
        }
    }

    @Test("three in a row wins")
    func topRowWin() throws {
        var game = try makeTicTacToeGame()
        try game.play(0, by: player1ID)
        try game.play(3, by: player2ID)
        try game.play(1, by: player1ID)
        try game.play(4, by: player2ID)
        let outcome = try game.play(2, by: player1ID)

        #expect(outcome == .win(player1ID))
        #expect(game.isOver)
        #expect(game.winner == game.player1)
        #expect(game.winningLine == [0, 1, 2])
        #expect(game.currentPlayerID == nil)
        #expect(game.status == .over)
    }

    @Test("a column win is detected")
    func columnWin() throws {
        var game = try makeTicTacToeGame()
        try game.play(0, by: player1ID)
        try game.play(1, by: player2ID)
        try game.play(3, by: player1ID)
        try game.play(4, by: player2ID)
        let outcome = try game.play(6, by: player1ID)

        #expect(outcome == .win(player1ID))
        #expect(game.winningLine == [0, 3, 6])
    }

    @Test("a diagonal win is detected")
    func diagonalWin() throws {
        var game = try makeTicTacToeGame()
        try game.play(0, by: player1ID)
        try game.play(1, by: player2ID)
        try game.play(4, by: player1ID)
        try game.play(2, by: player2ID)
        let outcome = try game.play(8, by: player1ID)

        #expect(outcome == .win(player1ID))
        #expect(game.winningLine == [0, 4, 8])
    }

    @Test("a full board with no line is a draw")
    func draw() throws {
        var game = try makeTicTacToeGame()
        let moves = [
            (player1ID, 0), (player2ID, 1),
            (player1ID, 2), (player2ID, 4),
            (player1ID, 3), (player2ID, 5),
            (player1ID, 7), (player2ID, 6),
            (player1ID, 8),
        ]

        var outcome = MoveOutcome.ongoing
        for (player, cell) in moves {
            outcome = try game.play(cell, by: player)
        }

        #expect(outcome == .draw)
        #expect(game.isDraw)
        #expect(game.isOver)
        #expect(game.winner == nil)
        #expect(game.winningLine == nil)
        #expect(game.availableCells.isEmpty)
    }

    @Test("history records who played what")
    func history() throws {
        var game = try makeTicTacToeGame()
        try game.play(4, by: player1ID)
        try game.play(0, by: player2ID)

        #expect(game.turnHistory.count == 2)
        #expect(game.turnHistory[0] == TicTacToeTurn(
            playerID: player1ID, playerName: "Player1", cell: 4, mark: .x
        ))
        #expect(game.mark(row: 1, column: 1) == .x)
        #expect(game.mark(row: 0, column: 0) == .o)
        #expect(game.mark(row: 2, column: 2) == nil)
    }
}
