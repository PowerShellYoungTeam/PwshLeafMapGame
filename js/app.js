// Main application initialization
class PwshLeafmapGame {
    constructor() {
        this.score = 0;
        this.inventory = [];
        this.gameData = null;

        this.init();
    }

    init() {
        // Initialize event listeners
        document.getElementById('loadData').addEventListener('click', () => this.loadGameData());
        document.getElementById('resetGame').addEventListener('click', () => this.resetGame());

        // Initialize the map
        this.gameMap = new GameMap('map', this);

        // Load initial game state
        this.updateUI();

        console.log('PowerShell Leafmap Game initialized!');
    }

    async loadGameData() {
        try {
            // This would typically call a PowerShell script to generate/load game data
            console.log('Loading game data via PowerShell...');

            // Simulate loading data (in a real app, this could call a PowerShell script)
            this.gameData = await this.simulateDataLoad();

            // Update map with new data
            this.gameMap.loadLocations(this.gameData.locations);

            this.updateGameInfo('Game data loaded successfully!');
        } catch (error) {
            console.error('Error loading game data:', error);
            this.updateGameInfo('Error loading game data');
        }
    }

    async simulateDataLoad() {
        // Simulate async data loading
        return new Promise(resolve => {
            setTimeout(() => {
                resolve({
                    locations: [
                        {
                            id: 'start',
                            lat: 40.7128,
                            lng: -74.0060,
                            name: 'Starting Point',
                            type: 'start',
                            description: 'Your adventure begins here in New York City!',
                            items: ['map', 'compass']
                        },
                        {
                            id: 'treasure1',
                            lat: 40.7589,
                            lng: -73.9851,
                            name: 'Central Park Treasure',
                            type: 'treasure',
                            description: 'A hidden treasure in Central Park!',
                            items: ['golden_coin', 'ancient_scroll'],
                            points: 100
                        },
                        {
                            id: 'quest1',
                            lat: 40.6892,
                            lng: -74.0445,
                            name: 'Statue of Liberty Quest',
                            type: 'quest',
                            description: 'Complete the challenge at Lady Liberty!',
                            items: ['liberty_key'],
                            points: 150
                        }
                    ]
                });
            }, 1000);
        });
    }

    visitLocation(location) {
        console.log(`Visiting location: ${location.name}`);

        // Add items to inventory
        if (location.items) {
            location.items.forEach(item => {
                this.addToInventory(item);
            });
        }

        // Add points
        if (location.points) {
            this.addScore(location.points);
        }

        // Update game info
        this.updateGameInfo(`Visited: ${location.name}. ${location.description}`);
    }

    addToInventory(item) {
        this.inventory.push(item);
        this.updateInventoryUI();
        console.log(`Added ${item} to inventory`);
    }

    addScore(points) {
        this.score += points;
        this.updateScoreUI();
        console.log(`Added ${points} points. Total score: ${this.score}`);
    }

    resetGame() {
        this.score = 0;
        this.inventory = [];
        this.gameData = null;

        this.gameMap.clearMap();
        this.updateUI();
        this.updateGameInfo('Game reset! Click "Load Game Data" to start a new adventure.');

        console.log('Game reset');
    }

    updateUI() {
        this.updateScoreUI();
        this.updateInventoryUI();
    }

    updateScoreUI() {
        document.getElementById('score').textContent = `Score: ${this.score}`;
    }

    updateInventoryUI() {
        const inventoryList = document.getElementById('inventoryList');
        inventoryList.innerHTML = '';

        this.inventory.forEach(item => {
            const li = document.createElement('li');
            li.textContent = item.replace('_', ' ').toUpperCase();
            inventoryList.appendChild(li);
        });
    }

    updateGameInfo(message) {
        const gameInfo = document.getElementById('gameInfo');
        const p = document.createElement('p');
        p.textContent = message;
        p.style.color = '#2ecc71';
        p.style.fontWeight = 'bold';

        // Add new message at the top
        gameInfo.insertBefore(p, gameInfo.firstChild);

        // Keep only the last 5 messages
        while (gameInfo.children.length > 5) {
            gameInfo.removeChild(gameInfo.lastChild);
        }
    }
}

// Initialize the game when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.game = new PwshLeafmapGame();
});
