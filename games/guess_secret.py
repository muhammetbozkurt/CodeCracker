from games.game import Game
from player.guess_player import GuessPlayer

class GuessSecret(Game):
    def __init__(self, player1: GuessPlayer, player2: GuessPlayer):
        super().__init__(player1, player2)
        self.turn_history = []


    def get_current_player_and_target_secret(self, turn_count):
        if turn_count % 2 == 0:
            return self.player1, self.player2.secret
        else:
            return self.player2, self.player1.secret

    def start_game(self):
        # get secret numbers for both players
        self.player1.get_secret()
        self.player2.get_secret()

    
    def calculate_score(self, guess:str , secret: str) -> tuple:
        correct_digits = 0
        correct_positions = 0

        for i in range(4):
            if guess[i] == secret[i]:
                correct_positions += 1
            elif guess[i] in secret:
                correct_digits += 1

        return correct_digits, correct_positions



    def play(self):
        self.start_game()
        turn_count = 0
        current_score = 0
        while not self.is_game_over(current_score):
            current_player, secret = self.get_current_player_and_target_secret(turn_count)
            guess = current_player.receive()
            correct_digits, correct_positions = self.calculate_score(guess, secret)
            current_score = correct_positions
            self.turn_history.append((current_player.name, guess, f"+{correct_positions}, -{correct_digits}"))
            turn_count += 1
            print(f"{current_player.name} guessed {guess} and got {correct_positions} correct positions and {correct_digits} correct digits")

        print(f"Game over! {current_player.name} won!")

        print("-" * 20)
        print("-" * 20)
        print("Turn history:")
        self.print_turn_history()

            
    def print_turn_history(self):
        for turn in self.turn_history:
            print(f"{turn[0]} guessed {turn[1]} and got {turn[2]}")

    def is_game_over(self, score):
        return score == 4
    


if __name__ == "__main__":
    player1 = GuessPlayer("Player1", None, 1)
    player2 = GuessPlayer("Player2", None, 1)
    game = GuessSecret(player1, player2)
    game.play()