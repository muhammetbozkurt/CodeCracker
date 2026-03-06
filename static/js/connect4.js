const socket = io();

const urlParams = new URLSearchParams(window.location.search);
const gameId = urlParams.get('gameId');

const uuid = localStorage.getItem('uuid');
const username = localStorage.getItem('username');

let myTurn = false;
let gameOver = false;

if (!gameId || !uuid || !username) {
    window.location.href = '/';
}

document.getElementById('gameIdDisplay').innerText = gameId;

function copyGameId() {
    navigator.clipboard.writeText(gameId).then(() => {
        alert("Game ID copied!");
    });
}

// Generate the board
const boardElement = document.getElementById('board');
for (let r = 0; r < 6; r++) {
    for (let c = 0; c < 7; c++) {
        const cell = document.createElement('div');
        cell.className = 'c4-cell';
        cell.id = `cell-${r * 7 + c}`;
        cell.onclick = () => makeMove(c);
        boardElement.appendChild(cell);
    }
}

// Reconnect to the room
socket.emit('reconnect_player', {
    gameId: gameId,
    username: username,
    uuid: uuid
});

function updateStatus(msg) {
    document.getElementById('status-message').innerText = msg;
}

function renderBoard(board) {
    for (let i = 0; i < 42; i++) {
        const cell = document.getElementById(`cell-${i}`);
        cell.className = 'c4-cell ' + (board[i] === 'Red' ? 'red' : (board[i] === 'Yellow' ? 'yellow' : ''));
    }
}

function makeMove(col) {
    if (gameOver || !myTurn) return;

    socket.emit('submit_connect4_move', {
        gameId: gameId,
        username: username,
        uuid: uuid,
        col: col
    });
}

function quitGame() {
    socket.emit('quit_game', { gameId, username, uuid });
    window.location.href = '/';
}

socket.on('reconnected', (data) => {
    console.log("Reconnected", data);
    if (data.gameType !== 'connect4') {
        window.location.href = `/game.html?gameId=${gameId}`;
        return;
    }

    renderBoard(data.state.board);
    myTurn = data.state.who_will_play === uuid;
    gameOver = data.state.is_game_over;

    if (gameOver) {
        updateStatus("Game Over!");
        document.getElementById('endGameMessage').innerText = "This game instance has already concluded.";
        document.getElementById('endGameTitle').innerText = "Game Over";
        document.getElementById('endGameModal').style.display = 'block';
        document.getElementById('modalOverlay').style.display = 'block';
    } else if (!data.state.is_game_full) {
        updateStatus("Waiting for opponent...");
    } else {
        updateStatus(myTurn ? "Your turn!" : "Opponent's turn");
    }
});

socket.on('update_board', (data) => {
    renderBoard(data.board);
});

socket.on('guess_turn', (data) => {
    myTurn = true;
    updateStatus("Your turn!");
});

socket.on('move_submitted', (data) => {
    myTurn = false;
    updateStatus("Opponent's turn");
});

socket.on('game_over', (data) => {
    gameOver = true;
    let message = "";
    if (data.winner === "draw") {
        message = "It's a Draw!";
        document.getElementById('endGameTitle').innerText = "Tie Game";
    } else {
        message = data.winner === username ? "You Win!" : data.winner + " Wins!";
        document.getElementById('endGameTitle').innerText = data.winner === username ? "Victory!" : "Defeat";
    }
    updateStatus(message);
    document.getElementById('endGameMessage').innerText = message;
    document.getElementById('endGameModal').style.display = 'block';
    document.getElementById('modalOverlay').style.display = 'block';
});

socket.on('opponent_status', (data) => {
    if (!gameOver) {
        if (data.players.length < 2) {
            updateStatus("Waiting for opponent...");
            myTurn = false;
        } else {
            if (data.who_will_play === uuid) {
                myTurn = true;
                updateStatus("Your turn!");
            } else {
                myTurn = false;
                updateStatus("Opponent's turn");
            }
        }
    }
});

socket.on('error', (data) => {
    alert(data.message);
    if (data.message.includes("has left")) {
        window.location.href = '/';
    }
});
