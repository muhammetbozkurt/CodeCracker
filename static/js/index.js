const socket = io();

const urlParams = new URLSearchParams(window.location.search);
const legacyGameId = urlParams.get('gameId');

if (legacyGameId) {
    document.getElementById('gameId').value = legacyGameId;
}

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