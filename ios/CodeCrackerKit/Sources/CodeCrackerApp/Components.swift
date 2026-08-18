import SwiftUI

// The visual language for the app: colours, glass surfaces, the animated
// background, and the small building blocks the game views share.
//
// The app commits to a dark, neon-on-glass look in both system appearances —
// the same aesthetic as the web client — so `CodeCrackerApp` pins
// `.preferredColorScheme(.dark)` and nothing here has to be designed twice.

// MARK: - Palette

extension Color {
    /// Base canvas, darkest at the bottom of the screen.
    static let canvasTop = Color(red: 0.07, green: 0.07, blue: 0.13)
    static let canvasBottom = Color(red: 0.03, green: 0.03, blue: 0.06)

    static let markX = Color(red: 0.30, green: 0.80, blue: 1.00)
    static let markO = Color(red: 1.00, green: 0.62, blue: 0.28)

    static let discRed = Color(red: 1.00, green: 0.30, blue: 0.38)
    static let discYellow = Color(red: 1.00, green: 0.82, blue: 0.22)

    static let codeAccent = Color(red: 0.75, green: 0.40, blue: 1.00)
    static let codeMint = Color(red: 0.30, green: 0.92, blue: 0.72)

    /// Text and hairlines, as opacities over the dark canvas.
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)
    static let hairline = Color.white.opacity(0.12)
}

// MARK: - The three games

/// Everything the UI needs to know about a game before it starts one: how to
/// title it, colour it, and draw its thumbnail.
enum GameKind: String, CaseIterable, Identifiable {
    case ticTacToe
    case connect4
    case codeCracker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ticTacToe: "Tic-Tac-Toe"
        case .connect4: "Connect 4"
        case .codeCracker: "CodeCracker"
        }
    }

    var tagline: String {
        switch self {
        case .ticTacToe: "Three in a row"
        case .connect4: "Drop discs, connect four"
        case .codeCracker: "Crack the hidden code"
        }
    }

    var accent: Color {
        switch self {
        case .ticTacToe: .markX
        case .connect4: .discRed
        case .codeCracker: .codeAccent
        }
    }

    var secondaryAccent: Color {
        switch self {
        case .ticTacToe: .markO
        case .connect4: .discYellow
        case .codeCracker: .codeMint
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [accent, secondaryAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Glass

/// Builds the system glass style. Lives outside the view builder below because a
/// `@ViewBuilder` body cannot contain plain statements.
@available(iOS 26.0, *)
private func systemGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint.opacity(0.22)) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    /// A translucent panel. Uses the system glass material where the OS has one
    /// and falls back to a blurred material with a lit edge everywhere else.
    @ViewBuilder
    func glassSurface<S: Shape>(
        _ shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(systemGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(tint?.opacity(0.16) ?? Color.white.opacity(0.05), in: shape)
                .overlay(shape.stroke(Color.hairline, lineWidth: 1))
        }
    }

    /// The standard content card: generous padding on a rounded glass panel.
    func glassCard(cornerRadius: CGFloat = 28, tint: Color? = nil) -> some View {
        self
            .padding(24)
            .glassSurface(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    /// A soft coloured halo, for pieces and active states.
    func glow(_ color: Color, radius: CGFloat = 12, opacity: Double = 0.55) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}

// MARK: - Background

/// Slowly drifting colour blobs over a dark canvas. Two blobs take the tint of
/// whatever screen is showing, so each game feels like its own place.
struct AuroraBackground: View {
    var tint: Color = .codeAccent
    var secondary: Color = .markX

    @State private var drift = false

    var body: some View {
        // The blobs are fixed-size circles, so they live in an overlay: an
        // overlay can never widen its parent, and the gradient stays flexible.
        // As a ZStack sibling they would report a 460pt intrinsic width and
        // push every view stacked alongside this one off the screen edges.
        LinearGradient(
            colors: [.canvasTop, .canvasBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            ZStack {
                blob(tint, size: 460)
                    .offset(x: drift ? -120 : -70, y: drift ? -260 : -190)
                blob(secondary, size: 380)
                    .offset(x: drift ? 140 : 90, y: drift ? 120 : 210)
                blob(.codeMint.opacity(0.7), size: 300)
                    .offset(x: drift ? 60 : 130, y: drift ? 420 : 350)
            }
        }
        .clipped()
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 90)
            .opacity(0.38)
    }
}

// MARK: - Buttons

/// Shrinks and dims on press. Applied to every tappable surface so touches feel
/// physical rather than instantaneous.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The filled, full-width call to action.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var gradient: LinearGradient = GameKind.codeCracker.gradient
    var isEnabled: Bool = true
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        gradient: LinearGradient = GameKind.codeCracker.gradient,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.gradient = gradient
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(.black.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient, in: Capsule())
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled)
    }
}

/// The quiet counterpart: glass, no fill.
struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassSurface(Capsule(), interactive: true)
            .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Text entry

/// A name field on a glass pill.
struct AppTextField: View {
    let title: String
    @Binding var text: String
    var systemImage: String = "person.fill"
    var accent: Color = .codeAccent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22)
            TextField(
                "",
                text: $text,
                prompt: Text(title).foregroundStyle(Color.textTertiary)
            )
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(.white)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 18)
        .glassSurface(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.hairline, lineWidth: 1))
    }
}

// MARK: - Shared chrome

/// Section label above a group of controls.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(Color.textTertiary)
    }
}

/// One player's name, dimmed until it is their turn.
struct PlayerChip: View {
    let name: String
    let symbol: String
    let color: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(isActive ? .black.opacity(0.85) : color)
                .frame(width: 26, height: 26)
                .background(isActive ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.18)), in: Circle())
            Text(name)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(isActive ? .white : Color.textTertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background {
            Capsule()
                .fill(color.opacity(isActive ? 0.16 : 0))
                .overlay(Capsule().stroke(color.opacity(isActive ? 0.5 : 0), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }
}

/// The two-player turn indicator that sits above every board.
struct TurnBar: View {
    struct Seat {
        let name: String
        let symbol: String
        let color: Color
    }

    let seats: [Seat]
    /// Index of the seat to play, or `nil` when the game has ended.
    let activeIndex: Int?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(seats.enumerated()), id: \.offset) { index, seat in
                PlayerChip(
                    name: seat.name,
                    symbol: seat.symbol,
                    color: seat.color,
                    isActive: activeIndex == index
                )
            }
        }
        .padding(5)
        .glassSurface(Capsule())
        .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeIndex)
    }
}

/// Inline validation message. Reserves no space when empty.
struct ErrorLine: View {
    let message: String?

    var body: some View {
        Group {
            if let message {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message)
                }
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                .multilineTextAlignment(.center)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }
}

// MARK: - End of game

/// The card that covers the board when somebody wins or the game draws.
struct WinOverlay: View {
    let headline: String
    let detail: String
    let accent: Color
    let onPlayAgain: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            ConfettiView(colors: [accent, .codeMint, .discYellow, .markX])
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(accent.gradient)
                    .glow(accent, radius: 20)

                VStack(spacing: 6) {
                    Text(headline)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(detail)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(spacing: 10) {
                    PrimaryButton(
                        title: "Play again",
                        systemImage: "arrow.counterclockwise",
                        gradient: LinearGradient(
                            colors: [accent, accent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        action: onPlayAgain
                    )
                    Button("Review the board", action: onDismiss)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .glassCard(tint: accent)
            .padding(32)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

/// Cheap one-shot confetti: each piece flies to a random point and fades.
struct ConfettiView: View {
    let colors: [Color]
    private let pieces = (0..<44).map { _ in Piece() }

    @State private var launched = false

    private struct Piece {
        let x = Double.random(in: 0.05...0.95)
        let drift = Double.random(in: -60...60)
        let delay = Double.random(in: 0...0.35)
        let duration = Double.random(in: 1.6...2.8)
        let spin = Double.random(in: -540...540)
        let size = Double.random(in: 6...11)
        let colorIndex = Int.random(in: 0...3)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[piece.colorIndex % colors.count])
                        .frame(width: piece.size, height: piece.size * 1.7)
                        .rotationEffect(.degrees(launched ? piece.spin : 0))
                        .position(
                            x: proxy.size.width * piece.x + (launched ? piece.drift : 0),
                            y: launched ? proxy.size.height + 40 : -40
                        )
                        .opacity(launched ? 0 : 1)
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: launched
                        )
                        .id(index)
                }
            }
        }
        .onAppear { launched = true }
    }
}

// MARK: - Screen scaffold

/// Background, title and consistent padding for a game screen.
struct GameShell<Content: View>: View {
    let kind: GameKind
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            AuroraBackground(tint: kind.accent, secondary: kind.secondaryAccent)
            content()
                .padding(.horizontal, 20)
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// The pieces the games are drawn from: marks, discs, code entry, and the
// miniature board art on the home screen.

// MARK: - Tic-Tac-Toe

/// An X or an O, drawn as strokes rather than text so it scales cleanly.
struct MarkGlyph: View {
    let mark: Mark
    var color: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let inset = proxy.size.width * 0.26
            let rect = CGRect(origin: .zero, size: proxy.size).insetBy(dx: inset, dy: inset)

            Group {
                switch mark {
                case .x:
                    Path { path in
                        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                case .o:
                    Circle()
                        .path(in: rect)
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
            .glow(color, radius: 10, opacity: 0.7)
        }
    }
}

extension Mark {
    var color: Color {
        switch self {
        case .x: .markX
        case .o: .markO
        }
    }
}

// MARK: - Connect 4

/// A disc with a lit top edge, so the board reads as physical.
struct DiscView: View {
    let color: Color
    var isWinning: Bool = false

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.95), color.opacity(0.6)],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: 1,
                    endRadius: 34
                )
            )
            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .overlay(Circle().strokeBorder(Color.white, lineWidth: isWinning ? 3 : 0))
            .glow(color, radius: isWinning ? 14 : 6, opacity: isWinning ? 0.9 : 0.45)
    }
}

extension Disc {
    var color: Color {
        switch self {
        case .red: .discRed
        case .yellow: .discYellow
        }
    }
}

/// An empty socket in the board frame.
struct EmptySocket: View {
    var highlight: Color?

    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.5))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            // A ring, not a fill: a filled socket reads as a disc already played
            // there, which made every column's landing row look occupied.
            .overlay(Circle().strokeBorder(highlight?.opacity(0.6) ?? .clear, lineWidth: 2))
            .overlay(Circle().fill(highlight?.opacity(0.08) ?? .clear))
    }
}

// MARK: - CodeCracker

/// Four digit slots. Filled slots show the digit, or a dot when `isMasked`.
struct CodeBoxes: View {
    let digits: String
    var accent: Color = .codeAccent
    var isMasked: Bool = false
    var isFocused: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<SecretCode.length, id: \.self) { index in
                let characters = Array(digits)
                let character = index < characters.count ? String(characters[index]) : ""
                let isNext = isFocused && index == characters.count

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(character.isEmpty ? 0.05 : 0.10))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isNext ? accent : Color.hairline, lineWidth: isNext ? 2 : 1)

                    if !character.isEmpty {
                        if isMasked {
                            Circle().fill(accent).frame(width: 12, height: 12)
                        } else {
                            Text(character)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(height: 62)
                .glow(isNext ? accent : .clear, radius: 10, opacity: 0.5)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: digits)
    }
}

/// A digit pad, so code entry never summons the system keyboard.
struct Keypad: View {
    var accent: Color = .codeAccent
    var canSubmit: Bool
    var submitLabel: String
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void

    private let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        key(String(digit)) { onDigit(digit) }
                    }
                }
            }
            HStack(spacing: 10) {
                key("delete.left", isSymbol: true, action: onDelete)
                key("0") { onDigit(0) }
                Button(action: onSubmit) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            accent.opacity(canSubmit ? 1 : 0.2),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSubmit)
                .accessibilityLabel(submitLabel)
            }
        }
    }

    private func key(_ label: String, isSymbol: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isSymbol {
                    Image(systemName: label).font(.system(size: 19, weight: .semibold))
                } else {
                    Text(label).font(.system(size: 25, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .glassSurface(RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Feedback for one guess: filled pegs for exact digits, hollow for misplaced.
struct FeedbackPegs: View {
    let feedback: Feedback

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<SecretCode.length, id: \.self) { index in
                if index < feedback.correctPositions {
                    Circle().fill(Color.codeMint).frame(width: 9, height: 9)
                } else if index < feedback.correctPositions + feedback.correctDigits {
                    Circle().strokeBorder(Color.discYellow, lineWidth: 2).frame(width: 9, height: 9)
                } else {
                    Circle().fill(Color.white.opacity(0.12)).frame(width: 9, height: 9)
                }
            }
        }
    }
}

// MARK: - Home screen art

/// A small board preview for each game tile.
struct GameThumbnail: View {
    let kind: GameKind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(kind.accent.opacity(0.18))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(kind.accent.opacity(0.45), lineWidth: 1)

            switch kind {
            case .ticTacToe: ticTacToeArt
            case .connect4: connect4Art
            case .codeCracker: codeCrackerArt
            }
        }
        .frame(width: 68, height: 68)
        .glow(kind.accent, radius: 12, opacity: 0.35)
    }

    private var ticTacToeArt: some View {
        let marks: [Mark?] = [.x, nil, .o, nil, .x, nil, .o, nil, .x]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
            ForEach(0..<9, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08))
                    if let mark = marks[index] {
                        MarkGlyph(mark: mark, color: mark.color, lineWidth: 2)
                    }
                }
                .frame(height: 12)
            }
        }
        .padding(9)
    }

    private var connect4Art: some View {
        let discs: [Disc?] = [nil, nil, .red, nil, .yellow, .red, .red, .yellow, .yellow]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
            ForEach(0..<9, id: \.self) { index in
                Group {
                    if let disc = discs[index] {
                        Circle().fill(disc.color)
                    } else {
                        Circle().fill(Color.black.opacity(0.4))
                    }
                }
                .frame(height: 12)
            }
        }
        .padding(9)
    }

    private var codeCrackerArt: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(row == 2 && column < 2 ? Color.codeMint : Color.white.opacity(0.18))
                            .frame(width: 8, height: 11)
                    }
                }
            }
        }
    }
}
