from player.player import Player
from errors.mutability_error import MutabilityError
from uuid import uuid4

class GuessPlayer(Player):
    def __init__(self, name, sid: str, game_id, uuid=None):
        super().__init__(name, sid, game_id)
        self._secret = None
        if uuid:
            self._uuid = uuid
        else:
            self._uuid = uuid4()

    @property
    def secret(self):
        return self._secret
    
    @secret.setter
    def secret(self, secret):
        if self._secret:
            raise MutabilityError("Secret can only be set once")
        self._secret = secret
    
    @property
    def uuid(self):
        return self._uuid
    
    def __eq__(self, other):
        return self.uuid == other.uuid