const socket = io();

const urlParams = new URLSearchParams(window.location.search);
const legacyGameId = urlParams.get('gameId');

if (legacyGameId) {
    document.getElementById('gameId').value = legacyGameId;
}

const gameRulesMap = {
    'guess_secret': `
        <li>Each player selects a secret number.</li>
        <li>Players take turns guessing each other's secret number.</li>
        <li>After each guess, hints are provided about correct digits and their positions.</li>
        <li>The first player to guess the full number correctly wins!</li>
    `,
    'tictactoe': `
        <li>Players take turns placing their marks (X or O) in empty squares.</li>
        <li>The first player to get 3 of their marks in a row (up, down, across, or diagonally) is the winner.</li>
        <li>When all 9 squares are full, the game is over. If no player has 3 marks in a row, the game ends in a tie.</li>
    `
};

document.getElementById('gameType').addEventListener('change', function () {
    const rulesList = document.getElementById('gameRules');
    if (rulesList && gameRulesMap[this.value]) {
        rulesList.innerHTML = gameRulesMap[this.value];
    }
});

document.addEventListener('DOMContentLoaded', () => {
    const gameTypeSelect = document.getElementById('gameType');
    if (gameTypeSelect) {
        gameTypeSelect.dispatchEvent(new Event('change'));
    }
});

function showLoading() {
    // document.getElementById('loading').style.display = 'block';
}

function hideLoading() {
    // document.getElementById('loading').style.display = 'none';
}

function createGame() {
    const username = document.getElementById('username').value.trim();
    const gameType = document.getElementById('gameType').value;
    if (!username) {
        alert("Please enter a username!");
        return;
    }
    showLoading();
    socket.emit('create_game', { username, game_type: gameType });
}

function joinGame() {
    const username = document.getElementById('username').value.trim();
    const gameId = document.getElementById('gameId').value.trim();

    if (!username || !gameId) {
        alert("Please enter a username and game ID!");
        return;
    }
    showLoading();
    socket.emit('join_game', { gameId, username });
}

socket.on('game_created', (data) => {
    hideLoading();
    const page = data.gameType === 'tictactoe' ? 'tictactoe.html' : 'game.html';
    window.location.href = `/${page}?gameId=${data.gameId}`;
    localStorage.setItem('uuid', data.uuid);
    localStorage.setItem('username', data.username);
});

socket.on('game_joined', (data) => {
    hideLoading();
    const page = data.gameType === 'tictactoe' ? 'tictactoe.html' : 'game.html';
    window.location.href = `/${page}?gameId=${data.gameId}`;
    localStorage.setItem('uuid', data.uuid);
    localStorage.setItem('username', data.username);
});

socket.on('error', (message) => {
    hideLoading();
    document.getElementById('status').textContent = JSON.stringify(message);
});