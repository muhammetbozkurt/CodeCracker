import CodeCrackerKit
import Foundation

func render(_ game: TicTacToeGame) -> String {
    var lines: [String] = []
    for row in 0..<3 {
        let cells = (0..<3).map { column -> String in
            let index = row * 3 + column
            if let mark = game.mark(row: row, column: column) {
                let highlighted = game.winningLine?.contains(index) == true
                return highlighted ? "(\(mark.rawValue))" : " \(mark.rawValue) "
            }
            return " \(index) "  // empty cells show the number you'd type
        }
        lines.append("  " + cells.joined(separator: "|"))
        if row < 2 { lines.append("  ---+---+---") }
    }
    return lines.joined(separator: "\n")
}

func render(_ game: Connect4Game) -> String {
    var lines: [String] = []
    for row in 0..<Connect4Game.rows {
        let cells = (0..<Connect4Game.columns).map { column -> String in
            let index = game.index(row: row, column: column)
            guard let disc = game.disc(row: row, column: column) else { return "." }
            let symbol = disc == .red ? "R" : "Y"
            return game.winningCells?.contains(index) == true ? symbol.lowercased() : symbol
        }
        lines.append("  | " + cells.joined(separator: " ") + " |")
    }
    lines.append("  +" + String(repeating: "-", count: Connect4Game.columns * 2 + 1) + "+")
    lines.append("    " + (0..<Connect4Game.columns).map(String.init).joined(separator: " "))
    return lines.joined(separator: "\n")
}

func render(_ game: GuessSecretGame) -> String {
    guard !game.turnHistory.isEmpty else { return "  (no guesses yet)" }

    let columns = game.players.map { player -> [String] in
        var column = ["\(player.name)'s guesses"]
        for turn in game.history(for: player.id) {
            let marker = turn.isWinning ? " ✔" : ""
            column.append("\(turn.guess)  \(turn.feedback.correctPositions)● \(turn.feedback.correctDigits)○\(marker)")
        }
        return column
    }

    let width = columns.flatMap { $0 }.map(\.count).max() ?? 0
    let depth = columns.map(\.count).max() ?? 0

    return (0..<depth).map { row in
        "  "
            + columns.map { column in
                (row < column.count ? column[row] : "").padding(
                    toLength: width, withPad: " ", startingAt: 0
                )
            }
            .joined(separator: "   ")
    }
    .joined(separator: "\n")
}

/// `●` = right digit, right place. `○` = right digit, wrong place.
let guessLegend = "  ● right place   ○ right digit, wrong place"
