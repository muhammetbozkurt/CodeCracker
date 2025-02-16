from games.game import Game
from player.guess_player import GuessPlayer
from typing import List, Union, Tuple
from errors.input_error import InputError

class GuessSecretGame(Game):
    def __init__(self, game_id: str):
        super().__init__(game_id)
        self.turn_history: List[Tuple] = []
        self.players: List[GuessPlayer] = []

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

    def get_current_player_and_target_secret(self, username):
        if self.player1.name == username:
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
    
    def play(self, username: str, guess: str) -> Union[GuessPlayer, None]:
        if not self.is_okay_start():
            raise InputError("Game is not ready to play")

        if not GuessSecretGame.is_valid_input(guess):
            raise InputError("Guess must be a 4 digit number and every digit must be different")

        turn_count = len(self.turn_history)
        current_player, secret = self.get_current_player_and_target_secret(username)

        if current_player.name != username:
            raise InputError(f"It's not your turn, {username}. Wait for {current_player.name} to play")

        correct_digits, correct_positions = self.calculate_score(guess, secret)
        self.turn_history.append({
            "player": current_player.name,
            "guess": guess,
            "result": f"+{correct_positions}, -{correct_digits}"
        })

        if self.is_game_over(correct_positions):
            return current_player
        
        return None
            
    def print_turn_history(self):
        for turn in self.turn_history:
            print(f"{turn['player']} guessed {turn['guess']} and got {turn['result']}")

    def is_game_over(self, correct_positions):
        return correct_positions == 4
    
    def is_okay_start(self):
        return len(self.players) == 2 and all([p.secret for p in self.players])
        
