from games.game import Game
from player.connect4_player import Connect4Player
from typing import List, Union, Dict
from errors.input_error import InputError

class Connect4GameState:
    def __init__(self):
        self.who_will_play: str = None
        self.is_game_over: bool = False
        self.is_game_ready: bool = False
        self.is_game_started: bool = False
        self.is_game_full: bool = False
        self.board: List[str] = [""] * 42 
        self.winner: str = None # uuid of the winner or 'draw'

class Connect4Game(Game):
    def __init__(self, game_id: str):
        super().__init__(game_id)
        self.players: List[Connect4Player] = []
        self.state = Connect4GameState()
        self.turn_history: List[Dict] = []
        self.ROWS = 6
        self.COLS = 7

    def add_player(self, player: Connect4Player):
        if len(self.players) == 2:
            raise ValueError("Game is full")
        self.players.append(player)
        if len(self.players) == 2:
            self.state.is_game_full = True
            self.state.is_game_ready = True
            self.state.who_will_play = self.players[0].uuid

    def remove_player(self, player: Connect4Player):
        if player in self.players:
            self.players.remove(player)
        self.state.is_game_full = False
        self.state.is_game_ready = False

    def get_opponent(self, player: Connect4Player):
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

    def is_valid_input(self, col: int) -> bool:
        if not isinstance(col, int):
            try:
                col = int(col)
            except ValueError:
                return False
        if not (0 <= col < self.COLS):
            return False
        # Check if the top row of that column is empty
        return self.state.board[col] == ""

    def get_lowest_empty_row(self, col: int) -> int:
        for r in range(self.ROWS - 1, -1, -1):
            if self.state.board[r * self.COLS + col] == "":
                return r
        return -1

    def check_winner(self) -> str:
        b = self.state.board
        
        # Check horizontal
        for r in range(self.ROWS):
            for c in range(self.COLS - 3):
                idx = r * self.COLS + c
                if b[idx] and b[idx] == b[idx + 1] == b[idx + 2] == b[idx + 3]:
                    return b[idx]
                    
        # Check vertical
        for r in range(self.ROWS - 3):
            for c in range(self.COLS):
                idx = r * self.COLS + c
                if b[idx] and b[idx] == b[(r + 1) * self.COLS + c] == b[(r + 2) * self.COLS + c] == b[(r + 3) * self.COLS + c]:
                    return b[idx]
                    
        # Check diagonal (down-right)
        for r in range(self.ROWS - 3):
            for c in range(self.COLS - 3):
                idx = r * self.COLS + c
                if b[idx] and b[idx] == b[(r + 1) * self.COLS + c + 1] == b[(r + 2) * self.COLS + c + 2] == b[(r + 3) * self.COLS + c + 3]:
                    return b[idx]
                    
        # Check diagonal (up-right)
        for r in range(3, self.ROWS):
            for c in range(self.COLS - 3):
                idx = r * self.COLS + c
                if b[idx] and b[idx] == b[(r - 1) * self.COLS + c + 1] == b[(r - 2) * self.COLS + c + 2] == b[(r - 3) * self.COLS + c + 3]:
                    return b[idx]

        if "" not in b:
            return "draw"
            
        return None

    def _play(self, uuid: str, col: int) -> Union[Connect4Player, None]:
        try:
            col = int(col)
        except ValueError:
            raise InputError(f"Move must be an integer between 0 and {self.COLS - 1}")

        if uuid != self.state.who_will_play:
            raise InputError("Not your turn")
        
        if not self.is_valid_input(col):
            raise InputError("Invalid move. Column may be full or out of bounds.")

        current_player = self.player1 if self.player1.uuid == uuid else self.player2
        opponent = self.get_opponent(current_player)

        # Place the token
        row = self.get_lowest_empty_row(col)
        move_idx = row * self.COLS + col
        self.state.board[move_idx] = current_player.color

        self.turn_history.append({
            "uuid": uuid,
            "player": current_player.name,
            "col": col,
            "row": row,
            "color": current_player.color
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
