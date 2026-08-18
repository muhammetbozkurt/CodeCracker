import Foundation

/// A player's stable identity. Distinct from the transport-level socket id the
/// Python server tracked — that has no meaning on-device.
public struct PlayerID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }
}

/// A seat at the table. `Role` carries whatever the specific game needs to know
/// about a player: their mark in tic-tac-toe, their disc colour in Connect 4,
/// their secret in CodeCracker.
public struct Player<Role: Sendable & Equatable>: Identifiable, Sendable {
    public let id: PlayerID
    public var name: String
    public var score: Int
    public var role: Role

    public init(id: PlayerID = PlayerID(), name: String, score: Int = 0, role: Role) {
        self.id = id
        self.name = name
        self.score = score
        self.role = role
    }
}

extension Player: Equatable {
    /// Identity comparison only, matching the Python `Player.__eq__`.
    public static func == (lhs: Player<Role>, rhs: Player<Role>) -> Bool {
        lhs.id == rhs.id
    }
}
