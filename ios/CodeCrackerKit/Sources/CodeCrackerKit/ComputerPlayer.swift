import Foundation

/// How hard a computer-controlled seat tries.
public enum Difficulty: String, CaseIterable, Sendable, Codable {
    case easy
    case medium
    case hard
}

/// Chooses moves for a computer-controlled seat.
///
/// Every strategy is pure: it reads the game and returns a move, and never
/// mutates it. The caller plays that move through `play(_:by:)` like any other,
/// so the computer is held to exactly the same rules as a person. A strategy
/// returns `nil` when it is not that seat's turn.
public enum ComputerPlayer {}

// MARK: - Tic-Tac-Toe

extension ComputerPlayer {
    /// - Easy plays any open cell.
    /// - Medium takes a win when it has one, blocks yours when it doesn't, and
    ///   otherwise plays anywhere.
    /// - Hard plays perfectly: it never loses, and wins as soon as it can.
    public static func move<G: RandomNumberGenerator>(
        in game: TicTacToeGame,
        for playerID: PlayerID,
        difficulty: Difficulty,
        using generator: inout G
    ) -> Int? {
        guard game.currentPlayerID == playerID, let mark = game.player(id: playerID)?.role else {
            return nil
        }
        let open = game.availableCells

        switch difficulty {
        case .easy:
            return open.randomElement(using: &generator)
        case .medium:
            let winning = open.filter { completesLine(game.board, at: $0, for: mark) }
            if let cell = winning.randomElement(using: &generator) { return cell }
            let blocking = open.filter { completesLine(game.board, at: $0, for: mark.opponent) }
            if let cell = blocking.randomElement(using: &generator) { return cell }
            return open.randomElement(using: &generator)
        case .hard:
            var board = game.board
            var bestScore = Int.min
            var best: [Int] = []
            for cell in open {
                board[cell] = mark
                let score = hasLine(board, for: mark)
                    ? winScore(board)
                    : -negamax(&board, toMove: mark.opponent, alpha: -.max, beta: .max)
                board[cell] = nil

                if score > bestScore {
                    bestScore = score
                    best = [cell]
                } else if score == bestScore {
                    best.append(cell)
                }
            }
            return best.randomElement(using: &generator)
        }
    }

    public static func move(
        in game: TicTacToeGame,
        for playerID: PlayerID,
        difficulty: Difficulty
    ) -> Int? {
        var generator = SystemRandomNumberGenerator()
        return move(in: game, for: playerID, difficulty: difficulty, using: &generator)
    }

    /// The value of `board` to the side about to play `mark`, assuming the
    /// previous move did not end the game: positive is a win, negative a loss,
    /// zero a draw. Works on a bare board so the search does not copy history
    /// and timestamps at every node. Alpha-beta pruned: once a reply is found
    /// that the opponent would never allow, the rest of this node is skipped.
    private static func negamax(_ board: inout [Mark?], toMove mark: Mark, alpha: Int, beta: Int) -> Int {
        var alpha = alpha
        var best: Int?
        for cell in board.indices where board[cell] == nil {
            board[cell] = mark
            let score = hasLine(board, for: mark)
                ? winScore(board)
                : -negamax(&board, toMove: mark.opponent, alpha: -beta, beta: -alpha)
            board[cell] = nil
            best = max(best ?? score, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }
        }
        return best ?? 0
    }

    /// Winning with more of the board left empty scores higher, so the search
    /// prefers the quickest win and, when losing, the slowest loss.
    private static func winScore(_ board: [Mark?]) -> Int {
        1 + board.filter { $0 == nil }.count
    }

    private static func hasLine(_ board: [Mark?], for mark: Mark) -> Bool {
        TicTacToeGame.lines.contains { line in line.allSatisfy { board[$0] == mark } }
    }

    private static func completesLine(_ board: [Mark?], at cell: Int, for mark: Mark) -> Bool {
        var board = board
        board[cell] = mark
        return hasLine(board, for: mark)
    }
}

// MARK: - CodeCracker

extension ComputerPlayer {
    /// Every legal code — four distinct digits, no leading zero. 4,536 of them.
    static let allCodes: [SecretCode] = (1000...9999).compactMap { SecretCode(String($0)) }

    /// A code for the computer to hide.
    public static func secret<G: RandomNumberGenerator>(using generator: inout G) -> SecretCode {
        allCodes.randomElement(using: &generator)!
    }

    public static func secret() -> SecretCode {
        var generator = SystemRandomNumberGenerator()
        return secret(using: &generator)
    }

    /// - Easy only listens to how many digits it got right, not where.
    /// - Medium guesses any code that fits every answer so far.
    /// - Hard picks the guess whose worst-case answer leaves the fewest codes
    ///   standing.
    ///
    /// On one device the opponent's code sits in the same `GuessSecretGame`, so
    /// this reads the game only for whose turn it is and this seat's own
    /// guesses; the solver never sees anything else.
    public static func move<G: RandomNumberGenerator>(
        in game: GuessSecretGame,
        for playerID: PlayerID,
        difficulty: Difficulty,
        using generator: inout G
    ) -> SecretCode? {
        guard game.currentPlayerID == playerID else { return nil }
        return guess(after: game.history(for: playerID), difficulty: difficulty, using: &generator)
    }

    public static func move(
        in game: GuessSecretGame,
        for playerID: PlayerID,
        difficulty: Difficulty
    ) -> SecretCode? {
        var generator = SystemRandomNumberGenerator()
        return move(in: game, for: playerID, difficulty: difficulty, using: &generator)
    }

    /// The next guess, from nothing but the guesses made so far and the
    /// feedback each one got.
    static func guess<G: RandomNumberGenerator>(
        after history: [GuessTurn],
        difficulty: Difficulty,
        using generator: inout G
    ) -> SecretCode {
        let tried = Set(history.map(\.guess))
        let candidates: [SecretCode]
        switch difficulty {
        case .easy:
            candidates = allCodes.filter { code in
                !tried.contains(code) && history.allSatisfy {
                    digitsRight($0.guess.feedback(against: code)) == digitsRight($0.feedback)
                }
            }
        case .medium, .hard:
            candidates = allCodes.filter { code in
                history.allSatisfy { $0.guess.feedback(against: code) == $0.feedback }
            }
        }

        // Only reachable if the feedback contradicted itself. Still guess
        // something new rather than stall.
        guard !candidates.isEmpty else {
            return allCodes.filter { !tried.contains($0) }.randomElement(using: &generator)!
        }
        if difficulty == .hard, !history.isEmpty {
            return minimaxGuess(from: candidates, using: &generator)
        }
        return candidates.randomElement(using: &generator)!
    }

    /// Scoring costs candidates × guesses weighed, so while the field is still
    /// wide, hard weighs a random sample of this many rather than all of them.
    private static let hardGuessPool = 150

    private static func minimaxGuess<G: RandomNumberGenerator>(
        from candidates: [SecretCode],
        using generator: inout G
    ) -> SecretCode {
        let pool = candidates.count <= hardGuessPool
            ? candidates
            : Array(candidates.shuffled(using: &generator).prefix(hardGuessPool))

        var bestWorst = Int.max
        var best: [SecretCode] = []
        for guess in pool {
            // One bucket per possible answer: positions × 5 + misplaced digits.
            var buckets = [Int](repeating: 0, count: 25)
            for code in candidates {
                let feedback = guess.feedback(against: code)
                buckets[feedback.correctPositions * 5 + feedback.correctDigits] += 1
            }
            let worst = buckets.max()!

            if worst < bestWorst {
                bestWorst = worst
                best = [guess]
            } else if worst == bestWorst {
                best.append(guess)
            }
        }
        return best.randomElement(using: &generator)!
    }

    private static func digitsRight(_ feedback: Feedback) -> Int {
        feedback.correctPositions + feedback.correctDigits
    }
}

// MARK: - Connect 4

extension ComputerPlayer {
    /// - Easy drops into any open column.
    /// - Medium looks one exchange ahead: it takes a win, blocks yours, won't
    ///   hand you one by filling the square beneath it, and spots a reply that
    ///   would leave it a win.
    /// - Hard searches six plies ahead and scores what lies beyond by the lines
    ///   of four each side can still complete.
    public static func move<G: RandomNumberGenerator>(
        in game: Connect4Game,
        for playerID: PlayerID,
        difficulty: Difficulty,
        using generator: inout G
    ) -> Int? {
        guard game.currentPlayerID == playerID, let disc = game.player(id: playerID)?.role else {
            return nil
        }
        let open = game.availableColumns
        guard difficulty != .easy else { return open.randomElement(using: &generator) }

        let depth = difficulty == .hard ? 6 : 2
        var board = game.board
        var bestScore = Int.min
        var best: [Int] = []
        for column in open {
            let score = scoreDrop(&board, column: column, disc: disc, depth: depth, alpha: -.max, beta: .max)
            if score > bestScore {
                bestScore = score
                best = [column]
            } else if score == bestScore {
                best.append(column)
            }
        }
        return best.randomElement(using: &generator)
    }

    public static func move(
        in game: Connect4Game,
        for playerID: PlayerID,
        difficulty: Difficulty
    ) -> Int? {
        var generator = SystemRandomNumberGenerator()
        return move(in: game, for: playerID, difficulty: difficulty, using: &generator)
    }

    /// Outweighs any heuristic score, so a seen win always beats a good position.
    private static let connect4Win = 1_000_000

    /// Centre first: most lines run through it, so good moves are tried early
    /// and alpha-beta cuts more.
    private static let searchOrder = [3, 2, 4, 1, 5, 0, 6]

    /// The value to `disc` of dropping it into `column`, searching `depth` plies
    /// counting this one. The column must have room. Undoes the drop.
    private static func scoreDrop(
        _ board: inout [Disc?],
        column: Int,
        disc: Disc,
        depth: Int,
        alpha: Int,
        beta: Int
    ) -> Int {
        let row = landingRow(board, column: column)!
        let cell = row * Connect4Game.columns + column
        board[cell] = disc
        defer { board[cell] = nil }

        // Plies left over make a sooner win worth more, and a later loss cost less.
        if connectsFour(board, row: row, column: column, disc: disc) { return connect4Win + depth }
        if !board.contains(where: { $0 == nil }) { return 0 }
        if depth == 1 {
            // The search ends here, but a win on the very next drop is not a
            // position to weigh: without this, the last side to move is
            // assumed never to block, and even depths learn to set up threats
            // that are simply answered.
            if canWinNow(&board, disc: disc.opponent) { return -connect4Win }
            return evaluate(board, for: disc)
        }
        return -negamax(&board, toMove: disc.opponent, depth: depth - 1, alpha: -beta, beta: -alpha)
    }

    /// Whether `disc` has a drop that wins on the spot.
    private static func canWinNow(_ board: inout [Disc?], disc: Disc) -> Bool {
        for column in 0..<Connect4Game.columns {
            guard let row = landingRow(board, column: column) else { continue }
            let cell = row * Connect4Game.columns + column
            board[cell] = disc
            defer { board[cell] = nil }
            if connectsFour(board, row: row, column: column, disc: disc) { return true }
        }
        return false
    }

    /// The value of `board` to the side about to drop `disc`. Only called with
    /// at least one open column.
    private static func negamax(_ board: inout [Disc?], toMove disc: Disc, depth: Int, alpha: Int, beta: Int) -> Int {
        var alpha = alpha
        var best = -Int.max
        for column in searchOrder where landingRow(board, column: column) != nil {
            let score = scoreDrop(&board, column: column, disc: disc, depth: depth, alpha: alpha, beta: beta)
            best = max(best, score)
            alpha = max(alpha, score)
            if alpha >= beta { break }
        }
        return best
    }

    private static func landingRow(_ board: [Disc?], column: Int) -> Int? {
        (0..<Connect4Game.rows).reversed().first { board[$0 * Connect4Game.columns + column] == nil }
    }

    /// Whether the disc just dropped at `row`, `column` completes a line — the
    /// same walk `Connect4Game` does, on a bare board.
    private static func connectsFour(_ board: [Disc?], row: Int, column: Int, disc: Disc) -> Bool {
        for (rowStep, columnStep) in [(0, 1), (1, 0), (1, 1), (-1, 1)] {
            var run = 1
            for sign in [1, -1] {
                var currentRow = row + rowStep * sign
                var currentColumn = column + columnStep * sign
                while (0..<Connect4Game.rows).contains(currentRow),
                    (0..<Connect4Game.columns).contains(currentColumn),
                    board[currentRow * Connect4Game.columns + currentColumn] == disc
                {
                    run += 1
                    currentRow += rowStep * sign
                    currentColumn += columnStep * sign
                }
            }
            if run >= Connect4Game.connectLength { return true }
        }
        return false
    }

    /// Every run of four cells on the board — 69 of them.
    private static let windows: [[Int]] = {
        let rows = Connect4Game.rows
        let columns = Connect4Game.columns
        var windows: [[Int]] = []
        for row in 0..<rows {
            for column in 0..<columns {
                for (rowStep, columnStep) in [(0, 1), (1, 0), (1, 1), (-1, 1)] {
                    let cells = (0..<Connect4Game.connectLength).map {
                        (row + rowStep * $0, column + columnStep * $0)
                    }
                    guard cells.allSatisfy({ (0..<rows).contains($0.0) && (0..<columns).contains($0.1) }) else {
                        continue
                    }
                    windows.append(cells.map { $0.0 * columns + $0.1 })
                }
            }
        }
        return windows
    }()

    /// What a run of four is worth by how many of its cells one side holds,
    /// provided the other side holds none.
    private static let windowWeights = [0, 1, 4, 16]

    /// A heuristic value to `disc` of a position the search stops at: every
    /// run of four only one side can still complete, plus the centre column.
    private static func evaluate(_ board: [Disc?], for disc: Disc) -> Int {
        var score = 0
        for window in windows {
            var mine = 0
            var theirs = 0
            for cell in window {
                if board[cell] == disc {
                    mine += 1
                } else if board[cell] != nil {
                    theirs += 1
                }
            }
            // A completed four ends the search before it gets here, so neither
            // count reaches 4.
            if theirs == 0 { score += windowWeights[mine] }
            if mine == 0 { score -= windowWeights[theirs] }
        }
        for row in 0..<Connect4Game.rows {
            if let held = board[row * Connect4Game.columns + 3] {
                score += held == disc ? 3 : -3
            }
        }
        return score
    }
}

extension Mark {
    var opponent: Mark { self == .x ? .o : .x }
}

extension Disc {
    var opponent: Disc { self == .red ? .yellow : .red }
}
