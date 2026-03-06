from player.player import Player

class Connect4Player(Player):
    def __init__(self, name: str, sid: str, game_id: str, color: str, uuid: str = None):
        super().__init__(name, sid, game_id, uuid)
        self.color: str = color # "R" or "Y"
