from player.player import Player


class GuessPlayer(Player):
    def __init__(self, name, socket, game_id):
        super().__init__(name, socket, game_id)
        self.guess = 0
        self.secret = 0

    def get_secret(self):
        secret = input("Enter the secret number with 4 digits (every digit must be different): ")

        while not self.is_valid_secret(secret):
            secret = input("Invalid secret number. Enter the secret number with 4 digits (every digit must be different): ")

        self.secret = secret

    def is_valid_secret(self, secret):

        try:
            secret = int(secret)
            if secret < 1000 or secret > 9999:
                return False

            digits = [int(d) for d in str(secret)]
            return len(digits) == len(set(digits))
        except ValueError:
            return False
        
    def receive(self):
        guess = input("Enter your guess: ")

        while not self.is_valid_secret(guess):
            guess = input("Invalid guess. Enter your guess: ")

        return guess