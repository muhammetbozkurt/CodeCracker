from fastapi import FastAPI, WebSocket
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import socketio
import json

from player.player import Player
from games.game import Game

from games.guess_secret_game import GuessSecretGame
from player.guess_player import GuessPlayer

from typing import List, Union, Dict
from errors.input_error import InputError
from errors.mutability_error import MutabilityError

# TODO: use GAME class instead of GuessSecretGame when new games are added

# TODO: add user uuid to the player object and use it to identify players
# TODO: implement restart game

games: Dict[str, GuessSecretGame] = {}

app = FastAPI()

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
       
    game_id = str(len(games) + 1)
    game = GuessSecretGame(game_id)
    first_player = GuessPlayer(user_name, sid, game_id)
    game.add_player(first_player)

    games[game_id] = game

    await sio.emit("game_created", {
        "gameId": game_id,
        "username": user_name
    }, room=sid)


@sio.event
async def join_game(sid, data):
    user_name = data.get("username")
    game_id = data.get("gameId")

    print(games)

    if not user_name or not game_id:
        await sio.emit("error", {"message": "Invalid user name or game id"}, room=sid)
        return
    print(f"{user_name} is trying to join game {game_id}")
    if game_id not in games:
        print("Game not found")
        await sio.emit("error", {"message": "Game not found"}, room=sid)
        return
    
    # Add the player to the game room
    await sio.enter_room(sid, game_id)

    games[game_id].add_player(GuessPlayer(user_name, sid, game_id))

    await sio.emit("game_joined", {
        "gameId": game_id,
        "username": user_name
    }, room=sid)


@sio.event
async def submit_secret(sid, data):
    game_id = data.get("gameId")
    secret = data.get("secret")
    username = data.get("username")

    if not game_id or not secret or not username:
        await sio.emit("error", {"message": "Invalid game id, secret or username"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("error", {"message": "Game not found"}, room=sid)
        return
    
    game = games[game_id]

    if not GuessSecretGame.is_valid_input(secret):
        await sio.emit("error", {"message": "Invalid secret"}, room=sid)
        return
    
    player = game.player1 if game.player1.name == username else game.player2

    try:
        player.secret = secret
    except MutabilityError:
        await sio.emit("error", {"message": "Secret already submitted"}, room=sid)
        return

    await sio.emit("secret_submitted", {
        "gameId": game_id,
        "username": username
    }, room=sid)

    game.state.is_secret_set[username] = True

@sio.event
async def submit_guess(sid, data):
    game_id = data.get("gameId")
    guess = data.get("guess")
    username = data.get("username")
    print(f"Guess: {guess}")

    if not game_id or not guess or not username:
        await sio.emit("error", {"message": "Invalid game id, guess or username"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("error", {"message": "Game not found"}, room=sid)
        return

    game = games[game_id]
    opponent = game.player2 if game.player1.name == username else game.player1

    if game.state.who_will_play and game.state.who_will_play != username:
        await sio.emit("error", {"message": "Not your turn"}, room=sid)
        return

    print(f"Opponent: {opponent.name}")
    try:
        winner = game.play(username, guess)
    except InputError as e:
        print(f"Input error: {e}")
        await sio.emit("error", {"message": str(e)}, room=sid)
        return
    print(f"Winner: {winner}")
    if winner:
        # Game over - send the winner to both players
        await sio.emit("game_over", {
            "gameId": game_id,
            "winner": winner.name
        }, room=game_id)

    await sio.emit("guess_submitted", {
        "gameId": game_id,
        "username": username,
        "guess": guess,
    }, room=sid)
    game.state.who_will_play = opponent.name

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

    if not game_id or not username:
        await sio.emit("error", {"message": "Invalid game ID or username"}, room=sid)
        return

    if game_id not in games:
        await sio.emit("error", {"message": "Game not found"}, room=sid)
        return

    game = games[game_id]
    found = False

    for player in game.players:
        if player.name == username:
            player.sid = sid
            found = True
            break
    
    if not found:
        await sio.emit("error", {"message": "Player not found in game"}, room=sid)
        return
    
    await sio.enter_room(sid, game_id)
    await sio.emit("reconnected", {
        "gameId": game_id,
        "username": username,
        "secret": player.secret,
        "history": game.turn_history,
        "state": {
            "is_game_over": game.state.is_game_over,
            "is_game_ready": game.state.is_game_ready,
            "is_game_started": game.state.is_game_started,
            "is_game_full": game.state.is_game_full,
            "is_secret_set": game.state.is_secret_set.get(username, False),
            "who_will_play": game.state.who_will_play
        }
    }, room=sid)
