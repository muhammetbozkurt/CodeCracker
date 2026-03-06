from fastapi import FastAPI, WebSocket, BackgroundTasks
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import socketio
import json
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
from datetime import datetime, timedelta

from player.player import Player
from games.game import Game

from games.guess_secret_game import GuessSecretGame
from player.guess_player import GuessPlayer
from games.tictactoe_game import TicTacToeGame
from player.tictactoe_player import TicTacToePlayer
from games.connect4_game import Connect4Game
from player.connect4_player import Connect4Player

from typing import List, Union, Dict
from errors.input_error import InputError
from errors.mutability_error import MutabilityError
from utils import check_game_timeout, generate_custom_id

GAME_IDLE_TIMEOUT = timedelta(minutes=10)

#TODO: implement restart game
# TODO: cover one quit game someone else is still in the game and the game is not over
# TODO: add spectator mode
# TODO: win screen update
# TODO: trun history show old guesses like whatsapp messages
# TODO: inform users about opponent's name, status, etc.
# TODO: check uiid before user make any changes.

games: Dict[str, Game] = {}

app = FastAPI()

scheduler = AsyncIOScheduler()
scheduler.add_job(
    check_game_timeout,
    trigger=IntervalTrigger(minutes=15),
    args=[games, GAME_IDLE_TIMEOUT],
    id="check_game_timeout",
    name="Check game timeout every 10 seconds",
    replace_existing=True,
)
scheduler.start()

sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins=[])
app.mount("/socket.io", socketio.ASGIApp(sio))

# Serve static files (like HTML, CSS, JS)
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def get():
    with open("static/index.html", "r") as f:
        return HTMLResponse(content=f.read())
    
@app.get("/game.html")
async def get_game():
    with open("static/game.html", "r") as f:
        return HTMLResponse(content=f.read())

@app.get("/tictactoe.html")
async def get_tictactoe():
    with open("static/tictactoe.html", "r") as f:
        return HTMLResponse(content=f.read())

@app.get("/connect4.html")
async def get_connect4():
    with open("static/connect4.html", "r") as f:
        return HTMLResponse(content=f.read())
    
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    while True:
        data = await websocket.receive_text()
        await websocket.send_text(f"Message text was: {data}")

@sio.event
async def connect(sid, environ):
    print("connect ", sid)
    # print(environ)
    # print("-" * 20)


@sio.event
async def create_game(sid, data):
    user_name = data.get("username")
    game_type = data.get("game_type", "guess_secret")

    if not user_name:
        await sio.emit("error", {"message": "Invalid user name"}, room=sid)
        return
       
    game_id = generate_custom_id()
    if game_type == "guess_secret":
        game = GuessSecretGame(game_id)
        first_player = GuessPlayer(user_name, sid, game_id)
    elif game_type == "tictactoe":
        game = TicTacToeGame(game_id)
        first_player = TicTacToePlayer(user_name, sid, game_id, symbol="X")
    elif game_type == "connect4":
        game = Connect4Game(game_id)
        first_player = Connect4Player(user_name, sid, game_id, color="Red")
    else:
        await sio.emit("error", {"message": "Invalid game type"}, room=sid)
        return

    game.add_player(first_player)

    games[game_id] = game

    print(f"Game {game_id} ({game_type}) created by {user_name} with player id {first_player.uuid}")

    await sio.emit("game_created", {
        "gameId": game_id,
        "username": user_name,
        "uuid": first_player.uuid,
        "gameType": game_type
    }, room=sid)

@sio.event
async def join_game(sid, data):
    user_name = data.get("username")
    game_id = data.get("gameId")

    if not user_name or not game_id:
        await sio.emit("error", {"message": "Invalid user name or game id"}, room=sid)
        return

    if game_id not in games:
        print("Game not found")
        await sio.emit("game_not_found", {"message": "Game not found"}, room=sid)
        return
    
    game = games[game_id]
    
    # Add the player to the game room
    await sio.enter_room(sid, game_id)

    if isinstance(game, GuessSecretGame):
        new_player = GuessPlayer(user_name, sid, game_id)
        game_type = "guess_secret"
    elif isinstance(game, TicTacToeGame):
        new_player = TicTacToePlayer(user_name, sid, game_id, symbol="O")
        game_type = "tictactoe"
    elif isinstance(game, Connect4Game):
        new_player = Connect4Player(user_name, sid, game_id, color="Yellow")
        game_type = "connect4"
    else:
        await sio.emit("error", {"message": "Unknown game type"}, room=sid)
        return

    game.add_player(new_player)

    await sio.emit("game_joined", {
        "gameId": game_id,
        "username": user_name,
        "uuid": new_player.uuid,
        "gameType": game_type
    }, room=sid)

@sio.event
async def submit_secret(sid, data):
    game_id = data.get("gameId")
    secret = data.get("secret")
    username = data.get("username")
    uuid = data.get("uuid")

    if not game_id or not secret or not username:
        await sio.emit("error", {"message": "Invalid game id, secret or username"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("game_not_found", {"message": "Game not found"}, room=sid)
        return
    
    game = games[game_id]

    # Check UUID
    if uuid not in [p.uuid for p in game.players]:
        await sio.emit("error", {"message": "Invalid UUID for this game"}, room=sid)
        return

    if not GuessSecretGame.is_valid_input(secret):
        await sio.emit("error", {"message": "Invalid secret"}, room=sid)
        return
    
    player = None
    for p in game.players:
        if p.uuid == uuid:
            player = p
            break
    
    if not player:
        await sio.emit("error", {"message": "Player not found in game"}, room=sid)
        return

    try:
        player.secret = secret
    except MutabilityError:
        await sio.emit("error", {"message": "Secret already submitted"}, room=sid)
        return

    await sio.emit("secret_submitted", {
        "gameId": game_id,
        "username": username,
        "uuid": uuid
    }, room=sid)

    game.state.is_secret_set[uuid] = True

    who_will_play = getattr(game.state, 'who_will_play', None)
    await sio.emit("opponent_status", {"players": [{"name": p.name, "uuid": p.uuid} for p in game.players], "gameStatus": game.get_status(), "who_will_play": who_will_play}, room=game_id)


@sio.event
async def submit_guess(sid, data):
    game_id = data.get("gameId")
    guess = data.get("guess")
    username = data.get("username")
    uuid = data.get("uuid")
    print(f"Guess: {guess}")

    if not game_id or not guess or not uuid:
        await sio.emit("error", {"message": "Invalid game id, guess or username"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("error", {"message": "Game not found"}, room=sid)
        return

    game = games[game_id]

    # Check UUID
    if uuid not in [p.uuid for p in game.players]:
        await sio.emit("error", {"message": "Invalid UUID for this game"}, room=sid)
        return
    opponent = game.player2 if game.player1.uuid == uuid else game.player1

    if not opponent:
        await sio.emit("error", {"message": "Opponent not found"}, room=sid)
        return

    print(f"Opponent: {opponent.name} - {opponent.uuid}")
    try:
        winner = game.play(uuid, guess)
    except InputError as e:
        print(f"Input error: {e}")
        await sio.emit("error", {"message": str(e)}, room=sid)
        return
    print(f"Winner: {winner}")
    if winner:
        # Game over - send the winner to both players
        await sio.emit("game_over", {
            "gameId": game_id,
            "winner": winner.name,
        }, room=game_id)

    await sio.emit("guess_submitted", {
        "gameId": game_id,
        "username": username,
        "guess": guess,
    }, room=sid)
    game.state.who_will_play = opponent.uuid

    await sio.emit("guess_turn", {
        "gameId": game_id,
        "username": opponent.name,
    }, room=opponent.sid)

    await sio.emit("update_history",  game.turn_history
    , room=game_id)
    print(sid == game.player1.sid, sid == game.player2.sid)
    print("Guess results emitted")

@sio.event
async def submit_tictactoe_move(sid, data):
    game_id = data.get("gameId")
    move = data.get("move")
    username = data.get("username")
    uuid = data.get("uuid")

    if not game_id or move is None or not uuid:
        await sio.emit("error", {"message": "Invalid parameters"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("error", {"message": "Game not found"}, room=sid)
        return

    game = games[game_id]
    if not isinstance(game, TicTacToeGame):
        await sio.emit("error", {"message": "Not a Tic-Tac-Toe game"}, room=sid)
        return

    if uuid not in [p.uuid for p in game.players]:
        await sio.emit("error", {"message": "Invalid UUID for this game"}, room=sid)
        return
    opponent = game.get_opponent(next((p for p in game.players if p.uuid == uuid), None))

    if not opponent:
        await sio.emit("error", {"message": "Opponent not found"}, room=sid)
        return

    try:
        winner = game.play(uuid, move)
    except InputError as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
        return

    await sio.emit("move_submitted", {
        "gameId": game_id,
        "username": username,
        "move": move,
    }, room=sid)

    await sio.emit("guess_turn", {
        "gameId": game_id,
        "username": opponent.name,
    }, room=opponent.sid)

    await sio.emit("update_board", {
        "board": game.state.board,
        "history": game.turn_history
    }, room=game_id)

    if winner == "draw":
        await sio.emit("game_over", {"gameId": game_id, "winner": "draw"}, room=game_id)
    elif winner:
        await sio.emit("game_over", {"gameId": game_id, "winner": winner.name}, room=game_id)

@sio.event
async def submit_connect4_move(sid, data):
    game_id = data.get("gameId")
    col = data.get("col")
    username = data.get("username")
    uuid = data.get("uuid")

    if not game_id or col is None or not uuid:
        await sio.emit("error", {"message": "Invalid parameters"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("error", {"message": "Game not found"}, room=sid)
        return

    game = games[game_id]
    if not isinstance(game, Connect4Game):
        await sio.emit("error", {"message": "Not a Connect 4 game"}, room=sid)
        return

    if uuid not in [p.uuid for p in game.players]:
        await sio.emit("error", {"message": "Invalid UUID for this game"}, room=sid)
        return
    opponent = game.get_opponent(next((p for p in game.players if p.uuid == uuid), None))

    if not opponent:
        await sio.emit("error", {"message": "Opponent not found"}, room=sid)
        return

    try:
        winner = game.play(uuid, col)
    except InputError as e:
        await sio.emit("error", {"message": str(e)}, room=sid)
        return

    await sio.emit("move_submitted", {
        "gameId": game_id,
        "username": username,
        "col": col,
    }, room=sid)

    await sio.emit("guess_turn", {
        "gameId": game_id,
        "username": opponent.name,
    }, room=opponent.sid)

    await sio.emit("update_board", {
        "board": game.state.board,
        "history": game.turn_history
    }, room=game_id)

    if winner == "draw":
        await sio.emit("game_over", {"gameId": game_id, "winner": "draw"}, room=game_id)
    elif winner:
        await sio.emit("game_over", {"gameId": game_id, "winner": winner.name}, room=game_id)

@sio.event
async def reconnect_player(sid, data):
    game_id = data.get("gameId")
    username = data.get("username")
    uuid = data.get("uuid")

    if not game_id or not username:
        await sio.emit("error", {"message": "Invalid game ID or username"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("game_not_found", {"message": "Game not found"}, room=sid)
        return

    game = games[game_id]
    found = False

    for player in game.players:
        if player.uuid == uuid:
            player.sid = sid
            found = True
            break
    
    if not found:
        await sio.emit("error", {"message": "Player not found in game"}, room=sid)
        return
    
    print(f"Player {username} reconnected to game {game_id} with uuid {uuid}")
    await sio.enter_room(sid, game_id)
    secret = getattr(player, 'secret', None)
    
    state_dict = {
        "is_game_over": game.state.is_game_over,
        "is_game_ready": game.state.is_game_ready,
        "is_game_started": game.state.is_game_started,
        "is_game_full": game.state.is_game_full,
        "who_will_play": game.state.who_will_play
    }

    if isinstance(game, GuessSecretGame):
        state_dict["is_secret_set"] = game.state.is_secret_set.get(uuid, False)
        game_type = "guess_secret"
    elif isinstance(game, TicTacToeGame):
        state_dict["board"] = game.state.board
        game_type = "tictactoe"
    elif isinstance(game, Connect4Game):
        state_dict["board"] = game.state.board
        game_type = "connect4"

    await sio.emit("reconnected", {
        "gameId": game_id,
        "gameType": game_type,
        "username": username,
        "uuid": uuid,
        "secret": secret,
        "history": game.turn_history,
        "state": state_dict
    }, room=sid)

    who_will_play = getattr(game.state, 'who_will_play', None)
    await sio.emit("opponent_status", {"players": [{"name": p.name, "uuid": p.uuid} for p in game.players], "gameStatus": game.get_status(), "who_will_play": who_will_play}, room=game_id)

@sio.event
async def quit_game(sid, data):
    game_id = data.get("gameId")
    username = data.get("username")
    uuid = data.get("uuid")

    if not game_id or not username or not uuid:
        await sio.emit("error", {"message": "Invalid game ID, username or uuid"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("game_not_found", {"message": "Game not found"}, room=sid)
        return

    game = games[game_id]

    # Check UUID
    if uuid not in [p.uuid for p in game.players]:
        await sio.emit("error", {"message": "Invalid UUID for this game"}, room=sid)
        return

    was_active = len(game.players) == 2 and not game.state.is_game_over

    for player in game.players:
        if player.uuid == uuid:
            game.players.remove(player)
            sio.leave_room(sid, game_id)
            break
            
    if was_active:
        game.state.is_game_over = True
        await sio.emit("error", {"message": f"{username} has left the game. Game over."}, room=game_id)
    
    if not game.players:
        del games[game_id]

    print(f"Player {username} quit game {game_id}")

    who_will_play = getattr(game.state, 'who_will_play', None)
    await sio.emit("opponent_status", {"players": [{"name": p.name, "uuid": p.uuid} for p in game.players], "gameStatus": game.get_status(), "who_will_play": who_will_play}, room=game_id)

@sio.event
async def disconnect(sid):
    print("disconnect ", sid)
    for game_id, game in games.items():
        for player in game.players:
            if player.sid == sid:
                sio.leave_room(sid, game_id)
                # game.players.remove(player)
                who_will_play = getattr(game.state, 'who_will_play', None)
                await sio.emit("opponent_status", {"players": [{"name": p.name, "uuid": p.uuid} for p in game.players], "gameStatus": game.get_status(), "who_will_play": who_will_play}, room=game_id)
                break