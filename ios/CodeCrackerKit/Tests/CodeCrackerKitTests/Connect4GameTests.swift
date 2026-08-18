import Testing

@testable import CodeCrackerKit

@Suite("Connect4Game")
struct Connect4GameTests {
    @Test("is playable as soon as both seats are filled")
    func setupAndStart() throws {
        let game = try makeConnect4Game()
        #expect(game.isReadyToPlay)
        #expect(game.currentPlayerID == player1ID)
        #expect(game.board.count == 42)
        #expect(game.availableColumns == Array(0..<7))
    }

    @Test("the second player cannot open")
    func turnEnforcement() throws {
        var game = try makeConnect4Game()
        #expect(throws: GameError.notYourTurn) {
            try game.play(0, by: player2ID)
        }
    }

    @Test("an out-of-bounds column is rejected", arguments: [7, -1, 42])
    func outOfBounds(_ column: Int) throws {
        var game = try makeConnect4Game()
        #expect(throws: GameError.columnIsFull) {
            try game.play(column, by: player1ID)
        }
    }

    @Test("discs stack from the bottom up")
    func discsStack() throws {
        var game = try makeConnect4Game()
        try game.play(3, by: player1ID)
        #expect(game.disc(row: 5, column: 3) == .red)
        #expect(game.disc(row: 4, column: 3) == nil)

        try game.play(3, by: player2ID)
        #expect(game.disc(row: 4, column: 3) == .yellow)
        #expect(game.turnHistory.last?.row == 4)
    }

    @Test("a filled column is rejected")
    func columnFills() throws {
        var game = try makeConnect4Game()
        // Alternating in one column never makes four of the same colour.
        for turn in 0..<6 {
            try game.play(0, by: turn.isMultiple(of: 2) ? player1ID : player2ID)
        }
        #expect(!game.isOver)
        #expect(game.landingRow(inColumn: 0) == nil)
        #expect(game.availableColumns == Array(1..<7))

        #expect(throws: GameError.columnIsFull) {
            try game.play(0, by: player1ID)
        }
    }

    @Test("four stacked discs win")
    func verticalWin() throws {
        var game = try makeConnect4Game()
        for _ in 0..<3 {
            try game.play(0, by: player1ID)
            try game.play(1, by: player2ID)
        }
        let outcome = try game.play(0, by: player1ID)

        #expect(outcome == .win(player1ID))
        #expect(game.isOver)
        #expect(game.winner == game.player1)
        #expect(game.winningCells == [14, 21, 28, 35])  // rows 2–5 of column 0
        #expect(game.currentPlayerID == nil)
    }

    @Test("four discs along a row win")
    func horizontalWin() throws {
        var game = try makeConnect4Game()
        for column in 0..<3 {
            try game.play(column, by: player1ID)
            try game.play(column, by: player2ID)
        }
        let outcome = try game.play(3, by: player1ID)

        #expect(outcome == .win(player1ID))
        #expect(game.winningCells == [35, 36, 37, 38])  // bottom row, columns 0–3
    }

    @Test("four discs along a diagonal win")
    func diagonalWin() throws {
        var game = try makeConnect4Game()
        let moves = [
            (player1ID, 0), (player2ID, 1),
            (player1ID, 1), (player2ID, 2),
            (player1ID, 6), (player2ID, 2),
            (player1ID, 2), (player2ID, 3),
            (player1ID, 5), (player2ID, 3),
            (player1ID, 4), (player2ID, 3),
        ]
        for (player, column) in moves {
            let outcome = try game.play(column, by: player)
            #expect(outcome == .ongoing, "no win expected before the final move")
        }

        let outcome = try game.play(3, by: player1ID)

        #expect(outcome == .win(player1ID))
        // (5,0) (4,1) (3,2) (2,3) — an upward diagonal.
        #expect(game.winningCells == [17, 23, 29, 35])
    }

    @Test("no move is accepted after the game ends")
    func cannotPlayAfterGameOver() throws {
        var game = try makeConnect4Game()
        for _ in 0..<3 {
            try game.play(0, by: player1ID)
            try game.play(1, by: player2ID)
        }
        try game.play(0, by: player1ID)

        #expect(throws: GameError.gameIsAlreadyOver) {
            try game.play(2, by: player2ID)
        }
    }
}
