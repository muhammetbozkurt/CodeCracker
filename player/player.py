from abc import ABC, abstractmethod

class Player(ABC):
    def __init__(self, name, socket, game_id):
        self.name = name
        self._socket = socket
        self.game_id = game_id
        self.score = 0

    @abstractmethod
    def receive(self):
        pass