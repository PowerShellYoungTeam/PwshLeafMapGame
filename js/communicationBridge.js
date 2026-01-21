/**
 * Communication Bridge - PowerShell/JavaScript HTTP Bridge Client
 *
 * Provides a simplified wrapper around GameCommandClient for seamless
 * communication between the JavaScript frontend and PowerShell backend.
 *
 * @requires gameCommands.js - GameCommandClient class
 */

class CommunicationBridge {
    /**
     * Create a new CommunicationBridge instance
     * @param {Object} options - Configuration options
     * @param {string} options.bridgeUrl - Bridge server URL (default: http://localhost:8082)
     * @param {number} options.timeout - Request timeout in ms (default: 10000)
     * @param {boolean} options.autoReconnect - Auto-reconnect on connection loss (default: true)
     * @param {number} options.reconnectInterval - Reconnect interval in ms (default: 5000)
     */
    constructor(options = {}) {
        this.bridgeUrl = options.bridgeUrl || 'http://localhost:8082';
        this.timeout = options.timeout || 10000;
        this.autoReconnect = options.autoReconnect !== false;
        this.reconnectInterval = options.reconnectInterval || 5000;

        this.connected = false;
        this.reconnectTimer = null;
        this.eventListeners = new Map();
        this.commandClient = null;

        // Connection state
        this.lastStatus = null;
        this.connectionAttempts = 0;
        this.maxReconnectAttempts = 10;
    }

    /**
     * Connect to the PowerShell bridge server
     * @returns {Promise<boolean>} True if connection successful
     */
    async connect() {
        try {
            console.log(`[Bridge] Connecting to ${this.bridgeUrl}...`);

            const status = await this.getStatus();

            if (status && status.Status === 'ok') {
                this.connected = true;
                this.connectionAttempts = 0;
                this.lastStatus = status;

                // Initialize GameCommandClient if available
                if (typeof GameCommandClient !== 'undefined') {
                    this.commandClient = new GameCommandClient(this.bridgeUrl);
                    await this.commandClient.discoverCommands();
                }

                this._emit('connected', status);
                console.log('[Bridge] Connected successfully');
                return true;
            }

            throw new Error('Invalid status response');
        } catch (error) {
            console.error('[Bridge] Connection failed:', error.message);
            this.connected = false;
            this._emit('connectionFailed', error);

            if (this.autoReconnect) {
                this._scheduleReconnect();
            }

            return false;
        }
    }

    /**
     * Disconnect from the bridge server
     */
    disconnect() {
        this.connected = false;
        this.autoReconnect = false;

        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }

        this._emit('disconnected');
        console.log('[Bridge] Disconnected');
    }

    /**
     * Get bridge server status
     * @returns {Promise<Object>} Server status object
     */
    async getStatus() {
        const response = await this._fetch('/status', {
            method: 'GET'
        });

        return response;
    }

    /**
     * Get list of available commands
     * @param {Object} options - Filter options
     * @param {string} options.module - Filter by module name
     * @param {boolean} options.includeProtected - Include protected commands
     * @returns {Promise<Object>} Commands list
     */
    async getCommands(options = {}) {
        const params = new URLSearchParams();
        if (options.module) params.set('module', options.module);
        if (options.includeProtected) params.set('protected', 'true');

        const queryString = params.toString();
        const url = '/commands' + (queryString ? '?' + queryString : '');

        return this._fetch(url, { method: 'GET' });
    }

    /**
     * Get command documentation
     * @param {string} commandName - Specific command name (optional)
     * @returns {Promise<Object>} Command documentation
     */
    async getCommandDocs(commandName = null) {
        const params = new URLSearchParams();
        if (commandName) params.set('command', commandName);

        const queryString = params.toString();
        const url = '/commands/docs' + (queryString ? '?' + queryString : '');

        return this._fetch(url, { method: 'GET' });
    }

    /**
     * Execute a command on the PowerShell backend
     * @param {string} commandName - Name of the command to execute
     * @param {Object} parameters - Command parameters
     * @returns {Promise<Object>} Command result
     */
    async sendCommand(commandName, parameters = {}) {
        if (!this.connected) {
            throw new Error('Not connected to bridge server');
        }

        const commandId = `cmd_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        const commandData = {
            Id: commandId,
            Command: commandName,
            Parameters: parameters,
            Timestamp: new Date().toISOString(),
            ClientInfo: {
                UserAgent: navigator.userAgent,
                URL: window.location.href
            }
        };

        console.log(`[Bridge] Executing command: ${commandName}`, parameters);

        const result = await this._fetch('/command', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Command-Id': commandId
            },
            body: JSON.stringify(commandData)
        });

        if (result.Success) {
            this._emit('commandSuccess', { commandName, result });
        } else {
            this._emit('commandError', { commandName, error: result.Error });
        }

        return result;
    }

    /**
     * Check if connected to bridge server
     * @returns {boolean} Connection status
     */
    isConnected() {
        return this.connected;
    }

    /**
     * Add event listener
     * @param {string} event - Event name (connected, disconnected, commandSuccess, commandError, connectionFailed)
     * @param {Function} callback - Callback function
     */
    on(event, callback) {
        if (!this.eventListeners.has(event)) {
            this.eventListeners.set(event, []);
        }
        this.eventListeners.get(event).push(callback);
    }

    /**
     * Remove event listener
     * @param {string} event - Event name
     * @param {Function} callback - Callback function to remove
     */
    off(event, callback) {
        if (this.eventListeners.has(event)) {
            const listeners = this.eventListeners.get(event);
            const index = listeners.indexOf(callback);
            if (index > -1) {
                listeners.splice(index, 1);
            }
        }
    }

    /**
     * Emit an event to listeners
     * @private
     */
    _emit(event, data) {
        if (this.eventListeners.has(event)) {
            this.eventListeners.get(event).forEach(callback => {
                try {
                    callback(data);
                } catch (e) {
                    console.error(`[Bridge] Event listener error for '${event}':`, e);
                }
            });
        }
    }

    /**
     * Schedule a reconnection attempt
     * @private
     */
    _scheduleReconnect() {
        if (this.reconnectTimer) {
            return;
        }

        this.connectionAttempts++;

        if (this.connectionAttempts > this.maxReconnectAttempts) {
            console.error('[Bridge] Max reconnection attempts reached');
            this._emit('maxReconnectAttempts');
            return;
        }

        console.log(`[Bridge] Scheduling reconnect attempt ${this.connectionAttempts}/${this.maxReconnectAttempts} in ${this.reconnectInterval}ms`);

        this.reconnectTimer = setTimeout(async () => {
            this.reconnectTimer = null;
            await this.connect();
        }, this.reconnectInterval);
    }

    /**
     * Make a fetch request with timeout
     * @private
     */
    async _fetch(path, options = {}) {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.timeout);

        try {
            const response = await fetch(`${this.bridgeUrl}${path}`, {
                ...options,
                signal: controller.signal
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                throw new Error(errorData.Error || `HTTP ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            clearTimeout(timeoutId);

            if (error.name === 'AbortError') {
                throw new Error('Request timeout');
            }

            // Check if this is a connection error
            if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
                this.connected = false;
                this._emit('connectionLost');

                if (this.autoReconnect) {
                    this._scheduleReconnect();
                }
            }

            throw error;
        }
    }
}

// Create a global singleton instance
const bridge = new CommunicationBridge();

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { CommunicationBridge, bridge };
}
