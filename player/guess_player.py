from player.player import Player
from errors.mutability_error import MutabilityError
from uuid import uuid4

class GuessPlayer(Player):
    def __init__(self, name, sid: str, game_id, uuid=None):
        super().__init__(name, sid, game_id, uuid)
        self._secret = None

    @property
    def secret(self):
        return self._secret
    
    @secret.setter
    def secret(self, secret):
        if self._secret:
            raise MutabilityError("Secret can only be set once")
        self._secret = secret