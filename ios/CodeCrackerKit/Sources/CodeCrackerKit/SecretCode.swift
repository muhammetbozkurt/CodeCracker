import Foundation

/// A four-digit code with no repeated digits — used both as a hidden secret and
/// as a guess against one.
///
/// The type cannot be constructed in an invalid state, so the "is this a legal
/// guess?" check happens once at the edge (parsing user input) rather than on
/// every move.
public struct SecretCode: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    public static let length = 4

    public let digits: [Int]

    /// Returns `nil` unless `text` is a 1000–9999 integer whose digits are all
    /// distinct. A leading zero therefore fails, matching the Python range check.
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (1000...9999).contains(value) else { return nil }

        let digits = String(value).compactMap(\.wholeNumberValue)
        guard digits.count == Self.length, Set(digits).count == Self.length else { return nil }

        self.digits = digits
    }

    /// Throwing counterpart to `init?`, for call sites that want to surface
    /// `GameError.invalidCode` directly.
    public init(validating text: String) throws {
        guard let code = SecretCode(text) else { throw GameError.invalidCode }
        self = code
    }

    public var description: String { digits.map(String.init).joined() }

    /// Scores this code as a guess against `secret`.
    public func feedback(against secret: SecretCode) -> Feedback {
        var correctPositions = 0
        var correctDigits = 0

        for index in 0..<Self.length {
            if digits[index] == secret.digits[index] {
                correctPositions += 1
            } else if secret.digits.contains(digits[index]) {
                correctDigits += 1
            }
        }

        return Feedback(correctPositions: correctPositions, correctDigits: correctDigits)
    }
}

/// How close a guess came: digits in the right place, and digits present but
/// misplaced.
public struct Feedback: Equatable, Hashable, Sendable, Codable {
    public let correctPositions: Int
    public let correctDigits: Int

    public init(correctPositions: Int, correctDigits: Int) {
        self.correctPositions = correctPositions
        self.correctDigits = correctDigits
    }

    public var isExact: Bool { correctPositions == SecretCode.length }
}
