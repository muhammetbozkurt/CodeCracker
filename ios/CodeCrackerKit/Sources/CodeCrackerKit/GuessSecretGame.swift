import Foundation

public struct GuessTurn: Equatable, Sendable {
    public let playerID: PlayerID
    public let playerName: String
    public let guess: SecretCode
    public let feedback: Feedback

    public var isWinning: Bool { feedback.isExact }
}

/// CodeCracker: each player hides a four-digit code, then they take turns
/// guessing each other's.
public struct GuessSecretGame: TurnBasedGame {
    public typealias Move = SecretCode
    /// A player's own hidden code, `nil` until they choose one.
    public typealias Role = SecretCode?

    public let id: String
    public var players: [Player<SecretCode?>] = []
    public var timeline: GameTimeline
    public private(set) var turnHistory: [GuessTurn] = []
    public private(set) var result: MoveOutcome = .ongoing

    public init(id: String = GameID.generate(), createdAt: Date = Date()) {
        self.id = id
        self.timeline = GameTimeline(createdAt: createdAt)
    }

    /// Convenience for adding a player who has not chosen a secret yet.
    @discardableResult
    public mutating func addPlayer(named name: String, id: PlayerID = PlayerID()) throws -> PlayerID {
        try addPlayer(Player(id: id, name: name, role: nil))
        return id
    }

    public var isReadyToPlay: Bool {
        isFull && players.allSatisfy { $0.role != nil }
    }

    public var currentPlayerID: PlayerID? { seatToPlay(afterMoves: turnHistory.count) }

    public func hasChosenSecret(_ playerID: PlayerID) -> Bool {
        player(id: playerID)?.role != nil
    }

    /// Chooses a player's hidden code. Can only be done once per player.
    public mutating func setSecret(_ secret: SecretCode, for playerID: PlayerID) throws {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else {
            throw GameError.unknownPlayer
        }
        guard players[index].role == nil else { throw GameError.secretAlreadySet }
        players[index].role = secret
    }

    /// Every guess made by one player, oldest first — the history that player sees.
    public func history(for playerID: PlayerID) -> [GuessTurn] {
        turnHistory.filter { $0.playerID == playerID }
    }

    public mutating func applyMove(_ move: SecretCode, by playerID: PlayerID) throws -> MoveOutcome {
        guard let player = player(id: playerID) else { throw GameError.unknownPlayer }
        guard let target = opponent(of: playerID)?.role else { throw GameError.gameIsNotReady }

        let feedback = move.feedback(against: target)
        turnHistory.append(
            GuessTurn(
                playerID: playerID,
                playerName: player.name,
                guess: move,
                feedback: feedback
            )
        )

        if feedback.isExact {
            result = .win(playerID)
        }

        return result
    }
}
