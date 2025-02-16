from abc import ABC, abstractmethod

class Player(ABC):
    def __init__(self, name, sid: str, game_id):
        self.name = name
        self.sid = sid
        self.game_id = game_id
        self.score = 0

    def to_dict(self):
        return {
            "name": self.name,
            "game_id": self.game_id,
            "sid": self._sid,
            "score": self.score
        }