import unittest
from games.connect4_game import Connect4Game
from player.connect4_player import Connect4Player
from errors.input_error import InputError
from errors.mutability_error import MutabilityError

class TestConnect4Game(unittest.TestCase):
    def setUp(self):
        self.game = Connect4Game("game_c4")
        self.player1 = Connect4Player("Player1", "sid1", "game_c4", "Red", uuid="uuid1")
        self.player2 = Connect4Player("Player2", "sid2", "game_c4", "Yellow", uuid="uuid2")
        self.game.add_player(self.player1)
        self.game.add_player(self.player2)

    def test_game_setup_and_start(self):
        self.assertTrue(self.game.is_okay_start())
        self.assertEqual(self.game.state.who_will_play, self.player1.uuid)
        self.assertEqual(len(self.game.state.board), 42)

    def test_play_turn_enforcement(self):
        # Explicitly set P1 to play
        self.game.state.who_will_play = self.player1.uuid

        with self.assertRaises(InputError) as context:
            self.game.play(self.player2.uuid, 0)
        self.assertEqual(str(context.exception), "Not your turn")

    def test_invalid_move(self):
        self.game.state.who_will_play = self.player1.uuid
        self.game.play(self.player1.uuid, 0)

        # It's P2's turn now. Trying to play on column 0 again is fine, unless column is full
        
        # Out of bounds
        with self.assertRaises(InputError) as context:
            self.game.play(self.player2.uuid, 7)

    def test_play_game_win(self):
        # Vertical 4 in a row for P1 on col 0
        self.game.play(self.player1.uuid, 0) # P1
        self.game.play(self.player2.uuid, 1) # P2
        self.game.play(self.player1.uuid, 0) # P1
        self.game.play(self.player2.uuid, 1) # P2
        self.game.play(self.player1.uuid, 0) # P1
        self.game.play(self.player2.uuid, 1) # P2
        winner = self.game.play(self.player1.uuid, 0) # P1 win

        self.assertEqual(winner, self.player1)
        self.assertTrue(self.game.game_over_flag)
        self.assertTrue(self.game.state.is_game_over)
        self.assertEqual(self.game.state.winner, self.player1.uuid)

if __name__ == "__main__":
    unittest.main()
