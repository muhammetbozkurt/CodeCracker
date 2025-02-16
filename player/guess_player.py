from player.player import Player
from errors.mutability_error import MutabilityError


class GuessPlayer(Player):
    def __init__(self, name, sid: str, game_id):
        super().__init__(name, sid, game_id)
        self._secret = ""

    @property
    def secret(self):
        return self._secret
    
    @secret.setter
    def secret(self, secret):
        if self._secret:
            raise MutabilityError("Secret can only be set once")
        self._secret = secret