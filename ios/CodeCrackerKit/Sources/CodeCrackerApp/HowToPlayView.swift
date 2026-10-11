import SwiftUI

/// The rules of one game, as a sheet over its screen. Opened from the "?" in
/// `GameShell`, and once on its own the first time CodeCracker is played.
struct HowToPlayView: View {
    let kind: GameKind

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground(tint: kind.accent, secondary: kind.secondaryAccent)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        rules
                        if kind == .codeCracker {
                            example
                            Rule(icon: "lock.shield.fill", accent: kind.accent) {
                                Text("On two devices, your code never leaves your phone. It is checked when the game ends, so nobody can change theirs halfway through.")
                            }
                            .glassCard(tint: kind.accent)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: 14) {
            GameThumbnail(kind: kind)
                .frame(width: 54, height: 54)
            Text(kind.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var rules: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch kind {
            case .ticTacToe:
                Rule(icon: "arrow.left.arrow.right", accent: kind.accent) {
                    Text("Take turns placing your mark on the 3×3 board. X always goes first.")
                }
                Rule(icon: "trophy.fill", accent: kind.accent) {
                    Text("Get three in a row — across, down or corner to corner — to win.")
                }
                Rule(icon: "equal.circle.fill", accent: kind.accent) {
                    Text("If all nine squares fill up with no line, it's a draw.")
                }
            case .connect4:
                Rule(icon: "arrow.down.circle.fill", accent: kind.accent) {
                    Text("Take turns dropping a disc into one of the seven columns. It falls to the lowest free space. Red goes first.")
                }
                Rule(icon: "trophy.fill", accent: kind.accent) {
                    Text("Line up four of your discs — across, down or diagonally — to win.")
                }
                Rule(icon: "equal.circle.fill", accent: kind.accent) {
                    Text("If all 42 spaces fill up with no line of four, it's a draw.")
                }
            case .codeCracker:
                Rule(icon: "lock.fill", accent: kind.accent) {
                    Text("Each player picks a secret code: four digits, all different, no leading zero.")
                }
                Rule(icon: "arrow.left.arrow.right", accent: kind.accent) {
                    Text("Take turns guessing your opponent's code. Every guess is answered with two counts:")
                }
                legend
                Rule(icon: "trophy.fill", accent: kind.accent) {
                    Text("The counts never say which digits matched — working that out is the game. Crack the other code first to win.")
                }
            }
        }
        .glassCard(tint: kind.accent)
    }

    /// The two counts, with the same pegs the history card uses.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle().fill(Color.codeMint).frame(width: 9, height: 9)
                Text("Right digit, right place")
            }
            HStack(spacing: 10) {
                Circle().strokeBorder(Color.discYellow, lineWidth: 2).frame(width: 9, height: 9)
                Text("Right digit, wrong place")
            }
        }
        .font(.system(.subheadline, design: .rounded))
        .foregroundStyle(Color.textSecondary)
        .padding(.leading, 38)
    }

    // MARK: Worked example

    /// Codes for the example. Literals the type accepts, so the unwraps hold.
    private static let exampleSecret = SecretCode("4729")!
    private static let exampleGuesses = ["1234", "4752", "4729"].compactMap(SecretCode.init)

    /// Three guesses against one secret, scored by the kit itself rather than
    /// written out by hand, so the example can never disagree with the game.
    private var example: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: String(localized: "Example"))
            Text("The secret code is \(Self.exampleSecret.description).")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.textSecondary)

            VStack(spacing: 8) {
                ForEach(Self.exampleGuesses, id: \.self) { guess in
                    let feedback = guess.feedback(against: Self.exampleSecret)
                    HStack(spacing: 12) {
                        Text(guess.description)
                            .font(.system(size: 19, weight: .bold, design: .monospaced))
                            .foregroundStyle(feedback.isExact ? Color.codeMint : .white)
                            .tracking(3)
                        Spacer(minLength: 0)
                        FeedbackPegs(feedback: feedback)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        Color.white.opacity(feedback.isExact ? 0.10 : 0.04),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
            }
        }
        .glassCard(tint: kind.accent)
    }
}

/// One rule: an icon in the game's colour beside a short paragraph.
private struct Rule<Content: View>: View {
    let icon: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24)
            content
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
