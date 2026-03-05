from player.player import Player

class TicTacToePlayer(Player):
    def __init__(self, name: str, sid: str, game_id: str, symbol: str, uuid: str = None):
        super().__init__(name, sid, game_id, uuid)
        self.symbol = symbol # 'X' or 'O'

    def to_dict(self):
        d = super().to_dict()
        d['symbol'] = self.symbol
        return d
