from abc import ABC, abstractmethod
from uuid import uuid4

class Player(ABC):
    def __init__(self, name, sid: str, game_id, uuid=None):
        self.name = name
        self.sid = sid
        self.game_id = game_id
        self.score = 0
        if uuid:
            self._uuid = uuid
        else:
            self._uuid = str(uuid4())

    @property
    def uuid(self):
        return self._uuid
    
    def __eq__(self, other):
        return self.uuid == other.uuid

    def to_dict(self):
        return {
            "name": self.name,
            "game_id": self.game_id,
            "sid": self._sid,
            "score": self.score,
            "uuid": self.uuid
        }