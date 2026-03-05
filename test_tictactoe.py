import unittest
from games.tictactoe_game import TicTacToeGame
from player.tictactoe_player import TicTacToePlayer
from errors.input_error import InputError
from errors.mutability_error import MutabilityError

class TestTicTacToeGame(unittest.TestCase):
    def setUp(self):
        self.game = TicTacToeGame("game_abc")
        self.player1 = TicTacToePlayer("Player1", "sid1", "uuid1", "X", uuid="uuid1")
        self.player2 = TicTacToePlayer("Player2", "sid2", "uuid2", "O", uuid="uuid2")
        self.game.add_player(self.player1)
        self.game.add_player(self.player2)

    def test_game_setup_and_start(self):
        self.assertTrue(self.game.is_okay_start())
        self.assertEqual(self.game.state.who_will_play, self.player1.uuid)
        self.assertEqual(len(self.game.state.board), 9)

    def test_play_turn_enforcement(self):
        # Explicitly set P1 to play
        self.game.state.who_will_play = self.player1.uuid

        # Try to play with P2, should raise InputError
        with self.assertRaises(InputError) as context:
            self.game.play(self.player2.uuid, 0)
        self.assertEqual(str(context.exception), "Not your turn")

    def test_invalid_move(self):
        self.game.state.who_will_play = self.player1.uuid
        self.game.play(self.player1.uuid, 0)

        # It's P2's turn now. Trying to play on cell 0 again should fail
        with self.assertRaises(InputError) as context:
            self.game.play(self.player2.uuid, 0)
        self.assertEqual(str(context.exception), "Invalid move. Cell may be occupied or out of bounds.")

        # Out of bounds
        with self.assertRaises(InputError) as context:
            self.game.play(self.player2.uuid, 9)

    def test_play_game_win(self):
        # Row 1 win for P1
        # P1: 0, 1, 2
        # P2: 3, 4
        self.game.play(self.player1.uuid, 0)
        self.game.play(self.player2.uuid, 3)
        self.game.play(self.player1.uuid, 1)
        self.game.play(self.player2.uuid, 4)
        winner = self.game.play(self.player1.uuid, 2)

        self.assertEqual(winner, self.player1)
        self.assertTrue(self.game.game_over_flag)
        self.assertTrue(self.game.state.is_game_over)
        self.assertEqual(self.game.state.winner, self.player1.uuid)
    
    def test_play_game_draw(self):
        moves = [
            (self.player1.uuid, 0),
            (self.player2.uuid, 1),
            (self.player1.uuid, 2),
            (self.player2.uuid, 4),
            (self.player1.uuid, 3),
            (self.player2.uuid, 5),
            (self.player1.uuid, 7),
            (self.player2.uuid, 6),
            (self.player1.uuid, 8)
        ]
        winner = None
        for p, m in moves:
            winner = self.game.play(p, m)
        
        self.assertEqual(winner, "draw")
        self.assertTrue(self.game.state.is_game_over)
        self.assertEqual(self.game.state.winner, "draw")

if __name__ == "__main__":
    unittest.main()
