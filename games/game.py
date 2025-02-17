from abc import ABC, abstractmethod
from player.player import Player
from typing import List, Union

class Game(ABC):
    def __init__(self, game_id: int):
        self.game_id: str = game_id
        self.players: List[Player] = []

    @abstractmethod
    def add_player(self, player: Player) -> None:
        pass

    @abstractmethod
    def is_okay_start(self) -> bool:
        pass

    @abstractmethod
    def play(self, player, move) -> Union[Player, None]:
        pass

    @abstractmethod
    def is_game_over(self) -> bool:
        pass
