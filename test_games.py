from games.guess_secret import GuessSecret
from player.guess_player import GuessPlayer


def main():
    player1 = GuessPlayer("Player1", None, 1)
    player2 = GuessPlayer("Player2", None, 2)
    game = GuessSecret(player1, player2)
    game.play()


if __name__ == "__main__":
    main()