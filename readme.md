# CodeCracker: Multiplayer Web Game Platform

Welcome to **CodeCracker**, a fun and interactive multiplayer web game platform! It features multiple classic and unique games where players can challenge each other in real-time.

---

## 🎮 Games Available

1. **CodeCracker (Guess Secret)**: A thrilling battle of wits where players take turns guessing each other's secret numbers. The game provides feedback on correct digits and their positions.
2. **Tic-Tac-Toe**: The classic 3x3 grid game. Be the first to get 3 in a row!
3. **Connect 4**: Drop your chips into the grid and try to connect 4 in a row horizontally, vertically, or diagonally.

---

## 💻 Technologies Used

- **Frontend**: HTML, CSS, Vanilla JavaScript
- **Backend**: Python, FastAPI
- **Real-Time Communication**: Socket.IO (`python-socketio`)
- **Task Scheduling**: APScheduler (for handling game timeouts)

---

## 🚀 Setup Instructions

### Prerequisites
- Python 3.9+
- pip (Python package manager)

### Installation
1. Navigate to the project directory:
   ```bash
   cd CodeCracker
   ```

2. Install the required dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run the FastAPI server using Uvicorn:
   ```bash
   uvicorn main:app --reload
   ```

4. Open your browser and navigate to `http://127.0.0.1:8000` to start playing!
