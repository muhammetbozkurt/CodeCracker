import Foundation
import Observation

/// How a finished game turned out, from this device's point of view.
///
/// Pass-and-play has no "you" — both seats are on this device — so those games
/// land as `.decided` or `.drawn`, and the win/loss columns stay at zero.
enum GameOutcome: Sendable {
    case won
    case lost
    case drawn
    /// Somebody won, but nobody on this device owns the result.
    case decided
}

/// Counters for one game, in one mode, at one difficulty.
struct GameRecord: Codable, Equatable, Sendable {
    var played = 0
    var won = 0
    var lost = 0
    var drawn = 0
    var currentStreak = 0
    var bestStreak = 0

    /// A draw breaks a win streak: "streak" reads as consecutive wins, not
    /// consecutive games survived.
    mutating func add(_ outcome: GameOutcome) {
        played += 1
        switch outcome {
        case .won:
            won += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        case .lost:
            lost += 1
            currentStreak = 0
        case .drawn:
            drawn += 1
            currentStreak = 0
        case .decided:
            break
        }
    }
}

/// Every finished game, counted.
///
/// Records live in `UserDefaults` as one JSON blob: the whole store is a few
/// dozen integers with nothing to query, so a schema and a container would cost
/// more than they buy. A decode failure resets to empty, which is the right
/// answer for a stats file — never a reason to refuse to launch.
@MainActor
@Observable
final class StatsStore {
    /// The instance the app injects. Tests and previews build their own against
    /// a scratch `UserDefaults`.
    static let shared = StatsStore()

    /// Keyed by `statKey(kind:mode:difficulty:)`.
    private(set) var records: [String: GameRecord] = [:]

    private let defaults: UserDefaults
    private static let storageKey = "gameStats.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode([String: GameRecord].self, from: data)
        else { return }
        records = decoded
    }

    // MARK: Keys

    /// Difficulty is part of the key for solo games — beating `easy` and
    /// beating `hard` are not the same achievement — and absent elsewhere.
    static func statKey(kind: GameKind, mode: PlayMode, difficulty: Difficulty?) -> String {
        [kind.rawValue, mode.rawValue, difficulty?.rawValue]
            .compactMap { $0 }
            .joined(separator: "|")
    }

    // MARK: Reading

    func record(kind: GameKind, mode: PlayMode, difficulty: Difficulty? = nil) -> GameRecord {
        records[Self.statKey(kind: kind, mode: mode, difficulty: difficulty)] ?? GameRecord()
    }

    /// Every record for one game, summed across modes and difficulties. Streaks
    /// are taken as the best of the parts rather than added, since a streak
    /// spanning two modes is not a streak anybody played.
    func total(kind: GameKind) -> GameRecord {
        records
            .filter { $0.key.hasPrefix("\(kind.rawValue)|") }
            .values
            .reduce(into: GameRecord()) { total, part in
                total.played += part.played
                total.won += part.won
                total.lost += part.lost
                total.drawn += part.drawn
                total.bestStreak = max(total.bestStreak, part.bestStreak)
            }
    }

    var hasAnyRecord: Bool { records.values.contains { $0.played > 0 } }

    // MARK: Writing

    func record(
        _ outcome: GameOutcome,
        kind: GameKind,
        mode: PlayMode,
        difficulty: Difficulty? = nil
    ) {
        let key = Self.statKey(kind: kind, mode: mode, difficulty: difficulty)
        var record = records[key] ?? GameRecord()
        record.add(outcome)
        records[key] = record
        save()
    }

    func reset() {
        records = [:]
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
