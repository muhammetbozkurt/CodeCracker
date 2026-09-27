import Testing

@testable import CodeCrackerKit

/// A seeded generator, so tests that exercise random tie-breaking are repeatable.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("ComputerPlayer · Tic-Tac-Toe")
struct TicTacToeComputerTests {
    @Test("has no move when it isn't that seat's turn, or the game is over")
    func noMoveOutOfTurn() throws {
        var game = try makeTicTacToeGame()
        var rng = SplitMix64(state: 1)
        #expect(ComputerPlayer.move(in: game, for: player2ID, difficulty: .hard, using: &rng) == nil)

        for cell in [0, 3, 1, 4, 2] {
            try game.play(cell, by: game.currentPlayerID!)
        }
        #expect(game.isOver)
        #expect(ComputerPlayer.move(in: game, for: player2ID, difficulty: .hard, using: &rng) == nil)
    }

    @Test("only ever picks a legal cell", arguments: Difficulty.allCases)
    func legalMoves(difficulty: Difficulty) throws {
        var rng = SplitMix64(state: 7)
        for _ in 0..<50 {
            var game = try makeTicTacToeGame()
            while !game.isOver {
                let turn = game.currentPlayerID!
                let level = turn == player1ID ? difficulty : .easy
                let cell = try #require(ComputerPlayer.move(in: game, for: turn, difficulty: level, using: &rng))
                try game.play(cell, by: turn)
            }
        }
    }

    @Test("takes a win rather than blocking", arguments: [Difficulty.medium, .hard])
    func takesWin(difficulty: Difficulty) throws {
        // X: 0, 1 — O: 3, 4. Both threaten; X should finish at 2, not block 5.
        var game = try makeTicTacToeGame()
        for cell in [0, 3, 1, 4] {
            try game.play(cell, by: game.currentPlayerID!)
        }
        var rng = SplitMix64(state: 3)
        #expect(ComputerPlayer.move(in: game, for: player1ID, difficulty: difficulty, using: &rng) == 2)
    }

    @Test("blocks an immediate threat", arguments: [Difficulty.medium, .hard])
    func blocks(difficulty: Difficulty) throws {
        // X: 0, 1 — O: 4. O must take 2.
        var game = try makeTicTacToeGame()
        for cell in [0, 4, 1] {
            try game.play(cell, by: game.currentPlayerID!)
        }
        var rng = SplitMix64(state: 3)
        #expect(ComputerPlayer.move(in: game, for: player2ID, difficulty: difficulty, using: &rng) == 2)
    }

    @Test("hard never loses, whichever seat it takes and whatever the opponent plays")
    func hardNeverLoses() throws {
        for computer in [player1ID, player2ID] {
            var rng = SplitMix64(state: 11)
            try exploreEveryReply(try makeTicTacToeGame(), computer: computer, rng: &rng)
        }
    }

    @Test("hard against hard is always a draw")
    func hardVersusHardDraws() throws {
        for seed in 0..<10 {
            var rng = SplitMix64(state: UInt64(seed))
            var game = try makeTicTacToeGame()
            while !game.isOver {
                let turn = game.currentPlayerID!
                let cell = try #require(ComputerPlayer.move(in: game, for: turn, difficulty: .hard, using: &rng))
                try game.play(cell, by: turn)
            }
            #expect(game.isDraw)
        }
    }

    /// Plays the computer's move on its turns and every legal cell on the
    /// opponent's, checking each finished game.
    private func exploreEveryReply(
        _ game: TicTacToeGame,
        computer: PlayerID,
        rng: inout SplitMix64
    ) throws {
        if game.isOver {
            if case .win(let winner) = game.result {
                #expect(winner == computer, "lost after \(game.turnHistory.map(\.cell))")
            }
            return
        }

        let turn = try #require(game.currentPlayerID)
        if turn == computer {
            var next = game
            let cell = try #require(ComputerPlayer.move(in: game, for: computer, difficulty: .hard, using: &rng))
            try next.play(cell, by: computer)
            try exploreEveryReply(next, computer: computer, rng: &rng)
        } else {
            for cell in game.availableCells {
                var next = game
                try next.play(cell, by: turn)
                try exploreEveryReply(next, computer: computer, rng: &rng)
            }
        }
    }
}

@Suite("ComputerPlayer · CodeCracker")
struct CodeCrackerComputerTests {
    @Test("has no move before both codes are set, or when it isn't that seat's turn")
    func noMoveOutOfTurn() throws {
        var game = try makeGuessSecretGame()
        var rng = SplitMix64(state: 1)
        #expect(ComputerPlayer.move(in: game, for: player1ID, difficulty: .hard, using: &rng) == nil)

        try game.setSecret(try code("1234"), for: player1ID)
        try game.setSecret(try code("5678"), for: player2ID)
        #expect(ComputerPlayer.move(in: game, for: player2ID, difficulty: .hard, using: &rng) == nil)
    }

    @Test(
        "cracks every sampled code within its limit, never repeating a guess",
        arguments: [(Difficulty.easy, 40), (.medium, 10), (.hard, 8)]
    )
    func cracksCodes(difficulty: Difficulty, limit: Int) throws {
        var targets = SplitMix64(state: 42)
        var rng = SplitMix64(state: 7)
        for _ in 0..<50 {
            let target = ComputerPlayer.secret(using: &targets)
            let guesses = try crack(target, difficulty: difficulty, rng: &rng)

            #expect(guesses.count <= limit, "took \(guesses.count) guesses to crack \(target)")
            #expect(Set(guesses.map(\.guess)).count == guesses.count, "repeated a guess against \(target)")

            // Easy ignores where digits sit, so only medium and hard promise
            // every guess could still have been the answer.
            guard difficulty != .easy else { continue }
            for (index, turn) in guesses.enumerated() {
                let fits = guesses[..<index].allSatisfy { $0.guess.feedback(against: turn.guess) == $0.feedback }
                #expect(fits, "guess \(index + 1) (\(turn.guess)) contradicts earlier feedback for \(target)")
            }
        }
    }

    @Test("two computers play a full game through the rules")
    func computerVersusComputer() throws {
        var rng = SplitMix64(state: 5)
        var game = try makeGuessSecretGame()
        try game.setSecret(ComputerPlayer.secret(using: &rng), for: player1ID)
        try game.setSecret(ComputerPlayer.secret(using: &rng), for: player2ID)

        while !game.isOver {
            let turn = try #require(game.currentPlayerID)
            let guess = try #require(ComputerPlayer.move(in: game, for: turn, difficulty: .hard, using: &rng))
            try game.play(guess, by: turn)
        }
        #expect(game.winner != nil)
    }

    /// Plays the computer in seat 1 until it cracks `target`, returning its
    /// guesses. Seat 2 keeps guessing a code that never matches seat 1's.
    private func crack(
        _ target: SecretCode,
        difficulty: Difficulty,
        rng: inout SplitMix64
    ) throws -> [GuessTurn] {
        var game = try makeGuessSecretGame()
        try game.setSecret(try code("9876"), for: player1ID)
        try game.setSecret(target, for: player2ID)

        while !game.isOver {
            let guess = try #require(ComputerPlayer.move(in: game, for: player1ID, difficulty: difficulty, using: &rng))
            try game.play(guess, by: player1ID)
            if !game.isOver { try game.play(try code("1234"), by: player2ID) }
        }
        #expect(game.winner?.id == player1ID)
        return game.history(for: player1ID)
    }
}

@Suite("ComputerPlayer · Connect 4")
struct Connect4ComputerTests {
    @Test("has no move when it isn't that seat's turn, or the game is over")
    func noMoveOutOfTurn() throws {
        var game = try makeConnect4Game()
        var rng = SplitMix64(state: 1)
        #expect(ComputerPlayer.move(in: game, for: player2ID, difficulty: .hard, using: &rng) == nil)

        try play([0, 6, 1, 6, 2, 6, 3], in: &game)
        #expect(game.isOver)
        #expect(ComputerPlayer.move(in: game, for: player2ID, difficulty: .hard, using: &rng) == nil)
    }

    @Test(
        "only ever picks a column with room",
        arguments: [(Difficulty.easy, 30), (.medium, 30), (.hard, 4)]
    )
    func legalMoves(difficulty: Difficulty, games: Int) throws {
        var rng = SplitMix64(state: 7)
        for _ in 0..<games {
            var game = try makeConnect4Game()
            while !game.isOver {
                let turn = game.currentPlayerID!
                let level = turn == player1ID ? difficulty : .easy
                let column = try #require(ComputerPlayer.move(in: game, for: turn, difficulty: level, using: &rng))
                try game.play(column, by: turn)
            }
        }
    }

    @Test("takes a win rather than blocking", arguments: [Difficulty.medium, .hard])
    func takesWin(difficulty: Difficulty) throws {
        // Red: bottom row 0-2. Yellow: three up column 6. Red finishes at 3.
        var game = try makeConnect4Game()
        try play([0, 6, 1, 6, 2, 6], in: &game)
        var rng = SplitMix64(state: 3)
        #expect(ComputerPlayer.move(in: game, for: player1ID, difficulty: difficulty, using: &rng) == 3)
    }

    @Test("blocks an immediate threat", arguments: [Difficulty.medium, .hard])
    func blocks(difficulty: Difficulty) throws {
        // Red: bottom row 0-2. Yellow must take 3.
        var game = try makeConnect4Game()
        try play([0, 6, 1, 6, 2], in: &game)
        var rng = SplitMix64(state: 3)
        #expect(ComputerPlayer.move(in: game, for: player2ID, difficulty: difficulty, using: &rng) == 3)
    }

    @Test("never hands over a win it could have avoided", arguments: [Difficulty.medium, .hard])
    func noFreeWins(difficulty: Difficulty) throws {
        var rng = SplitMix64(state: 21)
        var checked = 0
        while checked < 30 {
            // A random mid-game position that is still open.
            var game = try makeConnect4Game()
            for _ in 0..<Int.random(in: 6...20, using: &rng) where !game.isOver {
                try game.play(game.availableColumns.randomElement(using: &rng)!, by: game.currentPlayerID!)
            }
            guard !game.isOver else { continue }

            let turn = game.currentPlayerID!
            let safe = try game.availableColumns.filter { try !opponentCanWin(after: $0, in: game) }
            guard !safe.isEmpty else { continue }

            let column = try #require(ComputerPlayer.move(in: game, for: turn, difficulty: difficulty, using: &rng))
            #expect(safe.contains(column), "played \(column) after \(game.turnHistory.map(\.column)); safe: \(safe)")
            checked += 1
        }
    }

    @Test("hard beats easy from either seat")
    func hardBeatsEasy() throws {
        var rng = SplitMix64(state: 5)
        for index in 0..<6 {
            let hard = index.isMultiple(of: 2) ? player1ID : player2ID
            var game = try makeConnect4Game()
            while !game.isOver {
                let turn = game.currentPlayerID!
                let level: Difficulty = turn == hard ? .hard : .easy
                let column = try #require(ComputerPlayer.move(in: game, for: turn, difficulty: level, using: &rng))
                try game.play(column, by: turn)
            }
            #expect(game.winner?.id == hard, "game \(index): \(game.turnHistory.map(\.column))")
        }
    }

    private func play(_ columns: [Int], in game: inout Connect4Game) throws {
        for column in columns {
            try game.play(column, by: game.currentPlayerID!)
        }
    }

    /// Whether playing `column` lets the other side win with their very next
    /// drop. A move that wins outright hands nothing over.
    private func opponentCanWin(after column: Int, in game: Connect4Game) throws -> Bool {
        var next = game
        try next.play(column, by: game.currentPlayerID!)
        guard !next.isOver, let opponent = next.currentPlayerID else { return false }
        return try next.availableColumns.contains { reply in
            var after = next
            try after.play(reply, by: opponent)
            return after.winner?.id == opponent
        }
    }
}
