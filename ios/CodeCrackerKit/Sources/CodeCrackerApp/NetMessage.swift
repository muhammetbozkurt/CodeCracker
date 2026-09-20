import CryptoKit
import Foundation

// The wire protocol for nearby multiplayer.
//
// Nothing here knows how to play. Both devices hold their own copy of the game
// struct and replay the same moves: turn order is derived from
// `turnHistory.count` (see `TurnBasedGame.seatToPlay`) and `applyMove` is
// deterministic, so the two copies cannot drift as long as every move arrives
// exactly once and in order — which the `seq` on `.move` checks.

/// A seat the host has assigned. Seat 0 opens.
struct NetSeat: Codable, Sendable, Equatable {
    let playerID: PlayerID
    let name: String
}

/// A move, narrowed to the three shapes the games accept.
enum NetMove: Codable, Sendable, Equatable {
    case cell(Int)          // Tic-Tac-Toe, 0..<9
    case column(Int)        // Connect 4, 0..<7
    case guess(SecretCode)  // CodeCracker
}

enum NetMessage: Codable, Sendable, Equatable {
    /// Guest → host, on connect.
    case hello(name: String)
    /// Host → guest. The host owns seat assignment, so both sides agree on
    /// player IDs and on who opens.
    case start(kind: GameKind, gameID: String, seats: [NetSeat])
    /// CodeCracker setup. A code never leaves the device that chose it — only
    /// this commitment to it does, which `.reveal` is checked against.
    case commit(playerID: PlayerID, digest: Data)
    /// `seq` is the sender's `turnHistory.count` *before* the move. A receiver
    /// whose count disagrees reports a desync instead of applying it.
    case move(playerID: PlayerID, seq: Int, move: NetMove)
    /// CodeCracker only: the owner of the guessed code returns the score, since
    /// the guesser has no way to work it out. `playerID` is the guesser's.
    case feedback(playerID: PlayerID, seq: Int, guess: SecretCode, feedback: Feedback)
    /// Sent by both sides once the game is over, opening the commitment so the
    /// other player can check the answers they were given all game.
    case reveal(playerID: PlayerID, code: SecretCode, salt: Data)
    /// Guest → host request; the host answers with a fresh `.start`.
    case rematch
    case quit
}

extension NetMessage {
    func encoded() throws -> Data { try JSONEncoder().encode(self) }

    static func decoded(from data: Data) throws -> NetMessage {
        try JSONDecoder().decode(NetMessage.self, from: data)
    }
}

/// `GameKind` is a `String` enum in `Components.swift`, so this is the whole
/// conformance.
extension GameKind: Codable {}

/// Binds a player to their code without disclosing it.
///
/// A bare hash of four digits is brute-forced in microseconds, so the salt is
/// what actually hides the code until the reveal; the hash is what stops the
/// owner quietly swapping codes when a guess gets close.
enum SecretCommitment {
    static func makeSalt() -> Data {
        Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
    }

    static func digest(_ code: SecretCode, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(code.description.utf8)))
    }
}
