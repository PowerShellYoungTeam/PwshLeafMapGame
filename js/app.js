// Main application initialization
class PwshLeafmapGame {
    constructor() {
        this.score = 0;
        this.inventory = [];
        this.gameData = null;
        this.eventManager = null;
        this.gameEventHandlers = null;

        this.init();
    }

    init() {
        // Initialize event system first
        this.eventManager = new EventManager();
        this.gameEventHandlers = new GameEventHandlers(this.eventManager, this);

        // Initialize event listeners
        document.getElementById('loadData').addEventListener('click', () => this.loadGameData());
        document.getElementById('resetGame').addEventListener('click', () => this.resetGame());

        // Initialize the map
        this.gameMap = new GameMap('map', this);

        // Register for PowerShell events
        this.eventManager.register('powershell.commandCompleted', (data) => {
            this.handlePowerShellResponse(data);
        });

        // Load initial game state
        this.updateUI();

        // Emit initialization event
        this.eventManager.emit('system.initialized', {
            timestamp: new Date().toISOString(),
            version: '1.0.0'
        });

        console.log('PowerShell Leafmap Game initialized with Event System!');
    }

    async loadGameData() {
        try {
            // Emit event to PowerShell to generate/load game data
            console.log('Requesting game data from PowerShell...');

            this.eventManager.emit('powershell.generateLocations', {
                city: 'New York',
                locationCount: 10
            });

            this.updateGameInfo('Requesting game data from PowerShell...');
        } catch (error) {
            console.error('Error loading game data:', error);
            this.eventManager.emit('system.error', {
                message: error.message,
                context: 'loadGameData'
            });
            this.updateGameInfo('Error loading game data');
        }
    }

    handlePowerShellResponse(data) {
        console.log('Received PowerShell response:', data);

        if (data.commandType === 'generateLocations' && data.success) {
            this.gameData = data.result;

            if (this.gameData && this.gameData.locations) {
                // Update map with new data
                this.gameMap.loadLocations(this.gameData.locations);
                this.updateGameInfo('Game data loaded from PowerShell successfully!');

                // Emit data loaded event
                this.eventManager.emit('system.dataLoaded', {
                    locations: this.gameData.locations,
                    source: 'powershell'
                });
            }
        } else if (!data.success) {
            this.updateGameInfo(`PowerShell error: ${data.error || 'Unknown error'}`);
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

        // Emit location visit event
        this.eventManager.emit('location.visited', {
            location: location,
            playerId: 'player1', // This would be dynamic in a real game
            timestamp: new Date().toISOString()
        });

        // Add items to inventory
        if (location.items) {
            const items = Array.isArray(location.items) ? location.items : [location.items];
            items.forEach(item => {
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

        // Emit inventory change event
        this.eventManager.emit('player.inventoryChanged', {
            action: 'added',
            item: item,
            inventory: [...this.inventory]
        });

        console.log(`Added ${item} to inventory`);
    }

    addScore(points) {
        const oldScore = this.score;
        this.score += points;
        this.updateScoreUI();

        // Emit score change event
        this.eventManager.emit('player.scoreChanged', {
            oldScore: oldScore,
            newScore: this.score,
            pointsAdded: points
        });

        console.log(`Added ${points} points. Total score: ${this.score}`);
    }

    resetGame() {
        this.score = 0;
        this.inventory = [];
        this.gameData = null;

        this.gameMap.clearMap();
        this.updateUI();
        this.updateGameInfo('Game reset! Click "Load Game Data" to start a new adventure.');

        // Emit reset event
        this.eventManager.emit('game.reset', {
            timestamp: new Date().toISOString()
        });

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
