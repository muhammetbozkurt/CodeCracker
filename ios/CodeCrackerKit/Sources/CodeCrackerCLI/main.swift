import CodeCrackerKit
import Foundation

// A pass-and-play terminal driver for CodeCrackerKit. Every rule decision comes
// from the package — this file only reads input and draws boards.
//
//   swift run codecracker              # menu
//   swift run codecracker tictactoe    # straight into a game
//   swift run codecracker demo         # scripted playthrough of all three

/// Input source, so the scripted demo and a live terminal share one code path.
final class Input {
    private var scripted: [String]
    private let echo: Bool

    init(scripted: [String] = [], echo: Bool = false) {
        self.scripted = scripted
        self.echo = echo
    }

    var isScripted: Bool { !scripted.isEmpty }

    func next() -> String? {
        guard !scripted.isEmpty else { return readLine() }
        let line = scripted.removeFirst()
        if echo { print(line) }
        return line
    }
}

func announce(_ outcome: MoveOutcome, name: (PlayerID) -> String?) {
    switch outcome {
    case .ongoing:
        break
    case .win(let id):
        print("\n  🏆 \(name(id) ?? "somebody") wins!")
    case .draw:
        print("\n  🤝 A draw.")
    }
}

/// Drives any two-player game to completion.
func run<G: TurnBasedGame>(
    _ game: inout G,
    input: Input,
    render: (G) -> String,
    prompt: String,
    parse: (String) -> G.Move?
) {
    print("\n" + render(game))

    while !game.isOver, let turnHolder = game.currentPlayerID {
        let player = game.player(id: turnHolder)
        print("\n  \(player?.name ?? "?") — \(prompt)")

        guard let line = input.next() else {
            print("  (out of input)")
            return
        }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if ["quit", "q", "exit"].contains(trimmed.lowercased()) {
            print("  Bye.")
            return
        }
        guard let move = parse(trimmed) else {
            print("  ✗ Couldn't read \"\(trimmed)\".")
            continue
        }

        do {
            let outcome = try game.play(move, by: turnHolder)
            print("\n" + render(game))
            announce(outcome) { game.player(id: $0)?.name }
        } catch {
            // Rejections come straight from the package.
            print("  ✗ \(error.localizedDescription)")
        }
    }
}

func askName(_ seat: String, default fallback: String, input: Input) -> String {
    print("  \(seat) name (enter for \(fallback)):")
    let typed = input.next()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return typed.isEmpty ? fallback : typed
}

// MARK: - Games

func playTicTacToe(input: Input) throws {
    print("\n── Tic-Tac-Toe ──")
    var game = TicTacToeGame()
    try game.addPlayer(Player(name: askName("X", default: "Alice", input: input), role: .x))
    try game.addPlayer(Player(name: askName("O", default: "Bob", input: input), role: .o))
    print("  Game \(game.id)")

    run(&game, input: input, render: render, prompt: "pick a cell (0–8):") { Int($0) }
}

func playConnect4(input: Input) throws {
    print("\n── Connect 4 ──")
    var game = Connect4Game()
    try game.addPlayer(Player(name: askName("Red", default: "Alice", input: input), role: .red))
    try game.addPlayer(Player(name: askName("Yellow", default: "Bob", input: input), role: .yellow))
    print("  Game \(game.id)")

    run(&game, input: input, render: render, prompt: "drop into a column (0–6):") { Int($0) }
}

func playCodeCracker(input: Input) throws {
    print("\n── CodeCracker ──")
    print("  Each player hides a 4-digit code with no repeated digits,")
    print("  then you take turns guessing each other's.")

    var game = GuessSecretGame()
    let names = [
        askName("Player 1", default: "Alice", input: input),
        askName("Player 2", default: "Bob", input: input),
    ]
    for name in names {
        try game.addPlayer(Player(name: name, role: nil))
    }
    print("  Game \(game.id)")

    // Setup: both players commit a secret before any guessing.
    for player in game.players {
        while !game.hasChosenSecret(player.id) {
            print("\n  \(player.name), your secret code:")
            guard let line = input.next() else { return }
            do {
                try game.setSecret(SecretCode(validating: line), for: player.id)
                print("  Locked in.")
            } catch {
                print("  ✗ \(error.localizedDescription)")
            }
        }
    }

    print("\n" + guessLegend)
    run(&game, input: input, render: render, prompt: "guess your opponent's code:") {
        SecretCode($0)
    }
}

// MARK: - Entry point

let arguments = Array(CommandLine.arguments.dropFirst())

func demo() throws {
    print("\n═══ Scripted demo — every move below is fed to the real package ═══")

    // X takes the top row.
    try playTicTacToe(input: Input(scripted: ["", "", "0", "3", "1", "4", "0", "2"], echo: true))

    // Red stacks four in column 0. Includes a full-column rejection.
    try playConnect4(
        input: Input(scripted: ["", "", "0", "1", "0", "1", "0", "1", "0"], echo: true)
    )

    // Alice cracks 5678 on her second guess. Includes two invalid codes.
    try playCodeCracker(
        input: Input(
            scripted: ["", "", "1234", "1123", "5678", "5687", "1111", "1357", "5678"],
            echo: true
        )
    )
}

switch arguments.first?.lowercased() {
case "demo":
    try demo()
case "tictactoe", "ttt":
    try playTicTacToe(input: Input())
case "connect4", "c4":
    try playConnect4(input: Input())
case "codecracker", "guess":
    try playCodeCracker(input: Input())
case let other:
    if let other { print("Unknown game \"\(other)\".") }
    print(
        """

        CodeCracker — pass and play

          1  CodeCracker (guess the code)
          2  Tic-Tac-Toe
          3  Connect 4

        Pick a number:
        """
    )
    let input = Input()
    switch input.next()?.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "1": try playCodeCracker(input: input)
    case "2": try playTicTacToe(input: input)
    case "3": try playConnect4(input: input)
    default: print("Nothing picked. Try: swift run codecracker demo")
    }
}
