# CodeCrackerKit

A Swift port of the CodeCracker game rules — the logic that lived in `games/` and
`player/` in the Python project. No networking, no server, no UI: just the rules,
so an iOS app can run a full game on-device (pass-and-play or against an AI).

```swift
var game = TicTacToeGame()
let alice = Player(name: "Alice", role: Mark.x)
let bob = Player(name: "Bob", role: Mark.o)
try game.addPlayer(alice)
try game.addPlayer(bob)

switch try game.play(4, by: alice.id) {
case .ongoing: break
case .win(let id): print("\(game.player(id: id)?.name ?? "?") wins")
case .draw: print("draw")
}
```

## Layout

| File | Ported from |
| --- | --- |
| `TurnBasedGame.swift` | `games/game.py` |
| `GuessSecretGame.swift` | `games/guess_secret_game.py` |
| `TicTacToeGame.swift` | `games/tictactoe_game.py` |
| `Connect4Game.swift` | `games/connect4_game.py` |
| `Player.swift` | `player/*.py` |
| `SecretCode.swift` | `GuessSecretGame.is_valid_input` / `calculate_score` |
| `GameError.swift` | `errors/*.py` |
| `GameID.swift` | `utils.generate_custom_id` |
| `ComputerPlayer.swift` | — (new; the Python version has no computer opponent) |

Run the tests from this directory with:

```bash
swift build --build-tests
swift test --skip-build
```

Plain `swift test` fails: it builds every target, and `CodeCrackerApp` only
compiles inside Xcode. The build step still reports those app errors, but the
kit and its tests compile first, and `--skip-build` runs them. The suite covers
the same ground as `test_games.py`, `test_tictactoe.py` and `test_connect4.py`,
plus draws, diagonals, full columns, code validation, and the computer opponent.

## Deliberate differences from the Python version

**Games are value types.** Each game is a `struct`, so copying it snapshots the
state. Undo, replay and SwiftUI change-diffing come for free. The Python classes
were reference types mutated in place.

**One move channel instead of three.** Python's `_play` returned a `Player`, the
string `"draw"`, or `None`. That is now `MoveOutcome.win(PlayerID) / .draw / .ongoing`.

**Turn order is derived, not stored.** There is no `who_will_play` field; the
current player is `players[turnHistory.count % 2]`. It cannot drift out of sync
with the board.

This fixes a real gap in the Python version: `GuessSecretGame._play` never
advanced the turn at all — `main.py:269` did it, so the rules were only correct
when driven by the server. Its turn check also read
`if uuid != who_will_play and who_will_play`, which skipped the check entirely
while `who_will_play` was `nil`. Since it was never set when the second player
joined, *either* player could open, and a player could take two turns in a row.
Here seat 0 always opens and turns alternate strictly, as in the other two games.

**Invalid codes cannot be constructed.** `SecretCode.init?` is the only way to
make one, so validity is checked once when parsing input rather than on every
move. There is no `InputError` path for a malformed guess because a malformed
guess is not representable.

**Empty cells are `nil`, not `""`.** Boards are `[Mark?]` and `[Disc?]` instead
of arrays of strings.

**A rejected move changes nothing.** Python's `Game.play` bumped
`last_played_at` before validating, so an illegal move still counted as activity.
Timestamps now only advance on success. (This mattered only for the server's
timeout reaper.)

**`sid` and `game_id` are gone from `Player`.** Both were Socket.IO bookkeeping.

**Board scanning is local.** Connect 4 checks the four directions through the
disc just played rather than rescanning all 42 cells; it also returns the winning
cells (`winningCells`, and `winningLine` for tic-tac-toe) so the UI can highlight
them.

**`GameStatus.waitingForSetup`** replaces the per-game status strings. The Python
`get_status()` returned `"Waiting for players to set their secrets"`, which only
made sense for CodeCracker; user-facing copy belongs in the app layer.

## Computer opponent

`ComputerPlayer.move(in:for:difficulty:)` picks a move for one seat of any of
the three games, or returns `nil` when it is not that seat's turn. It never
mutates the game: the caller plays the move through `play(_:by:)`, so the
computer is held to exactly the same rules. Every strategy takes an injectable
`RandomNumberGenerator`, which is how the tests stay deterministic.

| | Easy | Medium | Hard |
| --- | --- | --- | --- |
| Tic-Tac-Toe | any open cell | takes a win, else blocks, else random | full minimax — never loses |
| Connect 4 | any open column | 2-ply search | 6-ply alpha-beta search |
| CodeCracker | only uses how many digits were right | any code consistent with all feedback | minimax over consistent codes |

Things worth knowing before changing these:

- **The CodeCracker solver never sees the game.** On one device the human's
  code sits in the same `GuessSecretGame`, so `move` reads only whose turn it
  is and `history(for:)` of the computer's own guesses.
- **Medium and hard CodeCracker are nearly equal** (about 5.4 vs 5.3 guesses on
  average). Consistent guessing is already close to optimal for this game;
  that was accepted rather than making medium artificially worse.
- **Connect 4 checks for an immediate win where the search stops.** Without
  that, even search depths assume the last side to move never blocks, and
  depth 6 did no better than depth 2. With it, hard beats medium roughly 38–8–14
  over 60 games. Depth 7 is stronger but takes up to ~3s per move in a debug
  build.
- **Searches run on bare boards** (`[Mark?]`, `[Disc?]`), not copies of the
  game, so they don't copy history and timestamps at every node.

## Not included

Everything the server owned: matchmaking, rooms, reconnection, and the abandoned-game
reaper (`utils.check_game_timeout`). GameKit `GKTurnBasedMatch` could sit on
top of this package without a backend.
