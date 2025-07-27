// Event System for PowerShell Leafmap RPG
// Provides centralized event management between PowerShell backend and JavaScript frontend

class EventManager {
    constructor() {
        this.eventHandlers = new Map();
        this.eventQueue = [];
        this.isProcessing = false;
        this.eventLog = [];
        this.maxLogSize = 1000;

        // PowerShell communication settings
        this.powershellEventFile = 'events.json';
        this.powershellCommandFile = 'commands.json';
        this.pollInterval = 1000; // Poll for PowerShell events every second

        this.init();
    }

    init() {
        console.log('Initializing Event Manager...');

        // Start polling for PowerShell events
        this.startPowerShellPolling();

        // Set up error handling
        window.addEventListener('error', (error) => {
            this.emit('system.error', {
                message: error.message,
                filename: error.filename,
                lineno: error.lineno,
                timestamp: new Date().toISOString()
            });
        });

        console.log('Event Manager initialized');
    }

    /**
     * Register an event handler
     * @param {string} eventType - The event type to listen for
     * @param {function} handler - The function to call when event occurs
     * @param {object} options - Additional options (priority, once, etc.)
     */
    register(eventType, handler, options = {}) {
        if (!this.eventHandlers.has(eventType)) {
            this.eventHandlers.set(eventType, []);
        }

        const handlerInfo = {
            handler,
            priority: options.priority || 0,
            once: options.once || false,
            id: this.generateHandlerId()
        };

        const handlers = this.eventHandlers.get(eventType);
        handlers.push(handlerInfo);

        // Sort by priority (higher priority first)
        handlers.sort((a, b) => b.priority - a.priority);

        console.log(`Registered handler for event: ${eventType}`);
        return handlerInfo.id;
    }

    /**
     * Unregister an event handler
     * @param {string} eventType - The event type
     * @param {string} handlerId - The handler ID returned from register()
     */
    unregister(eventType, handlerId) {
        if (!this.eventHandlers.has(eventType)) {
            return false;
        }

        const handlers = this.eventHandlers.get(eventType);
        const index = handlers.findIndex(h => h.id === handlerId);

        if (index !== -1) {
            handlers.splice(index, 1);
            console.log(`Unregistered handler ${handlerId} for event: ${eventType}`);
            return true;
        }

        return false;
    }

    /**
     * Emit an event
     * @param {string} eventType - The event type
     * @param {object} data - Event data
     * @param {object} options - Additional options (async, batch, etc.)
     */
    emit(eventType, data = {}, options = {}) {
        const event = {
            type: eventType,
            data,
            timestamp: new Date().toISOString(),
            id: this.generateEventId(),
            source: options.source || 'javascript'
        };

        // Add to event log
        this.addToEventLog(event);

        if (options.async) {
            this.queueEvent(event);
        } else {
            this.processEvent(event);
        }

        // If this is a PowerShell command, queue it for PowerShell processing
        if (eventType.startsWith('powershell.')) {
            this.queuePowerShellCommand(event);
        }

        return event.id;
    }

    /**
     * Process an event immediately
     * @param {object} event - The event to process
     */
    processEvent(event) {
        const handlers = this.eventHandlers.get(event.type) || [];

        for (const handlerInfo of handlers) {
            try {
                handlerInfo.handler(event.data, event);

                // Remove if it's a one-time handler
                if (handlerInfo.once) {
                    this.unregister(event.type, handlerInfo.id);
                }
            } catch (error) {
                console.error(`Error processing event ${event.type}:`, error);
                this.emit('system.error', {
                    message: error.message,
                    eventType: event.type,
                    handlerId: handlerInfo.id
                });
            }
        }
    }

    /**
     * Queue an event for asynchronous processing
     * @param {object} event - The event to queue
     */
    queueEvent(event) {
        this.eventQueue.push(event);
        this.processEventQueue();
    }

    /**
     * Process queued events
     */
    async processEventQueue() {
        if (this.isProcessing || this.eventQueue.length === 0) {
            return;
        }

        this.isProcessing = true;

        while (this.eventQueue.length > 0) {
            const event = this.eventQueue.shift();
            this.processEvent(event);

            // Small delay to prevent blocking
            await new Promise(resolve => setTimeout(resolve, 1));
        }

        this.isProcessing = false;
    }

    /**
     * Queue a command for PowerShell processing
     * @param {object} event - The event containing the command
     */
    queuePowerShellCommand(event) {
        const command = {
            id: event.id,
            type: event.type,
            data: event.data,
            timestamp: event.timestamp,
            status: 'pending'
        };

        // In a real implementation, this would write to a file or send via HTTP
        console.log('Queuing PowerShell command:', command);

        // Simulate saving to file
        this.savePowerShellCommand(command);
    }

    /**
     * Start polling for PowerShell events
     */
    startPowerShellPolling() {
        setInterval(() => {
            this.checkPowerShellEvents();
        }, this.pollInterval);
    }

    /**
     * Check for events from PowerShell
     */
    async checkPowerShellEvents() {
        try {
            // In a real implementation, this would read from a file or HTTP endpoint
            const events = await this.loadPowerShellEvents();

            for (const event of events) {
                // Process events from PowerShell
                this.emit(event.type, event.data, { source: 'powershell' });
            }
        } catch (error) {
            // Silently handle errors (file might not exist yet)
        }
    }

    /**
     * Save command for PowerShell processing (mock implementation)
     * @param {object} command - The command to save
     */
    savePowerShellCommand(command) {
        // In a real implementation, this would write to a JSON file
        // that PowerShell scripts could read and process
        const commands = this.loadFromStorage('powershell_commands') || [];
        commands.push(command);
        this.saveToStorage('powershell_commands', commands);
    }

    /**
     * Load PowerShell events (mock implementation)
     */
    async loadPowerShellEvents() {
        // In a real implementation, this would read from a JSON file
        // created by PowerShell scripts
        const events = this.loadFromStorage('powershell_events') || [];

        if (events.length > 0) {
            // Clear processed events
            this.saveToStorage('powershell_events', []);
        }

        return events;
    }

    /**
     * Add event to log with size management
     * @param {object} event - The event to log
     */
    addToEventLog(event) {
        this.eventLog.push(event);

        // Trim log if it gets too large
        if (this.eventLog.length > this.maxLogSize) {
            this.eventLog = this.eventLog.slice(-this.maxLogSize);
        }
    }

    /**
     * Get event log for debugging
     * @param {string} eventType - Optional filter by event type
     * @param {number} limit - Optional limit on number of events
     */
    getEventLog(eventType = null, limit = 100) {
        let log = this.eventLog;

        if (eventType) {
            log = log.filter(event => event.type === eventType);
        }

        return log.slice(-limit);
    }

    /**
     * Generate unique event ID
     */
    generateEventId() {
        return `evt_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    /**
     * Generate unique handler ID
     */
    generateHandlerId() {
        return `handler_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    /**
     * Save data to localStorage
     * @param {string} key - Storage key
     * @param {any} data - Data to save
     */
    saveToStorage(key, data) {
        try {
            localStorage.setItem(key, JSON.stringify(data));
        } catch (error) {
            console.error('Failed to save to storage:', error);
        }
    }

    /**
     * Load data from localStorage
     * @param {string} key - Storage key
     */
    loadFromStorage(key) {
        try {
            const data = localStorage.getItem(key);
            return data ? JSON.parse(data) : null;
        } catch (error) {
            console.error('Failed to load from storage:', error);
            return null;
        }
    }

    /**
     * Clear all event handlers and queues
     */
    clearAll() {
        this.eventHandlers.clear();
        this.eventQueue = [];
        this.eventLog = [];
        console.log('Event Manager cleared');
    }
}

// Game-specific event handlers and utilities
class GameEventHandlers {
    constructor(eventManager, gameInstance) {
        this.eventManager = eventManager;
        this.game = gameInstance;
        this.registerDefaultHandlers();
    }

    registerDefaultHandlers() {
        // Player events
        this.eventManager.register('player.levelUp', (data) => {
            this.handlePlayerLevelUp(data);
        });

        this.eventManager.register('player.inventoryChanged', (data) => {
            this.handleInventoryChange(data);
        });

        // Location events
        this.eventManager.register('location.visited', (data) => {
            this.handleLocationVisit(data);
        });

        this.eventManager.register('location.discovered', (data) => {
            this.handleLocationDiscovery(data);
        });

        // System events
        this.eventManager.register('system.dataLoaded', (data) => {
            this.handleDataLoaded(data);
        });

        this.eventManager.register('system.error', (data) => {
            this.handleSystemError(data);
        });

        // PowerShell events
        this.eventManager.register('powershell.commandCompleted', (data) => {
            this.handlePowerShellCommand(data);
        });

        console.log('Default game event handlers registered');
    }

    handlePlayerLevelUp(data) {
        console.log(`Player leveled up to level ${data.newLevel}!`);

        // Update UI
        if (this.game && this.game.updateGameInfo) {
            this.game.updateGameInfo(`🎉 Level Up! You are now level ${data.newLevel}!`);
        }

        // Play sound effect
        this.eventManager.emit('ui.playSound', { sound: 'levelUp' });

        // Show level up notification
        this.eventManager.emit('ui.showNotification', {
            type: 'success',
            title: 'Level Up!',
            message: `Congratulations! You reached level ${data.newLevel}!`
        });
    }

    handleInventoryChange(data) {
        console.log('Inventory changed:', data);

        if (this.game && this.game.updateInventoryUI) {
            this.game.updateInventoryUI();
        }

        // If item was added, show notification
        if (data.action === 'added') {
            this.eventManager.emit('ui.showNotification', {
                type: 'info',
                title: 'Item Added',
                message: `${data.item} added to inventory`
            });
        }
    }

    handleLocationVisit(data) {
        console.log('Location visited:', data.location.name);

        // Update game state
        if (this.game) {
            this.game.visitLocation(data.location);
        }

        // Trigger PowerShell location processing
        this.eventManager.emit('powershell.processLocation', {
            locationId: data.location.id,
            playerId: data.playerId,
            timestamp: new Date().toISOString()
        });
    }

    handleLocationDiscovery(data) {
        console.log('New location discovered:', data.location.name);

        this.eventManager.emit('ui.showNotification', {
            type: 'discovery',
            title: 'Location Discovered!',
            message: `You discovered: ${data.location.name}`
        });
    }

    handleDataLoaded(data) {
        console.log('Game data loaded from PowerShell');

        if (this.game && this.game.gameMap && data.locations) {
            this.game.gameMap.loadLocations(data.locations);
            this.game.updateGameInfo('Game data loaded from PowerShell scripts!');
        }
    }

    handleSystemError(data) {
        console.error('System error:', data);

        if (this.game && this.game.updateGameInfo) {
            this.game.updateGameInfo(`❌ Error: ${data.message}`);
        }
    }

    handlePowerShellCommand(data) {
        console.log('PowerShell command completed:', data);

        // Process results based on command type
        switch (data.commandType) {
            case 'generateLocations':
                this.eventManager.emit('system.dataLoaded', data.result);
                break;
            case 'saveProgress':
                this.eventManager.emit('ui.showNotification', {
                    type: 'success',
                    title: 'Game Saved',
                    message: 'Your progress has been saved!'
                });
                break;
            case 'calculateStats':
                this.eventManager.emit('ui.updateStats', data.result);
                break;
        }
    }
}

// Export for use in other modules
window.EventManager = EventManager;
window.GameEventHandlers = GameEventHandlers;
