/**
 * PowerShell Leafmap Game - JavaScript Communication Bridge
 * Client-side bridge for PowerShell-JavaScript communication
 */

class CommunicationBridge {
    constructor(config = {}) {
        this.config = {
            // Communication methods
            fileBasedEnabled: true,
            httpEnabled: true,
            webSocketEnabled: true,
            eventStreamEnabled: true,

            // Server endpoints
            httpBaseUrl: 'http://localhost:8080',
            webSocketUrl: 'ws://localhost:8081/gamebridge',
            eventStreamUrl: 'http://localhost:8080/events',

            // File-based paths (for local file system access)
            commandsPath: './Data/Bridge/Commands',
            responsesPath: './Data/Bridge/Responses',
            eventsPath: './Data/Bridge/Events',

            // Performance settings
            compressionEnabled: true,
            batchingEnabled: true,
            batchSize: 10,
            batchTimeout: 100,
            retryAttempts: 3,
            retryDelay: 1000,

            // Connection settings
            heartbeatInterval: 30000,
            reconnectInterval: 5000,
            maxReconnectAttempts: 10,

            // Debugging
            debugMode: false,
            loggingEnabled: true
        };

        // Merge provided config
        Object.assign(this.config, config);

        this.isInitialized = false;
        this.isConnected = false;
        this.connectionId = null;
        this.eventSource = null;
        this.webSocket = null;

        this.commandQueue = [];
        this.responseHandlers = new Map();
        this.eventHandlers = new Map();
        this.connectionAttempts = 0;

        this.statistics = {
            commandsSent: 0,
            responsesReceived: 0,
            eventsReceived: 0,
            errorCount: 0,
            bytesTransferred: 0,
            averageResponseTime: 0,
            lastActivity: new Date(),
            connectionUptime: 0
        };

        // Initialize event listeners
        this.initializeEventListeners();
    }

    async initialize() {
        try {
            this.log('Initializing Communication Bridge...', 'info');

            if (this.config.httpEnabled) {
                await this.testHttpConnection();
            }

            if (this.config.eventStreamEnabled) {
                this.initializeEventStream();
            }

            if (this.config.webSocketEnabled) {
                await this.initializeWebSocket();
            }

            if (this.config.fileBasedEnabled) {
                this.initializeFileWatcher();
            }

            this.startHeartbeat();
            this.isInitialized = true;
            this.isConnected = true;
            this.statistics.lastActivity = new Date();

            this.log('Communication Bridge initialized successfully', 'success');
            this.emit('bridge:connected', { connectionId: this.connectionId });

            return { success: true, message: 'Bridge initialized' };
        }
        catch (error) {
            this.log(`Bridge initialization failed: ${error.message}`, 'error');
            throw error;
        }
    }

    async testHttpConnection() {
        try {
            const response = await fetch(`${this.config.httpBaseUrl}/status`, {
                method: 'GET',
                headers: { 'Content-Type': 'application/json' }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const status = await response.json();
            this.log(`HTTP connection established. Server status: ${status.Status}`, 'info');
            return status;
        }
        catch (error) {
            throw new Error(`HTTP connection failed: ${error.message}`);
        }
    }

    initializeEventStream() {
        try {
            this.eventSource = new EventSource(this.config.eventStreamUrl);

            this.eventSource.onopen = (event) => {
                this.log('Event stream connected', 'info');
                this.connectionAttempts = 0;
            };

            this.eventSource.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    this.handleEvent(event.type || 'message', data);
                }
                catch (error) {
                    this.log(`Event parsing error: ${error.message}`, 'error');
                }
            };

            this.eventSource.addEventListener('connected', (event) => {
                const data = JSON.parse(event.data);
                this.connectionId = data.connectionId;
                this.log(`Connected with ID: ${this.connectionId}`, 'info');
            });

            this.eventSource.addEventListener('heartbeat', (event) => {
                const data = JSON.parse(event.data);
                this.updateConnectionUptime();
            });

            this.eventSource.onerror = (event) => {
                this.log('Event stream error, attempting reconnection...', 'warning');
                this.handleConnectionError();
            };
        }
        catch (error) {
            this.log(`Event stream initialization failed: ${error.message}`, 'error');
        }
    }

    async initializeWebSocket() {
        return new Promise((resolve, reject) => {
            try {
                this.webSocket = new WebSocket(this.config.webSocketUrl);

                this.webSocket.onopen = (event) => {
                    this.log('WebSocket connected', 'info');
                    this.connectionAttempts = 0;
                    resolve();
                };

                this.webSocket.onmessage = (event) => {
                    try {
                        const data = JSON.parse(event.data);
                        this.handleWebSocketMessage(data);
                    }
                    catch (error) {
                        this.log(`WebSocket message parsing error: ${error.message}`, 'error');
                    }
                };

                this.webSocket.onerror = (event) => {
                    this.log('WebSocket error', 'error');
                    this.handleConnectionError();
                    reject(new Error('WebSocket connection failed'));
                };

                this.webSocket.onclose = (event) => {
                    this.log('WebSocket disconnected', 'warning');
                    this.isConnected = false;
                    this.attemptReconnection();
                };
            }
            catch (error) {
                reject(error);
            }
        });
    }

    initializeFileWatcher() {
        // File-based communication for environments that support it
        if (typeof require !== 'undefined') {
            try {
                const fs = require('fs');
                const path = require('path');

                // Watch for response files
                if (fs.existsSync(this.config.responsesPath)) {
                    fs.watch(this.config.responsesPath, (eventType, filename) => {
                        if (eventType === 'rename' && filename.endsWith('.json')) {
                            this.handleFileResponse(path.join(this.config.responsesPath, filename));
                        }
                    });
                }

                // Watch for event files
                if (fs.existsSync(this.config.eventsPath)) {
                    fs.watch(this.config.eventsPath, (eventType, filename) => {
                        if (eventType === 'rename' && filename.endsWith('.json')) {
                            this.handleFileEvent(path.join(this.config.eventsPath, filename));
                        }
                    });
                }

                this.log('File watcher initialized', 'info');
            }
            catch (error) {
                this.log(`File watcher initialization failed: ${error.message}`, 'warning');
            }
        }
    }

    async sendCommand(command, parameters = {}, options = {}) {
        const commandId = options.commandId || this.generateId();
        const startTime = Date.now();

        const commandData = {
            Id: commandId,
            Command: command,
            Parameters: parameters,
            Timestamp: new Date().toISOString(),
            ClientId: this.connectionId
        };

        try {
            let result;

            // Choose communication method based on availability and preference
            if (options.method === 'file' || (!this.isConnected && this.config.fileBasedEnabled)) {
                result = await this.sendFileCommand(commandData);
            }
            else if (options.method === 'websocket' || (this.webSocket && this.webSocket.readyState === WebSocket.OPEN)) {
                result = await this.sendWebSocketCommand(commandData);
            }
            else if (this.config.httpEnabled) {
                result = await this.sendHttpCommand(commandData);
            }
            else {
                throw new Error('No available communication method');
            }

            // Update statistics
            const responseTime = Date.now() - startTime;
            this.updateStatistics('command', responseTime);

            this.log(`Command executed: ${command} (${responseTime}ms)`, 'info');
            return result;
        }
        catch (error) {
            this.statistics.errorCount++;
            this.log(`Command failed: ${command} - ${error.message}`, 'error');
            throw error;
        }
    }

    async sendHttpCommand(commandData) {
        const response = await fetch(`${this.config.httpBaseUrl}/command`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Command-Id': commandData.Id
            },
            body: JSON.stringify(commandData)
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const result = await response.json();
        this.statistics.bytesTransferred += JSON.stringify(result).length;

        return result;
    }

    async sendWebSocketCommand(commandData) {
        return new Promise((resolve, reject) => {
            if (this.webSocket.readyState !== WebSocket.OPEN) {
                reject(new Error('WebSocket not connected'));
                return;
            }

            // Register response handler
            this.responseHandlers.set(commandData.Id, { resolve, reject, timestamp: Date.now() });

            // Send command
            this.webSocket.send(JSON.stringify(commandData));

            // Timeout handler
            setTimeout(() => {
                if (this.responseHandlers.has(commandData.Id)) {
                    this.responseHandlers.delete(commandData.Id);
                    reject(new Error('Command timeout'));
                }
            }, 30000); // 30 second timeout
        });
    }

    async sendFileCommand(commandData) {
        if (typeof require === 'undefined') {
            throw new Error('File-based communication not available in browser environment');
        }

        const fs = require('fs');
        const path = require('path');

        return new Promise((resolve, reject) => {
            try {
                // Write command file
                const commandFile = path.join(this.config.commandsPath, `${commandData.Id}.json`);
                fs.writeFileSync(commandFile, JSON.stringify(commandData, null, 2));

                // Wait for response file
                const responseFile = path.join(this.config.responsesPath, `${commandData.Id}.json`);
                const checkInterval = setInterval(() => {
                    if (fs.existsSync(responseFile)) {
                        clearInterval(checkInterval);
                        try {
                            const responseData = JSON.parse(fs.readFileSync(responseFile, 'utf8'));
                            fs.unlinkSync(responseFile); // Clean up
                            resolve(responseData);
                        }
                        catch (error) {
                            reject(error);
                        }
                    }
                }, 100);

                // Timeout
                setTimeout(() => {
                    clearInterval(checkInterval);
                    reject(new Error('File command timeout'));
                }, 30000);
            }
            catch (error) {
                reject(error);
            }
        });
    }

    handleWebSocketMessage(data) {
        if (data.CommandId && this.responseHandlers.has(data.CommandId)) {
            const handler = this.responseHandlers.get(data.CommandId);
            this.responseHandlers.delete(data.CommandId);

            if (data.Success) {
                handler.resolve(data);
            } else {
                handler.reject(new Error(data.Error || 'Command failed'));
            }
        }
        else {
            // Handle as event
            this.handleEvent(data.Type || 'websocket:message', data);
        }
    }

    handleEvent(eventType, eventData) {
        this.statistics.eventsReceived++;
        this.statistics.lastActivity = new Date();

        // Emit to registered handlers
        this.emit(eventType, eventData);

        // Handle specific events
        switch (eventType) {
            case 'state.saved':
                this.emit('game:saved', eventData);
                break;
            case 'state.loaded':
                this.emit('game:loaded', eventData);
                break;
            case 'state.updated':
                this.emit('game:stateChanged', eventData);
                break;
        }

        this.log(`Event received: ${eventType}`, 'info');
    }

    handleFileResponse(filePath) {
        if (typeof require === 'undefined') return;

        try {
            const fs = require('fs');
            const responseData = JSON.parse(fs.readFileSync(filePath, 'utf8'));

            if (this.responseHandlers.has(responseData.CommandId)) {
                const handler = this.responseHandlers.get(responseData.CommandId);
                this.responseHandlers.delete(responseData.CommandId);

                if (responseData.Success) {
                    handler.resolve(responseData);
                } else {
                    handler.reject(new Error(responseData.Error || 'Command failed'));
                }
            }

            // Clean up file
            fs.unlinkSync(filePath);
        }
        catch (error) {
            this.log(`File response error: ${error.message}`, 'error');
        }
    }

    handleFileEvent(filePath) {
        if (typeof require === 'undefined') return;

        try {
            const fs = require('fs');
            const eventData = JSON.parse(fs.readFileSync(filePath, 'utf8'));

            this.handleEvent(eventData.Type, eventData.Data);

            // Clean up file
            fs.unlinkSync(filePath);
        }
        catch (error) {
            this.log(`File event error: ${error.message}`, 'error');
        }
    }

    handleConnectionError() {
        this.isConnected = false;
        this.statistics.errorCount++;
        this.emit('bridge:disconnected', { reason: 'Connection error' });

        if (this.connectionAttempts < this.config.maxReconnectAttempts) {
            this.attemptReconnection();
        } else {
            this.log('Max reconnection attempts reached', 'error');
            this.emit('bridge:failed', { reason: 'Max reconnection attempts reached' });
        }
    }

    async attemptReconnection() {
        this.connectionAttempts++;
        this.log(`Attempting reconnection (${this.connectionAttempts}/${this.config.maxReconnectAttempts})...`, 'warning');

        setTimeout(() => {
            this.initialize().catch(error => {
                this.log(`Reconnection failed: ${error.message}`, 'error');
            });
        }, this.config.reconnectInterval);
    }

    startHeartbeat() {
        setInterval(() => {
            if (this.isConnected) {
                this.sendCommand('Heartbeat', {}, { method: 'http' })
                    .catch(error => {
                        this.log(`Heartbeat failed: ${error.message}`, 'warning');
                        this.handleConnectionError();
                    });
            }
        }, this.config.heartbeatInterval);
    }

    updateConnectionUptime() {
        if (this.statistics.connectionStartTime) {
            this.statistics.connectionUptime = Date.now() - this.statistics.connectionStartTime;
        } else {
            this.statistics.connectionStartTime = Date.now();
        }
    }

    updateStatistics(operation, responseTime = 0) {
        switch (operation) {
            case 'command':
                this.statistics.commandsSent++;
                this.statistics.responsesReceived++;
                this.statistics.averageResponseTime = (
                    (this.statistics.averageResponseTime * (this.statistics.responsesReceived - 1)) + responseTime
                ) / this.statistics.responsesReceived;
                break;
        }

        this.statistics.lastActivity = new Date();
    }

    // Event system
    initializeEventListeners() {
        this.eventListeners = new Map();
    }

    on(eventType, handler) {
        if (!this.eventListeners.has(eventType)) {
            this.eventListeners.set(eventType, []);
        }
        this.eventListeners.get(eventType).push(handler);
    }

    off(eventType, handler) {
        if (this.eventListeners.has(eventType)) {
            const handlers = this.eventListeners.get(eventType);
            const index = handlers.indexOf(handler);
            if (index > -1) {
                handlers.splice(index, 1);
            }
        }
    }

    emit(eventType, data) {
        if (this.eventListeners.has(eventType)) {
            this.eventListeners.get(eventType).forEach(handler => {
                try {
                    handler(data);
                }
                catch (error) {
                    this.log(`Event handler error: ${error.message}`, 'error');
                }
            });
        }
    }

    // Utility methods
    generateId() {
        return 'cmd_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now();
    }

    log(message, level = 'info') {
        if (this.config.loggingEnabled) {
            const timestamp = new Date().toISOString();
            const logMessage = `[${timestamp}] [${level.toUpperCase()}] ${message}`;

            if (this.config.debugMode) {
                switch (level) {
                    case 'error':
                        console.error(logMessage);
                        break;
                    case 'warning':
                        console.warn(logMessage);
                        break;
                    case 'success':
                        console.log(`%c${logMessage}`, 'color: green');
                        break;
                    default:
                        console.log(logMessage);
                }
            }
        }
    }

    // High-level API methods
    async getGameState() {
        return await this.sendCommand('GetGameState');
    }

    async updateGameState(entityId, property, value) {
        return await this.sendCommand('UpdateGameState', {
            EntityId: entityId,
            Property: property,
            Value: value
        });
    }

    async saveGame(saveName, additionalData = {}) {
        return await this.sendCommand('SaveGame', {
            SaveName: saveName,
            AdditionalData: additionalData
        });
    }

    async loadGame(saveName) {
        return await this.sendCommand('LoadGame', {
            SaveName: saveName
        });
    }

    async getStatistics() {
        return await this.sendCommand('GetStatistics');
    }

    getClientStatistics() {
        return {
            ...this.statistics,
            isConnected: this.isConnected,
            connectionId: this.connectionId,
            configuration: this.config
        };
    }

    disconnect() {
        if (this.eventSource) {
            this.eventSource.close();
        }

        if (this.webSocket) {
            this.webSocket.close();
        }

        this.isConnected = false;
        this.isInitialized = false;

        this.log('Communication Bridge disconnected', 'info');
        this.emit('bridge:disconnected', { reason: 'Manual disconnect' });
    }
}

// Export for different environments
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CommunicationBridge;
} else {
    window.CommunicationBridge = CommunicationBridge;
}
