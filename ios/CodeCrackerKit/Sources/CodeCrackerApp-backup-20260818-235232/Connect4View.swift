import SwiftUI

struct Connect4View: View {
    @State private var game = Connect4Game()
    @State private var player1Name = ""
    @State private var player2Name = ""
    @State private var started = false
    @State private var errorMessage: String?
    @State private var fallingDisc: FallingDisc?
    @State private var fallingOffset: CGFloat = 0

    private let cellSize: CGFloat = 40
    private let cellSpacing: CGFloat = 6

    private struct FallingDisc: Identifiable {
        let id = UUID()
        let column: Int
        let targetRow: Int
        let color: Color
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack {
                Spacer(minLength: 0)
                if started {
                    boardSection
                } else {
                    setupSection
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .navigationTitle("Connect 4")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var setupSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red.gradient)
            VStack(spacing: 12) {
                AppTextField(title: "Red player name", text: $player1Name, systemImage: "person.fill")
                AppTextField(title: "Yellow player name", text: $player2Name, systemImage: "person.fill")
            }
            PrimaryButton(title: "Start Game", systemImage: "play.fill") { startGame() }
        }
        .cardBackground()
    }

    private func startGame() {
        var newGame = Connect4Game()
        try? newGame.addPlayer(Player(name: player1Name.isEmpty ? "Red" : player1Name, role: .red))
        try? newGame.addPlayer(Player(name: player2Name.isEmpty ? "Yellow" : player2Name, role: .yellow))
        game = newGame
        errorMessage = nil
        fallingDisc = nil
        started = true
    }

    private var boardSection: some View {
        VStack(spacing: 16) {
            statusBanner

            ZStack(alignment: .topLeading) {
                VStack(spacing: cellSpacing) {
                    ForEach(0..<Connect4Game.rows, id: \.self) { row in
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<Connect4Game.columns, id: \.self) { column in
                                cell(row: row, column: column)
                            }
                        }
                    }
                }

                if let falling = fallingDisc {
                    Circle()
                        .fill(falling.color)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .frame(width: cellSize, height: cellSize)
                        .offset(
                            x: CGFloat(falling.column) * (cellSize + cellSpacing),
                            y: CGFloat(falling.targetRow) * (cellSize + cellSpacing) + fallingOffset
                        )
                        .allowsHitTesting(false)
                }
            }
            .padding(10)
            .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }

            if game.isOver {
                SecondaryButton(title: "Play Again") {
                    started = false
                    errorMessage = nil
                }
            }
        }
    }

    private var statusBanner: some View {
        Group {
            switch game.result {
            case .win(let id):
                StatusBadge(text: "\u{1f3c6} \(game.player(id: id)?.name ?? "Someone") wins!", tint: .green)
            case .draw:
                StatusBadge(text: "\u{1f91d} Draw", tint: .orange)
            case .ongoing:
                if let turn = game.currentPlayerID, let player = game.player(id: turn) {
                    StatusBadge(text: "\(player.name)'s turn", tint: player.role == .red ? .red : .yellow)
                }
            }
        }
    }

    private func cell(row: Int, column: Int) -> some View {
        let disc = game.disc(row: row, column: column)
        let isFallingHere = fallingDisc?.column == column && fallingDisc?.targetRow == row
        let isWinning = game.winningCells?.contains(game.index(row: row, column: column)) == true
        return Circle()
            .fill(isFallingHere ? Color.blue.opacity(0.35) : color(for: disc))
            .overlay(
                Circle()
                    .strokeBorder(isWinning ? Color.white : Color.black.opacity(0.15), lineWidth: isWinning ? 3 : 1)
            )
            .shadow(color: .black.opacity(disc == nil || isFallingHere ? 0 : 0.25), radius: 2, y: 1)
            .frame(width: cellSize, height: cellSize)
            .onTapGesture { playColumn(column) }
    }

    private func color(for disc: Disc?) -> Color {
        switch disc {
        case .red: .red
        case .yellow: .yellow
        case nil: Color.blue.opacity(0.35)
        }
    }

    private func playColumn(_ column: Int) {
        guard let turn = game.currentPlayerID, !game.isOver else { return }
        guard let player = game.player(id: turn) else { return }
        guard let landingRow = game.landingRow(inColumn: column) else { return }
        let discColor = color(for: player.role)

        do {
            try game.play(column, by: turn)
            errorMessage = nil
            dropDisc(column: column, row: landingRow, color: discColor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dropDisc(column: Int, row: Int, color: Color) {
        let disc = FallingDisc(column: column, targetRow: row, color: color)
        fallingDisc = disc
        fallingOffset = -CGFloat(row + 1) * (cellSize + cellSpacing)

        withAnimation(.spring(response: 0.38, dampingFraction: 1.0)) {
            fallingOffset = 0
        } completion: {
            if fallingDisc?.id == disc.id {
                fallingDisc = nil
            }
        }
    }
}
