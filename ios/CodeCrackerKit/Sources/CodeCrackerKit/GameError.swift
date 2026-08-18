import Foundation

/// Every way a move or setup step can be rejected.
///
/// The `errorDescription` strings match the messages the Python server sent to
/// the web client, so existing UI copy carries over unchanged.
public enum GameError: Error, Equatable, Sendable {
    case gameIsFull
    case gameIsAlreadyOver
    case gameIsNotReady
    case notYourTurn
    case unknownPlayer
    case invalidCode
    case secretAlreadySet
    case cellOccupied
    case moveOutOfBounds
    case columnIsFull
}

extension GameError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .gameIsFull:
            "Game is full"
        case .gameIsAlreadyOver:
            "Game is already over"
        case .gameIsNotReady:
            "Game is not ready to play"
        case .notYourTurn:
            "Not your turn"
        case .unknownPlayer:
            "Player not found in game"
        case .invalidCode:
            "Guess must be a 4 digit number and every digit must be different"
        case .secretAlreadySet:
            "Secret can only be set once"
        case .cellOccupied:
            "Invalid move. Cell may be occupied or out of bounds."
        case .moveOutOfBounds:
            "Move is out of bounds"
        case .columnIsFull:
            "Invalid move. Column may be full or out of bounds."
        }
    }
}
