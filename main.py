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

from typing import List, Union, Dict
from errors.input_error import InputError
from errors.mutability_error import MutabilityError
from utils import check_game_timeout, generate_custom_id

GAME_IDLE_TIMEOUT = timedelta(minutes=10)

# TODO: use GAME class instead of GuessSecretGame when new games are added

# TODO: implement restart game
# TODO: cover one quit game someone else is still in the game and the game is not over
# TODO: add spectator mode
# TODO: win screen update
# TODO: trun history show old guesses like whatsapp messages
# TODO: inform users about opponent's name, status, etc.
# TODO: check uiid before user make any changes.

games: Dict[str, GuessSecretGame] = {}

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

    if not user_name:
        sio.emit("error", {"message": "Invalid user name"}, room=sid)
        return
       
    game_id = generate_custom_id()
    game = GuessSecretGame(game_id)
    first_player = GuessPlayer(user_name, sid, game_id)
    game.add_player(first_player)

    games[game_id] = game

    print(f"Game {game_id} created by {user_name} with player id {first_player.uuid}")

    await sio.emit("game_created", {
        "gameId": game_id,
        "username": user_name,
        "uuid": first_player.uuid
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
    
    # Add the player to the game room
    await sio.enter_room(sid, game_id)

    new_player = GuessPlayer(user_name, sid, game_id)
    games[game_id].add_player(new_player)

    await sio.emit("game_joined", {
        "gameId": game_id,
        "username": user_name,
        "uuid": new_player.uuid
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

    await sio.emit("opponent_status", {"players": [{"name": p.name, "uuid": p.uuid} for p in game.players], "gameStatus": game.get_status()}, room=game_id)


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
    opponent = game.player2 if game.player1.uuid == uuid else game.player1

    if not opponent:
        await sio.emit("error", {"message": "Opponent not found"}, room=sid)
        return

    # TODO: this should be handled by the game object
    # if game.state.who_will_play and game.state.who_will_play != uuid:
    #     await sio.emit("error", {"message": "Not your turn"}, room=sid)
    #     return

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
    await sio.emit("reconnected", {
        "gameId": game_id,
        "username": username,
        "uuid": uuid,
        "secret": player.secret,
        "history": game.turn_history,
        "state": {
            "is_game_over": game.state.is_game_over,
            "is_game_ready": game.state.is_game_ready,
            "is_game_started": game.state.is_game_started,
            "is_game_full": game.state.is_game_full,
            "is_secret_set": game.state.is_secret_set.get(uuid, False),
            "who_will_play": game.state.who_will_play
        }
    }, room=sid)

    await sio.emit("opponent_status", {"players": [{"name": p.name, "uuid": p.uuid} for p in game.players], "gameStatus": game.get_status()}, room=game_id)

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

    for player in game.players:
        if player.uuid == uuid:
            game.players.remove(player)
            sio.leave_room(sid, game_id)
            break
    
    if not game.players:
        del games[game_id]

    print(f"Player {username} quit game {game_id}")

    await sio.emit("opponent_status", {"players": [{"name": p.name, "uuid": p.uuid} for p in game.players], "gameStatus": game.get_status()}, room=game_id)

@sio.event
async def disconnect(sid):
    print("disconnect ", sid)
    for game_id, game in games.items():
        for player in game.players:
            if player.sid == sid:
                sio.leave_room(sid, game_id)
                # game.players.remove(player)
                await sio.emit("opponent_status", {"players": [{"name": p.name, "uuid": p.uuid} for p in game.players], "gameStatus": game.get_status()}, room=game_id)
                break