from abc import ABC, abstractmethod
from player.player import Player

class Game(ABC):
    def __init__(self, player1: Player, player2: Player):
        self.player1 = player1
        self.player2 = player2
        self.player_list = [player1, player2]

    @abstractmethod
    def start_game(self):
        pass

    @abstractmethod
    def play(self):
        pass

    @abstractmethod
    def is_game_over(self):
        pass
