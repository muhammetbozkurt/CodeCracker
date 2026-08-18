import Foundation

@testable import CodeCrackerKit

/// Fixed ids so failures are readable and turn order is deterministic.
let player1ID = PlayerID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
let player2ID = PlayerID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)

func makeGuessSecretGame() throws -> GuessSecretGame {
    var game = GuessSecretGame(id: "game_123")
    try game.addPlayer(Player(id: player1ID, name: "Player1", role: nil))
    try game.addPlayer(Player(id: player2ID, name: "Player2", role: nil))
    return game
}

func makeTicTacToeGame() throws -> TicTacToeGame {
    var game = TicTacToeGame(id: "game_abc")
    try game.addPlayer(Player(id: player1ID, name: "Player1", role: .x))
    try game.addPlayer(Player(id: player2ID, name: "Player2", role: .o))
    return game
}

func makeConnect4Game() throws -> Connect4Game {
    var game = Connect4Game(id: "game_c4")
    try game.addPlayer(Player(id: player1ID, name: "Player1", role: .red))
    try game.addPlayer(Player(id: player2ID, name: "Player2", role: .yellow))
    return game
}

func code(_ text: String) throws -> SecretCode {
    try SecretCode(validating: text)
}
