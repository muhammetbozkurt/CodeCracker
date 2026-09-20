import Foundation
import Observation

/// Drives one nearby game: owns the transport, the seat assignment, and this
/// device's copy of the board.
///
/// Both devices run their own `MultiplayerSession` over their own copy of the
/// game struct. The host deals seats; after that the two sides are symmetric,
/// each applying every move — local or remote — through the same
/// `TurnBasedGame.play(_:by:)` the pass-and-play path uses. See `NetMessage`
/// for why that stays in sync.
@MainActor
@Observable
final class MultiplayerSession {

    enum Role: Sendable { case host, guest }

    enum Phase: Equatable {
        /// Advertising, browsing, or waiting on an invitation.
        case connecting
        /// Connected, but the host has not dealt seats yet.
        case handshaking
        case playing
        /// Terminal: the opponent quit, the transport failed, or the two copies
        /// drifted apart.
        case ended(reason: String)
    }

    /// Whichever of the three games this session is running.
    enum Board {
        case ticTacToe(TicTacToeGame)
        case connect4(Connect4Game)
        case codeCracker(GuessSecretGame)

        var turnCount: Int {
            switch self {
            case .ticTacToe(let game): game.turnHistory.count
            case .connect4(let game): game.turnHistory.count
            case .codeCracker(let game): game.turnHistory.count
            }
        }

        var isOver: Bool {
            switch self {
            case .ticTacToe(let game): game.isOver
            case .connect4(let game): game.isOver
            case .codeCracker(let game): game.isOver
            }
        }

        var currentPlayerID: PlayerID? {
            switch self {
            case .ticTacToe(let game): game.currentPlayerID
            case .connect4(let game): game.currentPlayerID
            case .codeCracker(let game): game.currentPlayerID
            }
        }
    }

    // MARK: State

    let kind: GameKind
    let role: Role
    let localName: String

    private(set) var phase: Phase = .connecting
    /// Hosts advertise; guests browse and pick from this list.
    private(set) var discoveredPeers: [PeerHandle] = []
    private(set) var localPlayerID = PlayerID()
    /// The seat the other device owns. Every inbound message is checked against
    /// it, so the `playerID` in a payload is a claim we verify, not a fact.
    private(set) var remotePlayerID: PlayerID?
    /// Host side: a peer asking for the second seat, awaiting the player's yes.
    private(set) var pendingInvitation: PeerHandle?
    private(set) var opponentName: String?
    private(set) var board: Board?
    /// Last rejected move, for the views' `ErrorLine`.
    private(set) var errorMessage: String?
    /// CodeCracker: a guess sent to its owner, waiting to be scored. The turn
    /// does not advance here until the answer lands.
    private(set) var pendingGuess: SecretCode?
    /// CodeCracker: their code, once the finished game opened the commitment.
    private(set) var revealedOpponentCode: SecretCode?
    /// CodeCracker: their reveal did not match what they committed to, or did
    /// not match the feedback they gave all game.
    private(set) var opponentCheated = false

    /// This device's own code, and the salt behind its commitment. Neither is
    /// sent until the game is over.
    private var mySecret: SecretCode?
    private var mySalt: Data?

    private let transport: MultipeerTransport
    /// The one peer holding the other seat. `MCSession` can carry more than one
    /// connection, so messages are dropped unless they come from this one.
    private var opponentPeer: PeerHandle?
    private var listener: Task<Void, Never>?
    /// Host only: the guest's name, learned from `.hello`.
    private var pendingGuestName: String?

    // MARK: Lifecycle

    init(kind: GameKind, role: Role, localName: String) {
        self.kind = kind
        self.role = role
        self.localName = localName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (role == .host ? "Host" : "Guest")
            : localName
        transport = MultipeerTransport(displayName: self.localName)

        let events = transport.events
        listener = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }

        switch role {
        case .host: transport.startHosting()
        case .guest: transport.startBrowsing()
        }
    }

    /// Guests call this from the lobby list.
    func invite(_ peer: PeerHandle) {
        transport.invite(peer)
    }

    /// Host side: the player's answer to `pendingInvitation`.
    func respond(to peer: PeerHandle, accept: Bool) {
        guard pendingInvitation == peer else { return }
        pendingInvitation = nil
        transport.respond(to: peer, accept: accept)
    }

    func leave() {
        send(.quit)
        listener?.cancel()
        listener = nil
        transport.stop()
    }

    // MARK: Playing

    var isMyTurn: Bool { board?.currentPlayerID == localPlayerID }

    /// A CodeCracker guess is in flight, so the board is not yours to touch.
    var isAwaitingFeedback: Bool { pendingGuess != nil }

    var ticTacToe: TicTacToeGame? { if case .ticTacToe(let game) = board { game } else { nil } }
    var connect4: Connect4Game? { if case .connect4(let game) = board { game } else { nil } }
    var codeCracker: GuessSecretGame? { if case .codeCracker(let game) = board { game } else { nil } }

    /// Applies a move made on this device, then mirrors it to the opponent.
    /// Nothing is sent if the rules reject it.
    func submit(_ move: NetMove) {
        guard let board else { return }
        let seq = board.turnCount

        // A CodeCracker guess is scored by whoever owns the code, so this
        // device cannot apply it: send it and wait for the answer.
        if case .guess(let code) = move {
            guard isMyTurn, !isAwaitingFeedback else { return }
            pendingGuess = code
            errorMessage = nil
            send(.move(playerID: localPlayerID, seq: seq, move: move))
            return
        }

        do {
            try apply(move, by: localPlayerID)
            errorMessage = nil
            send(.move(playerID: localPlayerID, seq: seq, move: move))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// CodeCracker setup. The code stays here; the other device is told only
    /// enough to check the reveal at the end.
    func submitSecret(_ code: SecretCode) {
        guard case .codeCracker(var game) = board else { return }
        let salt = SecretCommitment.makeSalt()
        do {
            try game.setSecret(code, for: localPlayerID)
            board = .codeCracker(game)
            mySecret = code
            mySalt = salt
            errorMessage = nil
            send(.commit(playerID: localPlayerID, digest: SecretCommitment.digest(code, salt: salt)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Opens this device's commitment now that the game is over, so the other
    /// player can check every answer they were given against the real code.
    private func revealIfFinished() {
        guard case .codeCracker = board, board?.isOver == true else { return }
        guard let code = mySecret, let salt = mySalt else { return }
        send(.reveal(playerID: localPlayerID, code: code, salt: salt))
    }

    /// Guests ask; the host is the one that deals a fresh board.
    func requestRematch() {
        switch role {
        case .host: startGame()
        case .guest: send(.rematch)
        }
    }

    // MARK: Transport events

    private func handle(_ event: TransportEvent) {
        switch event {
        case .discovered(let peers):
            discoveredPeers = peers

        case .invitationReceived(let peer):
            // Only ever while hosting an empty table; anything else is declined
            // rather than quietly queued behind the current game.
            guard role == .host, phase == .connecting, pendingInvitation == nil else {
                transport.respond(to: peer, accept: false)
                return
            }
            pendingInvitation = peer

        case .connected(let peer):
            pendingInvitation = nil
            opponentPeer = peer
            opponentName = peer.displayName
            phase = .handshaking
            if role == .guest { send(.hello(name: localName)) }

        case .disconnected(let peer):
            pendingInvitation = nil
            if peer == opponentPeer { opponentPeer = nil }
            if case .ended = phase { return }
            phase = .ended(reason: "\(opponentName ?? "The other player") left the game.")

        case .received(let data, let peer):
            do {
                receive(try NetMessage.decoded(from: data), from: peer)
            } catch {
                phase = .ended(reason: "Could not read a message from the other device.")
            }

        case .failed(let reason):
            phase = .ended(reason: reason)
        }
    }

    /// Every message is judged against the seat the sending peer owns. The
    /// `playerID` in a payload is a claim, not a fact: unchecked, the opponent
    /// can move as you, set your secret before you choose one, or re-deal a
    /// board that is going badly for them.
    private func receive(_ message: NetMessage, from peer: PeerHandle) {
        guard peer == opponentPeer else { return }

        switch message {
        case .hello(let name):
            // Host side: the guest has introduced itself, so seats can be dealt.
            // Only during the handshake — mid-game this would reset the board.
            guard role == .host, phase == .handshaking else { return }
            opponentName = name
            pendingGuestName = name
            startGame()

        case .start(let kind, let gameID, let seats):
            // Guest side: adopt the host's seating verbatim, but only while
            // setting up or replacing a game that has actually finished.
            guard role == .guest, kind == self.kind, seats.count == 2 else { return }
            guard phase == .handshaking || board?.isOver == true else { return }
            localPlayerID = seats[1].playerID
            remotePlayerID = seats[0].playerID
            opponentName = seats[0].name
            board = Self.makeBoard(kind: kind, gameID: gameID, seats: seats)
            clearRoundState()
            phase = .playing

        case .commit(let playerID, let digest):
            // Their seat, their commitment. Write-once, so without this check a
            // peer could claim your seat and settle it before you chose.
            guard playerID == remotePlayerID else { return refuse() }
            guard case .codeCracker(var game) = board else { return }
            do {
                try game.commitSecret(digest, for: playerID)
                board = .codeCracker(game)
            } catch {
                refuse()
            }

        case .move(let playerID, let seq, let move):
            guard playerID == remotePlayerID else { return refuse() }
            guard let board else { return }
            guard seq == board.turnCount else {
                phase = .ended(reason: "The two devices fell out of sync.")
                return
            }
            // A move the rules reject here but accepted there means the copies
            // have drifted; there is no honest way to carry on.
            do {
                try apply(move, by: playerID)
            } catch {
                phase = .ended(reason: "The two devices fell out of sync.")
                return
            }
            // Their guess was against the code this device holds, so this is
            // the only side that can score it.
            if case .guess(let guess) = move,
               case .codeCracker(let game) = self.board,
               let turn = game.turnHistory.last {
                send(.feedback(playerID: playerID, seq: seq, guess: guess, feedback: turn.feedback))
            }
            revealIfFinished()

        case .feedback(let playerID, let seq, let guess, let feedback):
            // Only ever the answer to the guess this device is waiting on.
            guard playerID == localPlayerID, pendingGuess == guess else { return refuse() }
            guard case .codeCracker(var game) = board, seq == game.turnHistory.count else {
                phase = .ended(reason: "The two devices fell out of sync.")
                return
            }
            pendingGuess = nil
            do {
                try game.record(guess, scoredAs: feedback, by: localPlayerID)
                board = .codeCracker(game)
            } catch {
                phase = .ended(reason: "The two devices fell out of sync.")
                return
            }
            revealIfFinished()

        case .reveal(let playerID, let code, let salt):
            guard playerID == remotePlayerID else { return refuse() }
            guard case .codeCracker(let game) = board, game.isOver else { return }
            // Two ways to lie: reveal a different code than the one committed
            // to, or answer guesses all game as if the code were something else.
            let matchesCommitment = game.commitments[playerID]
                .map { $0 == SecretCommitment.digest(code, salt: salt) } ?? false
            if matchesCommitment, game.feedbackIsConsistent(with: code, guessedBy: localPlayerID) {
                revealedOpponentCode = code
            } else {
                opponentCheated = true
            }

        case .rematch:
            // Only once the game is genuinely over. Otherwise this is a way to
            // wipe a losing board.
            guard role == .host, board?.isOver == true else { return }
            startGame()

        case .quit:
            phase = .ended(reason: "\(opponentName ?? "The other player") left the game.")
        }
    }

    /// A message the other device had no right to send: either the two sides
    /// are running different builds, or somebody is cheating. Neither is worth
    /// carrying on through, and the peer's own name is not quoted back here.
    private func refuse() {
        phase = .ended(reason: "The other device sent a message it had no right to send.")
    }

    // MARK: Board plumbing

    /// Host only: deal seats, build the board, and tell the guest.
    private func startGame() {
        guard role == .host else { return }
        let seats = [
            NetSeat(playerID: PlayerID(), name: localName),
            NetSeat(playerID: PlayerID(), name: pendingGuestName ?? opponentName ?? "Guest"),
        ]
        let gameID = GameID.generate()
        localPlayerID = seats[0].playerID
        remotePlayerID = seats[1].playerID
        board = Self.makeBoard(kind: kind, gameID: gameID, seats: seats)
        clearRoundState()
        phase = .playing
        send(.start(kind: kind, gameID: gameID, seats: seats))
    }

    /// A new board means a new code, a new commitment, and nothing carried over
    /// from the last round.
    private func clearRoundState() {
        errorMessage = nil
        pendingGuess = nil
        mySecret = nil
        mySalt = nil
        revealedOpponentCode = nil
        opponentCheated = false
    }

    private static func makeBoard(kind: GameKind, gameID: String, seats: [NetSeat]) -> Board {
        switch kind {
        case .ticTacToe:
            var game = TicTacToeGame(id: gameID)
            try? game.addPlayer(Player(id: seats[0].playerID, name: seats[0].name, role: .x))
            try? game.addPlayer(Player(id: seats[1].playerID, name: seats[1].name, role: .o))
            return .ticTacToe(game)
        case .connect4:
            var game = Connect4Game(id: gameID)
            try? game.addPlayer(Player(id: seats[0].playerID, name: seats[0].name, role: .red))
            try? game.addPlayer(Player(id: seats[1].playerID, name: seats[1].name, role: .yellow))
            return .connect4(game)
        case .codeCracker:
            var game = GuessSecretGame(id: gameID)
            try? game.addPlayer(Player(id: seats[0].playerID, name: seats[0].name, role: nil))
            try? game.addPlayer(Player(id: seats[1].playerID, name: seats[1].name, role: nil))
            return .codeCracker(game)
        }
    }

    /// The one place a move reaches the rules, whether it came from this device
    /// or the wire.
    private func apply(_ move: NetMove, by playerID: PlayerID) throws {
        switch (board, move) {
        case (.ticTacToe(var game), .cell(let cell)):
            try game.play(cell, by: playerID)
            board = .ticTacToe(game)
        case (.connect4(var game), .column(let column)):
            try game.play(column, by: playerID)
            board = .connect4(game)
        case (.codeCracker(var game), .guess(let code)):
            try game.play(code, by: playerID)
            board = .codeCracker(game)
        default:
            // Move shape and board disagree — the peers are running different games.
            throw GameError.moveOutOfBounds
        }
    }

    private func send(_ message: NetMessage) {
        guard let data = try? message.encoded() else { return }
        transport.send(data)
    }
}
