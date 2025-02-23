from abc import ABC, abstractmethod
from player.player import Player
from typing import List, Union
from errors.input_error import InputError
from datetime import datetime, timedelta

class Game(ABC):
    def __init__(self, game_id: int):
        self.game_id: str = game_id
        self.players: List[Player] = []
        self.created_at: datetime = datetime.now()
        self.started_at: datetime = None
        self.last_played_at: datetime = self.created_at
        self.game_over_flag: bool = False

    @abstractmethod
    def add_player(self, player: Player) -> None:
        pass

    @abstractmethod
    def is_okay_start(self) -> bool:
        pass

    @abstractmethod
    def _play(self, player, move) -> Union[Player, None]:
        pass

    def play(self, player, move) -> Union[Player, None]:
        if self.game_over_flag:
            raise InputError("Game is already over")
        if not self.is_okay_start():
            raise InputError("Game is not ready to play")
        
        self.last_played_at = datetime.now()
        if not self.started_at:
            self.started_at = self.last_played_at
        
        return self._play(player, move)

    @abstractmethod
    def is_game_over(self) -> bool:
        pass

    def __str__(self) -> str:
        return f"""
        Game ID: {self.game_id}
        Players: {self.players}
        Created at: {self.created_at}
        Started at: {self.started_at}
        Last played at: {self.last_played_at}
        """
    
    def __repr__(self) -> str:
        return self.__str__()