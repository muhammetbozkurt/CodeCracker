const socket = io();

function showLoading() {
    // document.getElementById('loading').style.display = 'block';
}

function hideLoading() {
    // document.getElementById('loading').style.display = 'none';
}

function createGame() {
    const username = document.getElementById('username').value.trim();
    if (!username) {
        alert("Please enter a username!");
        return;
    }
    showLoading();
    socket.emit('create_game', { username });
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
    window.location.href = `/game.html?gameId=${data.gameId}&username=${data.username}`;
    localStorage.setItem('uuid', data.uuid);
});

socket.on('game_joined', (data) => {
    hideLoading();
    window.location.href = `/game.html?gameId=${data.gameId}&username=${data.username}`;
    localStorage.setItem('uuid', data.uuid);
});

socket.on('error', (message) => {
    hideLoading();
    document.getElementById('status').textContent = JSON.stringify(message);
});