from games.game import Game
from player.tictactoe_player import TicTacToePlayer
from typing import List, Union, Dict, Tuple
from errors.input_error import InputError
from errors.mutability_error import MutabilityError

class TicTacToeGameState:
    def __init__(self):
        self.who_will_play: str = None
        self.is_game_over: bool = False
        self.is_game_ready: bool = False
        self.is_game_started: bool = False
        self.is_game_full: bool = False
        self.board: List[str] = [""] * 9 # ["", "", "", "", "", "", "", "", ""]
        self.winner: str = None # uuid of the winner or 'draw'

class TicTacToeGame(Game):
    def __init__(self, game_id: str):
        super().__init__(game_id)
        self.players: List[TicTacToePlayer] = []
        self.state = TicTacToeGameState()
        self.turn_history: List[Dict] = []

    def add_player(self, player: TicTacToePlayer):
        if len(self.players) == 2:
            raise ValueError("Game is full")
        self.players.append(player)
        if len(self.players) == 2:
            self.state.is_game_full = True
            self.state.is_game_ready = True
            # Player 1 starts, typically X
            self.state.who_will_play = self.players[0].uuid

    def remove_player(self, player: TicTacToePlayer):
        self.players.remove(player)
        self.state.is_game_full = False
        self.state.is_game_ready = False

    def get_opponent(self, player: TicTacToePlayer):
        if len(self.players) < 2:
            return None
        return self.players[0] if player == self.players[1] else self.players[1]

    @property
    def player1(self):
        if len(self.players) == 0:
            return None
        return self.players[0]
    
    @property
    def player2(self):
        if len(self.players) > 1:
            return self.players[1]
        return None

    def is_okay_start(self):
        return len(self.players) == 2

    def is_valid_input(self, move: int) -> bool:
        if not isinstance(move, int):
            try:
                move = int(move)
            except ValueError:
                return False
        return 0 <= move <= 8 and self.state.board[move] == ""

    def check_winner(self) -> str:
        b = self.state.board
        lines = [
            (0, 1, 2), (3, 4, 5), (6, 7, 8), # rows
            (0, 3, 6), (1, 4, 7), (2, 5, 8), # cols
            (0, 4, 8), (2, 4, 6)             # diagonals
        ]
        for x, y, z in lines:
            if b[x] and b[x] == b[y] == b[z]:
                return b[x] # Returns 'X' or 'O'
        if "" not in b:
            return "draw"
        return None

    def _play(self, uuid: str, move: int) -> Union[TicTacToePlayer, None]:
        try:
            move = int(move)
        except ValueError:
            raise InputError("Move must be an integer between 0 and 8")

        if uuid != self.state.who_will_play:
            raise InputError("Not your turn")
        
        if not self.is_valid_input(move):
            raise InputError("Invalid move. Cell may be occupied or out of bounds.")

        current_player = self.player1 if self.player1.uuid == uuid else self.player2
        opponent = self.get_opponent(current_player)

        self.state.board[move] = current_player.symbol
        self.turn_history.append({
            "uuid": uuid,
            "player": current_player.name,
            "move": move,
            "symbol": current_player.symbol
        })

        result = self.check_winner()

        if result:
            self.state.is_game_over = True
            self.game_over_flag = True
            if result == "draw":
                self.state.winner = "draw"
                return "draw"
            else:
                self.state.winner = uuid
                return current_player

        self.state.who_will_play = opponent.uuid
        return None

    def is_game_over(self) -> bool:
        return self.state.is_game_over

    def get_status(self):
        if self.state.is_game_over:
            return "Game over"
        if len(self.players) < 2:
            return "Waiting for players"
        return "Game is on"
