import unittest
from games.guess_secret_game import GuessSecretGame
from player.guess_player import GuessPlayer
from errors.input_error import InputError
from errors.mutability_error import MutabilityError

class TestGuessSecretGame(unittest.TestCase):
    def setUp(self):
        self.game = GuessSecretGame("game_123")
        self.player1 = GuessPlayer("Player1", "sid1", "uuid1")
        self.player2 = GuessPlayer("Player2", "sid2", "uuid2")
        self.game.add_player(self.player1)
        self.game.add_player(self.player2)

    def test_game_setup_and_start(self):
        self.assertFalse(self.game.is_okay_start())
        self.player1.secret = "1234"
        self.player2.secret = "5678"
        self.assertTrue(self.game.is_okay_start())

    def test_play_turn_enforcement(self):
        # Setup secrets so game can play
        self.player1.secret = "1234"
        self.player2.secret = "5678"

        # Explicitly set P1 to play
        self.game.state.who_will_play = self.player1.uuid

        # Try to play with P2, should raise InputError
        with self.assertRaises(InputError) as context:
            self.game.play(self.player2.uuid, "1234")
        self.assertEqual(str(context.exception), "Not your turn")

    def test_play_game_over(self):
        # Setup secrets 
        self.player1.secret = "1234"
        self.player2.secret = "5678"

        # P1 guesses P2's secret exactly
        self.game.state.who_will_play = self.player1.uuid
        winner = self.game.play(self.player1.uuid, "5678")

        self.assertEqual(winner, self.player1)
        self.assertTrue(self.game.game_over_flag)
        self.assertTrue(self.game.state.is_game_over)

    def test_invalid_guess_input(self):
        self.player1.secret = "1234"
        self.player2.secret = "5678"
        self.game.state.who_will_play = self.player1.uuid

        with self.assertRaises(InputError) as context:
            self.game.play(self.player1.uuid, "1123") # Reused digit
        self.assertEqual(str(context.exception), "Guess must be a 4 digit number and every digit must be different")

if __name__ == "__main__":
    unittest.main()