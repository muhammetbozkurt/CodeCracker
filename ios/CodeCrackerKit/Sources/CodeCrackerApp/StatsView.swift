import SwiftUI

/// Everything this device has counted, grouped the way the home screen is:
/// one card per game, broken down by how it was played.
struct StatsView: View {
    @Environment(StatsStore.self) private var stats
    @State private var confirmingReset = false

    var body: some View {
        ZStack {
            AuroraBackground(tint: .codeAccent, secondary: .markX)

            if stats.hasAnyRecord {
                cards
            } else {
                emptyState
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if stats.hasAnyRecord {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { confirmingReset = true }
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .tint(.discRed)
                }
            }
        }
        .confirmationDialog(
            "Reset all stats?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { stats.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every game counted so far is forgotten. This cannot be undone.")
        }
    }

    // MARK: Cards

    private var cards: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(GameKind.allCases) { kind in
                    card(for: kind)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            // A phone-width column on iPad, matching the home screen.
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func card(for kind: GameKind) -> some View {
        let total = stats.total(kind: kind)
        let rows = rows(for: kind)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                GameThumbnail(kind: kind)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(summary(total))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer(minLength: 8)

                if total.bestStreak > 1 {
                    streak(total.bestStreak, accent: kind.accent)
                }
            }

            if rows.isEmpty {
                Text("Not played yet.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        breakdown(row, accent: kind.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: kind.accent)
    }

    /// Deliberately not a percentage. Pass-and-play games are counted but have
    /// no winner, so a "% won" beside the total would be a share of a smaller
    /// set than the number next to it — and off one or two games it says
    /// nothing anyway.
    private func summary(_ record: GameRecord) -> String {
        guard record.played > 0 else { return "No games yet" }
        let games = record.played == 1 ? "1 game" : "\(record.played) games"
        guard record.won + record.lost > 0 else { return games }
        return "\(games) · \(record.won)W \(record.lost)L"
    }

    /// A best run worth mentioning. One win is not a streak, so the badge only
    /// appears from two up.
    private func streak(_ count: Int, accent: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text("\(count)")
        }
        .font(.system(.footnote, design: .rounded, weight: .bold))
        .foregroundStyle(accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(accent.opacity(0.16)))
        .overlay(Capsule().stroke(accent.opacity(0.4), lineWidth: 1))
    }

    // MARK: Breakdown rows

    /// One line of a card: a way of playing, and what it came to.
    private struct Row: Identifiable {
        let label: String
        let record: GameRecord
        /// Pass-and-play has no "you" to win or lose, so it shows a count only.
        let showsOutcome: Bool

        var id: String { label }
    }

    /// The rows for one game, in the order the home screen offers the modes,
    /// leaving out anything never played.
    private func rows(for kind: GameKind) -> [Row] {
        PlayMode.allCases
            .flatMap { mode -> [Row] in
                guard mode == .solo else {
                    return [
                        Row(
                            label: mode.title,
                            record: stats.record(kind: kind, mode: mode),
                            showsOutcome: mode != .passAndPlay
                        )
                    ]
                }
                // Solo splits by difficulty: beating easy and beating hard are
                // not the same achievement, and the store keys them apart.
                return Difficulty.allCases.map { level in
                    Row(
                        label: "\(mode.title) · \(level.rawValue.capitalized)",
                        record: stats.record(kind: kind, mode: mode, difficulty: level),
                        showsOutcome: true
                    )
                }
            }
            .filter { $0.record.played > 0 }
    }

    private func breakdown(_ row: Row, accent: Color) -> some View {
        HStack(spacing: 10) {
            Text(row.label)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            if row.showsOutcome {
                tally("W", row.record.won, color: accent)
                tally("L", row.record.lost, color: .textSecondary)
                if row.record.drawn > 0 {
                    tally("D", row.record.drawn, color: .discYellow)
                }
            } else {
                // No winner to report, so say what the number means.
                Text("\(row.record.played) played")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func tally(_ letter: String, _ count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(letter)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(count > 0 ? color : Color.textTertiary)
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.textTertiary)

            Text("Nothing counted yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("Finish a game and it shows up here — wins, losses and your best run, for every way you play.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 36)
    }
}
