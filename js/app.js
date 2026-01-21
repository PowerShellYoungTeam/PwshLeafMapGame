// Main application initialization
class PwshLeafmapGame {
    constructor() {
        this.score = 0;
        this.inventory = [];
        this.gameData = null;
        this.eventManager = null;
        this.gameEventHandlers = null;
        this.travelMode = 'foot';
        this.communicationBridge = null;

        this.init();
    }

    init() {
        // Initialize event system first
        this.eventManager = new EventManager();
        this.gameEventHandlers = new GameEventHandlers(this.eventManager, this);

        // Initialize communication bridge
        this.initCommunicationBridge();

        // Initialize event listeners
        document.getElementById('loadData').addEventListener('click', () => this.loadGameData());
        document.getElementById('resetGame').addEventListener('click', () => this.resetGame());

        // Center on player button
        const centerBtn = document.getElementById('centerPlayer');
        if (centerBtn) {
            centerBtn.addEventListener('click', () => this.centerOnPlayer());
        }

        // Travel mode selector
        const travelModeSelect = document.getElementById('travelMode');
        if (travelModeSelect) {
            travelModeSelect.addEventListener('change', (e) => this.setTravelMode(e.target.value));
        }

        // Initialize the map
        this.gameMap = new GameMap('map', this);

        // Register for PowerShell events
        this.eventManager.register('powershell.commandCompleted', (data) => {
            this.handlePowerShellResponse(data);
        });

        // Register for movement events
        this.eventManager.register('movement.started', (data) => {
            this.updateStatus('Moving...');
            this.updatePathInfo(data);
        });

        this.eventManager.register('movement.completed', (data) => {
            this.updateStatus('Ready');
            this.updatePositionDisplay(data.position);
            // Send to PowerShell bridge
            this.sendMovementEvent('movement.completed', data);
        });

        // Load initial game state
        this.updateUI();

        // Emit initialization event
        this.eventManager.emit('system.initialized', {
            timestamp: new Date().toISOString(),
            version: '1.0.0'
        });

        console.log('PowerShell Leafmap Game initialized with Event System!');

        // Auto-load gamedata.json if it exists
        this.autoLoadGameData();
    }

    initCommunicationBridge() {
        // Initialize the communication bridge if available
        if (typeof CommunicationBridge !== 'undefined') {
            this.communicationBridge = new CommunicationBridge({
                bridgeUrl: 'http://localhost:8082',
                autoReconnect: true
            });

            this.communicationBridge.on('connected', () => {
                console.log('Connected to PowerShell bridge');
                this.updateStatus('Bridge Connected');
            });

            this.communicationBridge.on('disconnected', () => {
                console.log('Disconnected from PowerShell bridge');
            });

            // Try to connect
            this.communicationBridge.connect().catch(err => {
                console.log('Bridge not available (standalone mode):', err.message);
            });
        }
    }

    sendMovementEvent(eventType, data) {
        if (this.communicationBridge && this.communicationBridge.isConnected()) {
            this.communicationBridge.sendCommand('movement.event', {
                type: eventType,
                ...data
            }).catch(err => console.log('Bridge send failed:', err.message));
        }
    }

    setTravelMode(mode) {
        this.travelMode = mode;
        if (this.gameMap) {
            this.gameMap.setTravelMode(mode);
        }

        const modeNames = {
            'foot': '🚶 On Foot',
            'car': '🚗 Car',
            'motorcycle': '🏍️ Motorcycle',
            'van': '🚐 Van',
            'aerial': '🚁 Aerial'
        };

        const modeDisplay = document.getElementById('modeDisplay');
        if (modeDisplay) {
            modeDisplay.textContent = modeNames[mode] || mode;
        }

        console.log(`Travel mode set to: ${mode}`);
    }

    centerOnPlayer() {
        if (this.gameMap && this.gameMap.playerPosition) {
            this.gameMap.map.setView(this.gameMap.playerPosition, this.gameMap.map.getZoom());
        }
    }

    updateStatus(status) {
        const statusDisplay = document.getElementById('statusDisplay');
        if (statusDisplay) {
            statusDisplay.textContent = status;
        }
    }

    updatePositionDisplay(position) {
        const posDisplay = document.getElementById('positionDisplay');
        if (posDisplay && position) {
            const lat = position.lat.toFixed(4);
            const lng = position.lng.toFixed(4);
            posDisplay.textContent = `${lat}, ${lng}`;
        }
    }

    updatePathInfo(data) {
        const pathPanel = document.getElementById('pathInfoPanel');
        const pathDisplay = document.getElementById('pathInfoDisplay');

        if (pathPanel && pathDisplay && data) {
            pathPanel.style.display = 'flex';
            const distKm = (data.distance / 1000).toFixed(2);
            const durMin = Math.round(data.duration / 60);
            pathDisplay.textContent = `${distKm}km • ~${durMin}min • ${data.travelMode}`;
        }
    }

    hidePathInfo() {
        const pathPanel = document.getElementById('pathInfoPanel');
        if (pathPanel) {
            pathPanel.style.display = 'none';
        }
    }

    async autoLoadGameData() {
        try {
            console.log('Attempting to load gamedata.json...');
            const response = await fetch('gamedata.json');
            if (response.ok) {
                const data = await response.json();
                console.log('Game data received:', data);
                if (data && data.locations && data.locations.length > 0) {
                    this.gameData = data;
                    console.log(`Loading ${data.locations.length} locations onto map...`);
                    this.gameMap.loadLocations(data.locations);
                    this.updateGameInfo(`🎮 Game ready! ${data.locations.length} locations in ${data.city}. Click markers to explore!`);
                    console.log('✓ Game data loaded successfully');

                    this.eventManager.emit('system.dataLoaded', {
                        locations: data.locations,
                        source: 'file'
                    });
                } else {
                    console.warn('Game data loaded but no locations found');
                    this.updateGameInfo('No locations found in game data');
                }
            } else {
                console.log('No gamedata.json found (HTTP', response.status, ')');
                this.updateGameInfo('Click "Load Game Data" to start your adventure!');
            }
        } catch (error) {
            console.error('Error auto-loading game data:', error);
            this.updateGameInfo('Click "Load Game Data" to start!');
        }
    }

    async loadGameData() {
        try {
            console.log('Loading game data...');
            this.updateGameInfo('Loading game data...');

            // First try to fetch from the local gamedata.json file
            const response = await fetch('gamedata.json');
            if (response.ok) {
                const data = await response.json();
                console.log('Game data received:', data);
                if (data && data.locations && data.locations.length > 0) {
                    this.gameData = data;
                    console.log(`Loading ${data.locations.length} locations onto map...`);
                    this.gameMap.loadLocations(data.locations);
                    this.updateGameInfo(`🎮 Game loaded! ${data.locations.length} locations in ${data.city || 'the city'}. Click markers to explore!`);
                    console.log('✓ Game data loaded successfully');

                    this.eventManager.emit('system.dataLoaded', {
                        locations: data.locations,
                        source: 'file'
                    });
                } else {
                    console.warn('Game data loaded but no locations found');
                    this.updateGameInfo('No locations found in game data. Try regenerating.');
                }
            } else {
                console.warn('gamedata.json not found, attempting PowerShell bridge...');
                // Fall back to PowerShell bridge if file not found
                this.eventManager.emit('powershell.generateLocations', {
                    city: 'New York',
                    locationCount: 10
                });
                this.updateGameInfo('Requesting game data from PowerShell...');
            }
        } catch (error) {
            console.error('Error loading game data:', error);
            this.eventManager.emit('system.error', {
                message: error.message,
                context: 'loadGameData'
            });
            this.updateGameInfo('Error loading game data: ' + error.message);
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
        try {
            // Check if player is within visit range (100m)
            if (this.map && !this.map.isWithinVisitRange(location)) {
                const distance = this.map.getDistanceToLocation(location);
                const distanceText = distance < 1000
                    ? `${Math.round(distance)}m`
                    : `${(distance / 1000).toFixed(1)}km`;
                this.updateGameInfo(`❌ Too far to visit ${location.name} (${distanceText} away). Get within 100m first!`);
                console.log(`Cannot visit ${location.name} - too far (${distanceText})`);
                return;
            }

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
            this.updateGameInfo(`✅ Visited: ${location.name}. ${location.description}`);

            console.log('✓ Location visit completed successfully');
        } catch (error) {
            console.error('Error visiting location:', error);
            this.updateGameInfo(`Error: ${error.message}`);
        }
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
