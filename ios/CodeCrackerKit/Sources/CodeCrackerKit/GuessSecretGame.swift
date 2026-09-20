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
    /// Seats whose code was chosen on another device, keyed to an opaque
    /// commitment to it.
    ///
    /// Pass-and-play never uses this. Nearby multiplayer does: copying a secret
    /// to the guesser's device hands them the game, so the code stays with its
    /// owner, who scores guesses against it, and this side holds only a
    /// commitment it can check against the reveal at the end. How that
    /// commitment is computed is the caller's business — the rules only store
    /// it and compare it.
    public private(set) var commitments: [PlayerID: Data] = [:]

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
        isFull && players.allSatisfy { $0.role != nil || commitments[$0.id] != nil }
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
        guard players[index].role == nil, commitments[playerID] == nil else {
            throw GameError.secretAlreadySet
        }
        players[index].role = secret
    }

    /// Records that a player has chosen a code held on another device, without
    /// learning what it is. Like `setSecret`, once only.
    public mutating func commitSecret(_ digest: Data, for playerID: PlayerID) throws {
        guard players.contains(where: { $0.id == playerID }) else { throw GameError.unknownPlayer }
        guard player(id: playerID)?.role == nil, commitments[playerID] == nil else {
            throw GameError.secretAlreadySet
        }
        commitments[playerID] = digest
    }

    /// Whether this seat's code is settled — chosen here, or committed to elsewhere.
    public func hasSettledSecret(_ playerID: PlayerID) -> Bool {
        hasChosenSecret(playerID) || commitments[playerID] != nil
    }

    /// Every guess made by one player, oldest first — the history that player sees.
    public func history(for playerID: PlayerID) -> [GuessTurn] {
        turnHistory.filter { $0.playerID == playerID }
    }

    /// Records a guess that was scored on the other player's device.
    ///
    /// When the code never leaves its owner, the guesser cannot score their own
    /// guess: the owner returns a `Feedback` and this writes the turn. The
    /// guards are the same ones `play(_:by:)` applies — repeated here because
    /// the outcome arrives with the move instead of being derived from it.
    @discardableResult
    public mutating func record(
        _ guess: SecretCode,
        scoredAs feedback: Feedback,
        by playerID: PlayerID
    ) throws -> MoveOutcome {
        guard !isOver else { throw GameError.gameIsAlreadyOver }
        guard isReadyToPlay else { throw GameError.gameIsNotReady }
        guard let player = player(id: playerID) else { throw GameError.unknownPlayer }
        guard currentPlayerID == playerID else { throw GameError.notYourTurn }

        turnHistory.append(
            GuessTurn(playerID: playerID, playerName: player.name, guess: guess, feedback: feedback)
        )

        if feedback.isExact {
            result = .win(playerID)
        }

        timeline.recordMove()
        return result
    }

    /// Re-scores every guess this player made against a code revealed at the
    /// end. `false` means the feedback they were given never described that
    /// code — the owner changed their answer as the game went along.
    public func feedbackIsConsistent(with secret: SecretCode, guessedBy playerID: PlayerID) -> Bool {
        history(for: playerID).allSatisfy { $0.feedback == $0.guess.feedback(against: secret) }
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
