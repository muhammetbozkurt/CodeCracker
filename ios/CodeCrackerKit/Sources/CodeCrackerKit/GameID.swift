import Foundation

/// Short, human-shareable game codes — the port of `utils.generate_custom_id`.
public enum GameID {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    public static func generate(suffixLength: Int = 6, now: Date = Date()) -> String {
        let timestamp = Int(now.timeIntervalSince1970)
        let suffix = String((0..<suffixLength).map { _ in alphabet.randomElement()! })
        return "\(timestamp)-\(suffix)"
    }
}
