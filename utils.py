from datetime import datetime, timedelta
from typing import List, Union, Dict
from games.game import Game
import random
import time
import string


def check_game_timeout(games: Dict[str, Game], timeout: timedelta):
    now = datetime.now()
    print(f"Checking game timeout at {now}")
    print(f"Current games: {list(games.keys())}")
    for game_id, game in list(games.items()):
        print(f"Checking game {game}")
        if now - game.last_played_at > timeout:
            del games[game_id]
            print(f"Game {game_id} is over due to timeout")
    print("-"*10)
    print(f"after check games: {list(games.keys())}")


def generate_custom_id():
    timestamp = str(int(time.time()))
    random_chars = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    return f"{timestamp}-{random_chars}"