import Foundation

public enum Mark: String, Sendable, Codable, CaseIterable {
    case x = "X"
    case o = "O"
}

public struct TicTacToeTurn: Equatable, Sendable {
    public let playerID: PlayerID
    public let playerName: String
    public let cell: Int
    public let mark: Mark
}

public struct TicTacToeGame: TurnBasedGame {
    public typealias Move = Int
    public typealias Role = Mark

    public static let cellCount = 9

    /// The eight three-in-a-row lines.
    public static let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],  // rows
        [0, 3, 6], [1, 4, 7], [2, 5, 8],  // columns
        [0, 4, 8], [2, 4, 6],             // diagonals
    ]

    public let id: String
    public var players: [Player<Mark>] = []
    public var timeline: GameTimeline
    public private(set) var board: [Mark?] = Array(repeating: nil, count: TicTacToeGame.cellCount)
    public private(set) var turnHistory: [TicTacToeTurn] = []
    public private(set) var result: MoveOutcome = .ongoing
    /// The three cells that won, for highlighting in the UI.
    public private(set) var winningLine: [Int]?

    public init(id: String = GameID.generate(), createdAt: Date = Date()) {
        self.id = id
        self.timeline = GameTimeline(createdAt: createdAt)
    }

    public var isReadyToPlay: Bool { isFull }

    public var currentPlayerID: PlayerID? { seatToPlay(afterMoves: turnHistory.count) }

    public func mark(row: Int, column: Int) -> Mark? {
        board[row * 3 + column]
    }

    public func canPlay(_ cell: Int) -> Bool {
        board.indices.contains(cell) && board[cell] == nil
    }

    public var availableCells: [Int] {
        board.indices.filter { board[$0] == nil }
    }

    public mutating func applyMove(_ move: Int, by playerID: PlayerID) throws -> MoveOutcome {
        guard let player = player(id: playerID) else { throw GameError.unknownPlayer }
        guard canPlay(move) else { throw GameError.cellOccupied }

        board[move] = player.role
        turnHistory.append(
            TicTacToeTurn(playerID: playerID, playerName: player.name, cell: move, mark: player.role)
        )

        if let line = Self.lines.first(where: { line in
            guard let first = board[line[0]] else { return false }
            return line.allSatisfy { board[$0] == first }
        }) {
            winningLine = line
            result = .win(playerID)
        } else if !board.contains(where: { $0 == nil }) {
            result = .draw
        }

        return result
    }
}
