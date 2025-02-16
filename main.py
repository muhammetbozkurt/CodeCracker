from fastapi import FastAPI, WebSocket
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import socketio

from player.player import Player
from games.game import Game

games = {}

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
    games[game_id] = {
        "players": [{"name": user_name, "sid": sid, "game_id": game_id}],
        "game": game_id,
        "gameId": game_id,
        "username": user_name
    }

    await sio.emit("game_created", games[game_id], room=sid)


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

    games[game_id]["players"].append({"name": user_name, "sid": sid, "game_id": game_id})

    await sio.emit("game_joined", games[game_id], room=sid)


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

    if len(game["players"]) != 2:
        await sio.emit("error", {"message": "Not enough players in the game"}, room=sid)
        return
    
    player = [p for p in game["players"] if p["name"] == username][0]