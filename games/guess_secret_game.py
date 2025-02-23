from games.game import Game
from player.guess_player import GuessPlayer
from typing import List, Union, Tuple, Dict
from errors.input_error import InputError

class GameState:
    who_will_play: str = None
    is_game_over: bool = False
    is_game_ready: bool = False
    is_game_started: bool = False
    is_game_full: bool = False
    is_secret_set: Dict[str, bool] = {} # {player_uuid: bool}


class GuessSecretGame(Game):
    def __init__(self, game_id: str):
        super().__init__(game_id)
        self.turn_history: List[Dict] = []
        self.players: List[GuessPlayer] = []
        self.state = GameState()

    def add_player(self, player: GuessPlayer):
        if len(self.players) == 2:
            raise ValueError("Game is full")
        self.players.append(player)

    def remove_player(self, player: GuessPlayer):
        self.players.remove(player)

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
    
    @staticmethod
    def is_valid_input(secret):
        try:
            secret = int(secret)
            if secret < 1000 or secret > 9999:
                return False

            digits = [int(d) for d in str(secret)]
            return len(digits) == len(set(digits))
        except ValueError:
            return False

    def get_current_player_and_target_secret(self, uuid: str) -> Tuple[GuessPlayer, str]:
        if self.player1.uuid == uuid:
            return self.player1, self.player2.secret
        return self.player2, self.player1.secret
    

    
    def calculate_score(self, guess:str , secret: str) -> tuple:
        correct_digits = 0
        correct_positions = 0

        for i in range(4):
            if guess[i] == secret[i]:
                correct_positions += 1
            elif guess[i] in secret:
                correct_digits += 1

        return correct_digits, correct_positions
    
    def _play(self, uuid: str, guess: str) -> Union[GuessPlayer, None]:
        if not GuessSecretGame.is_valid_input(guess):
            raise InputError("Guess must be a 4 digit number and every digit must be different")

        if uuid != self.state.who_will_play and self.state.who_will_play:
            raise InputError("Not your turn")
    
        current_player, secret = self.get_current_player_and_target_secret(uuid)

        correct_digits, correct_positions = self.calculate_score(guess, secret)
        self.turn_history.append({
            "uuid": uuid,
            "player": current_player.name,
            "guess": guess,
            "result": 4 == correct_positions,
            "correct_positions": correct_positions,
            "correct_digits": correct_digits
        })

        if self.is_game_over(correct_positions):
            return current_player
        
        return None
            
    def print_turn_history(self):
        for turn in self.turn_history:
            print(f"{turn['player']} guessed {turn['guess']} and got {turn['result']}")

    # TODO: improve this method
    def is_game_over(self, correct_positions=None):
        self.state.is_game_over = correct_positions == 4
        self.game_over_flag = correct_positions == 4
        print(f"Correct positions: {correct_positions}")
        print(f"Game over: {correct_positions == 4}")
        return correct_positions == 4
    
    def is_okay_start(self):
        return len(self.players) == 2 and all([p.secret for p in self.players])
        
