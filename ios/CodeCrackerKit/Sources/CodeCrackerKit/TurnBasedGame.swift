import Foundation

/// The outcome of a single move.
///
/// Replaces the Python `_play` return value, which could be a `Player`, the
/// string `"draw"`, or `None` — three unrelated types down one channel.
public enum MoveOutcome: Equatable, Sendable {
    case ongoing
    case win(PlayerID)
    case draw
}

/// Coarse game state, for driving UI.
public enum GameStatus: Equatable, Sendable, CustomStringConvertible {
    case waitingForPlayers
    case waitingForSetup
    case inProgress
    case over

    public var description: String {
        switch self {
        case .waitingForPlayers: "Waiting for players"
        case .waitingForSetup: "Waiting for setup"
        case .inProgress: "Game is on"
        case .over: "Game over"
        }
    }
}

/// When things happened. The Python server used `lastPlayedAt` to reap
/// abandoned games; on-device it is informational only.
public struct GameTimeline: Equatable, Sendable {
    public let createdAt: Date
    public private(set) var startedAt: Date?
    public private(set) var lastPlayedAt: Date

    public init(createdAt: Date = Date()) {
        self.createdAt = createdAt
        self.startedAt = nil
        self.lastPlayedAt = createdAt
    }

    mutating func recordMove(at date: Date = Date()) {
        if startedAt == nil { startedAt = date }
        lastPlayedAt = date
    }
}

/// A two-player, alternating-turn game.
///
/// Conformers are value types: copying a game snapshots it, which makes undo,
/// replay, and SwiftUI diffing fall out for free.
public protocol TurnBasedGame: Sendable {
    /// What a single move looks like — a cell index, a column, a code.
    associatedtype Move: Sendable
    /// Per-player game-specific data. See `Player.role`.
    associatedtype Role: Sendable & Equatable

    var id: String { get }
    var players: [Player<Role>] { get set }
    var timeline: GameTimeline { get set }

    /// `.ongoing` until somebody wins or the board fills.
    var result: MoveOutcome { get }

    /// Whose move it is, or `nil` when the game cannot accept a move.
    var currentPlayerID: PlayerID? { get }

    /// Whether setup is complete — both seats filled, and for CodeCracker both
    /// secrets chosen.
    var isReadyToPlay: Bool { get }

    var status: GameStatus { get }

    /// Game-specific move handling. Call `play(_:by:)` instead; this is the hook
    /// each game implements.
    mutating func applyMove(_ move: Move, by playerID: PlayerID) throws -> MoveOutcome
}

// MARK: - Roster

extension TurnBasedGame {
    public static var seatCount: Int { 2 }

    public var isFull: Bool { players.count == Self.seatCount }

    public var player1: Player<Role>? { players.first }

    public var player2: Player<Role>? { players.count > 1 ? players[1] : nil }

    public func player(id: PlayerID) -> Player<Role>? {
        players.first { $0.id == id }
    }

    public func opponent(of playerID: PlayerID) -> Player<Role>? {
        guard isFull else { return nil }
        return players.first { $0.id != playerID }
    }

    public mutating func addPlayer(_ player: Player<Role>) throws {
        guard !isFull else { throw GameError.gameIsFull }
        players.append(player)
    }

    public mutating func removePlayer(id: PlayerID) {
        players.removeAll { $0.id == id }
    }
}

// MARK: - Turn order and play

extension TurnBasedGame {
    public var isOver: Bool { result != .ongoing }

    /// The winning player, if the game ended in a win rather than a draw.
    public var winner: Player<Role>? {
        guard case .win(let id) = result else { return nil }
        return player(id: id)
    }

    public var isDraw: Bool { result == .draw }

    public var status: GameStatus {
        if isOver { return .over }
        if !isFull { return .waitingForPlayers }
        if !isReadyToPlay { return .waitingForSetup }
        return .inProgress
    }

    /// Turn order is derived from how many moves have been played rather than
    /// stored, so it cannot drift out of sync with the board. Seat 0 opens.
    func seatToPlay(afterMoves moveCount: Int) -> PlayerID? {
        guard isReadyToPlay, !isOver else { return nil }
        return players[moveCount % Self.seatCount].id
    }

    /// Validates and applies a move, advancing the turn.
    @discardableResult
    public mutating func play(_ move: Move, by playerID: PlayerID) throws -> MoveOutcome {
        guard !isOver else { throw GameError.gameIsAlreadyOver }
        guard isReadyToPlay else { throw GameError.gameIsNotReady }
        guard player(id: playerID) != nil else { throw GameError.unknownPlayer }
        guard currentPlayerID == playerID else { throw GameError.notYourTurn }

        let outcome = try applyMove(move, by: playerID)
        timeline.recordMove()
        return outcome
    }
}
