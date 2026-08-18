# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Two independent implementations of the same three turn-based games (CodeCracker/guess-secret,
Tic-Tac-Toe, Connect 4) live side by side:

- **Root** — a Python FastAPI + Socket.IO server with a vanilla-JS web frontend. Two players
  over a network, all state in server memory.
- **`ios/`** — `CodeCrackerKit`, a Swift port of just the *rules*, plus a SwiftUI app and a CLI
  harness. No networking, no server: on-device pass-and-play. Not yet committed to git.

The Swift port deliberately diverges from the Python semantics. `ios/CodeCrackerKit/README.md`
enumerates every difference and why — **read it before changing either side**, and update it when
the ports drift further.

## Commands

Python server:

```bash
pip install -r requirements.txt
uvicorn main:app --reload   # http://127.0.0.1:8000
```

Python tests (stdlib `unittest`, no pytest configured):

```bash
python3 -m unittest discover -p "test_*.py"
python3 -m unittest test_connect4                                        # one file
python3 -m unittest test_connect4.TestConnect4Game.test_play_turn_enforcement   # one test
```

Swift (from `ios/CodeCrackerKit/`):

```bash
swift test
swift test --filter Connect4GameTests
swift run codecracker            # interactive terminal harness; `demo` arg scripts all three games
```

The iOS app: open `ios/CodeCracker.xcodeproj` (bundle id `com.codecracker.app`, iOS 17+), or use
the simulator tooling. Xcode is the only way to build it — the app sources do not `import
CodeCrackerKit` (Xcode compiles the kit and the app into a single module) and they use UIKit-only
APIs, so the `CodeCrackerApp` SPM target does not build with `swift build` on macOS:

```bash
xcodebuild -project ios/CodeCracker.xcodeproj -scheme CodeCracker
```

`requirements.txt` is a `pip freeze` of the author's whole environment (pandas, boto3, gcloud…) —
only `fastapi`, `uvicorn`, `python-socketio`, and `apscheduler` are actually imported.

## Python architecture

`main.py` is the entire server: one module holding the `games: Dict[str, Game]` registry, the
static-file routes, and every Socket.IO handler. There is no persistence — restarting drops all
games. An APScheduler job (`utils.check_game_timeout`) reaps games idle longer than
`GAME_IDLE_TIMEOUT` (10 min) every 15 minutes.

Two parallel class hierarchies, one branch per game:

- `games/game.py` — abstract `Game`. Its `play()` is a template method: it checks
  `game_over_flag` and `is_okay_start()`, stamps `last_played_at`, then delegates to the
  subclass's `_play()`. Each subclass owns a `*GameState` object (`who_will_play`,
  `is_game_*` flags, `board`) and a `turn_history` list of dicts.
- `player/player.py` — abstract `Player` holding `name`, `sid` (Socket.IO session id),
  `game_id`, and an immutable `uuid`. `GuessPlayer.secret` is write-once and raises
  `MutabilityError` on a second set.

**Identity model:** `uuid` is the durable player identity; `sid` is transient and gets rewritten
on `reconnect_player`. Every handler that mutates a game must validate the incoming `uuid`
against `game.players` — that check is repeated inline in each handler rather than factored out.
The client persists `uuid`/`username` in `localStorage` and passes `gameId` via query string.

**Socket.IO flow.** Handlers are `create_game`, `join_game`, `submit_secret`,
`submit_guess`, `submit_tictactoe_move`, `submit_connect4_move`, `reconnect_player`,
`quit_game`, plus `connect`/`disconnect`. Server emits: `game_created`, `game_joined`,
`game_not_found`, `secret_submitted`, `guess_submitted`, `move_submitted`, `guess_turn`,
`update_board`, `update_history`, `opponent_status`, `reconnected`, `game_over`, `error`.
Rooms are keyed by `game_id`; `room=sid` targets one player. Note `create_game` never calls
`enter_room`, so the creator only joins the room on `reconnect_player` (which every game page
emits on load).

Game type is dispatched by string (`"guess_secret"`, `"tictactoe"`, `"connect4"`) in
`create_game` and by `isinstance` everywhere else. Adding a game means touching: a
`games/*_game.py`, a `player/*_player.py`, both dispatch sites, a new `submit_*_move` handler,
a route + `static/*.html` + `static/js/*.js`, and the page mapping in `static/js/index.js`.

**Known Python-side quirk** (fixed in the Swift port, kept here for compatibility with the
existing frontend): `GuessSecretGame._play` never advances `who_will_play` — `main.py` does it
after the call — and its turn guard `if uuid != who_will_play and who_will_play` no-ops while
`who_will_play` is `None`, which it is until the first guess. Tic-Tac-Toe and Connect 4 set
`who_will_play` in `add_player` and advance it inside `_play`.

Boards are flat lists with `""` for empty: 9 cells for tic-tac-toe, 42 (6 rows × 7 cols,
row-major) for Connect 4.

## Swift architecture (`ios/CodeCrackerKit/`)

Three targets over one library: `CodeCrackerKit` (rules), `CodeCrackerCLI` (terminal driver),
`CodeCrackerApp` (SwiftUI). The library has no dependencies and no UI.

Games are **structs** conforming to `TurnBasedGame`, which supplies roster management, status,
and a `play(_:by:)` template method that validates (`isOver`, `isReadyToPlay`, known player,
`currentPlayerID`) before calling the game's `applyMove`. Each game implements only `applyMove`,
`result`, `currentPlayerID`, `isReadyToPlay`.

Key invariants that differ from Python and should be preserved:

- Turn order is **derived** (`players[turnHistory.count % 2]`), never stored.
- `applyMove` returns one `MoveOutcome` (`.ongoing` / `.win(PlayerID)` / `.draw`) instead of
  Python's `Player | "draw" | None`.
- An invalid guess is unrepresentable: `SecretCode.init?` is the only constructor.
- Boards are `[Mark?]` / `[Disc?]`, empty is `nil`.
- A rejected move mutates nothing, including timestamps.

Rules changes belong in `CodeCrackerKit` and its tests, not in the views or the CLI — both are
pure drivers.
