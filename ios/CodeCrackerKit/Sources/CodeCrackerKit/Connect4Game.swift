import Foundation

public enum Disc: String, Sendable, Codable, CaseIterable {
    case red = "Red"
    case yellow = "Yellow"
}

public struct Connect4Turn: Equatable, Sendable {
    public let playerID: PlayerID
    public let playerName: String
    public let column: Int
    public let row: Int
    public let disc: Disc
}

public struct Connect4Game: TurnBasedGame {
    public typealias Move = Int
    public typealias Role = Disc

    public static let rows = 6
    public static let columns = 7
    public static let connectLength = 4

    public let id: String
    public var players: [Player<Disc>] = []
    public var timeline: GameTimeline
    /// Row-major, `rows * columns` entries. Row 0 is the top of the board.
    public private(set) var board: [Disc?] = Array(
        repeating: nil, count: Connect4Game.rows * Connect4Game.columns
    )
    public private(set) var turnHistory: [Connect4Turn] = []
    public private(set) var result: MoveOutcome = .ongoing
    /// The four cells that won, for highlighting in the UI.
    public private(set) var winningCells: [Int]?

    public init(id: String = GameID.generate(), createdAt: Date = Date()) {
        self.id = id
        self.timeline = GameTimeline(createdAt: createdAt)
    }

    public var isReadyToPlay: Bool { isFull }

    public var currentPlayerID: PlayerID? { seatToPlay(afterMoves: turnHistory.count) }

    public func index(row: Int, column: Int) -> Int {
        row * Self.columns + column
    }

    public func disc(row: Int, column: Int) -> Disc? {
        board[index(row: row, column: column)]
    }

    /// The row a disc dropped into `column` would land in, or `nil` if full.
    public func landingRow(inColumn column: Int) -> Int? {
        guard (0..<Self.columns).contains(column) else { return nil }
        return (0..<Self.rows).reversed().first { board[index(row: $0, column: column)] == nil }
    }

    public func canPlay(_ column: Int) -> Bool {
        landingRow(inColumn: column) != nil
    }

    public var availableColumns: [Int] {
        (0..<Self.columns).filter(canPlay)
    }

    public mutating func applyMove(_ move: Int, by playerID: PlayerID) throws -> MoveOutcome {
        guard let player = player(id: playerID) else { throw GameError.unknownPlayer }
        guard let row = landingRow(inColumn: move) else { throw GameError.columnIsFull }

        let landed = index(row: row, column: move)
        board[landed] = player.role
        turnHistory.append(
            Connect4Turn(
                playerID: playerID,
                playerName: player.name,
                column: move,
                row: row,
                disc: player.role
            )
        )

        if let cells = connectedCells(through: row, column: move, disc: player.role) {
            winningCells = cells
            result = .win(playerID)
        } else if !board.contains(where: { $0 == nil }) {
            result = .draw
        }

        return result
    }

    /// Looks for a run of four through the cell just played — the only cell that
    /// can have created one.
    private func connectedCells(through row: Int, column: Int, disc: Disc) -> [Int]? {
        let directions = [(0, 1), (1, 0), (1, 1), (-1, 1)]  // →, ↓, ↘, ↗

        for (rowStep, columnStep) in directions {
            var run = [index(row: row, column: column)]

            for sign in [1, -1] {
                var currentRow = row + rowStep * sign
                var currentColumn = column + columnStep * sign

                while (0..<Self.rows).contains(currentRow),
                    (0..<Self.columns).contains(currentColumn),
                    board[index(row: currentRow, column: currentColumn)] == disc
                {
                    run.append(index(row: currentRow, column: currentColumn))
                    currentRow += rowStep * sign
                    currentColumn += columnStep * sign
                }
            }

            if run.count >= Self.connectLength { return run.sorted() }
        }

        return nil
    }
}
