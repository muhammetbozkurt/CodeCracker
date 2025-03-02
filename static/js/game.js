const urlParams = new URLSearchParams(window.location.search);
const gameId = urlParams.get('gameId');
const username = localStorage.getItem('username');
const uuid = localStorage.getItem('uuid');

if (!gameId || !username || !uuid) {
    alert('Invalid game ID or username!');
    window.location.href = `/?gameId=${gameId}`;
}

document.getElementById('gameId').textContent = gameId;
document.getElementById('username').textContent = username;

const socket = io();

// Join the game room
socket.emit('join_room', { gameId, username, uuid });

// Function to submit the secret number
function submitSecret() {
    const secret = document.getElementById('secret').value.trim();
    if (!secret) {
        alert("Please enter a secret number!");
        return;
    }
    socket.emit('submit_secret', { gameId, username, uuid, secret });
}

// Function to submit a guess
function submitGuess() {
    const guess = document.getElementById('guess').value.trim();
    if (!guess) {
        alert("Please enter a guess!");
        return;
    }
    socket.emit('submit_guess', { gameId, username, uuid, guess });
}

// Function to quit the game
function quitGame() {
    if (confirm("Are you sure you want to quit the game?")) {
        socket.emit('quit_game', { gameId, username, uuid });
        window.location.href = '/';
    }
}

function secretEnable(state) {
    document.getElementById('secret').readOnly = state;
    document.getElementById('secretButton').disabled = state;
    if (state) {
        document.getElementById('secret').classList.add('readonly');
    } else {
        document.getElementById('secret').classList.remove('readonly');
    }
}

function setSecret(secret) {
    document.getElementById('secret').value = secret;
}

function guessEnable(state) {
    document.getElementById('guess').readOnly = state;
    document.getElementById('guessButton').disabled = state;
    if (state) {
        document.getElementById('guess').classList.add('readonly');
    } else {
        document.getElementById('guess').classList.remove('readonly');
    }
}

function setGuess(guess) {
    document.getElementById('guess').value = guess;
}

function updateHistory(history) {
    const historyList = document.getElementById('history');
    historyList.innerHTML = history.map(entry => {
        const isCurrentUser = entry.uuid === uuid;
        const alignmentClass = isCurrentUser ? 'current-user' : 'opponent';
        return `
            <li class="${entry.result ? 'correct' : 'incorrect'} ${alignmentClass}">
                <span class="icon">${entry.result ? '✅' : '❌'}</span>
                <div class="details">
                    <div class="player">${entry.player}</div>
                    <div class="guess">Guessed: ${entry.guess}</div>
                    <div class="result">Correct Digits in Correct Position: <strong>${entry.correct_positions}</strong>, Correct but Misplaced Digits: <strong>${entry.correct_digits}</strong></div>
                    <div class="timestamp">${new Date().toLocaleTimeString()}</div>
                </div>
            </li>
        `;
    }).join('');
    historyList.scrollTop = historyList.scrollHeight;
}

function updateOpponentStatus(opponentName, status) {
    const opponentNameText = document.getElementById('opponentNameText');
    const gameStatusText = document.getElementById('gameStatusText');
    opponentNameText.textContent = opponentName;
    gameStatusText.textContent = status;
}

// Listen for secret submission success
socket.on('secret_submitted', () => {
    console.log('Secret submitted successfully');
    secretEnable(true);
});

socket.on('guess_turn', (data) => {
    guessEnable(false);
});

socket.on('guess_submitted', (data) => {
    setGuess('');
    guessEnable(true);
});

socket.on('update_history', (history) => {
    updateHistory(history);
});

socket.on('game_over', (winner) => {
    alert(`Game Over! ${JSON.stringify(winner)} wins!`);
});

// Listen for errors
socket.on('error', (message) => {
    alert(JSON.stringify(message));
});

socket.on('connect', () => {
    console.log('Connected to server');
    if (gameId && username && uuid) {
        socket.emit('reconnect_player', { gameId, username, uuid });
    }
});

socket.on('reconnected', (data) => {
    console.log('Reconnected successfully');
    const { gameId, uuid, secret, history, state } = data;
    console.log(JSON.stringify(data));
    console.log(uuid)
    if (state.is_game_over) {
        alert('Game Over!');
    } 
    if (state.is_secret_set) {
        setSecret(secret);
        secretEnable(true);
    }
    if (state.who_will_play && state.who_will_play !== uuid) {
        guessEnable(true);
    } else {
        guessEnable(false);
    }
    updateHistory(history);
});

socket.on('game_not_found', () => {
    alert('Game not found!');
    window.location.href = '/';
});

socket.on('disconnect', () => {
    console.log('Disconnected from server');
});

socket.on('opponent_status', (status) => {
    const {players, gameStatus} = status;
    console.log(players);
    console.log(gameStatus);

    const opponentName = players.filter(player => player.uuid !== uuid).pop();
    console.log(opponentName);

    updateOpponentStatus(opponentName?.name || '', gameStatus);
}
);