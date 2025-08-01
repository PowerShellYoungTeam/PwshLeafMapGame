/**
 * PowerShell Leafmap Game - Command System JavaScript Client
 * Advanced client library for interacting with the command registry and bridge
 */
/**
 * The `GameCommandClient` class provides an interface for interacting with the command registry
 * and communication bridge in the PowerShell Leafmap Game. It manages command execution, 
 * event handling, and connection status with the bridge.
 *
 * Main Features:
 * - Manages connection to the communication bridge.
 * - Discovers and caches available commands from the registry.
 * - Tracks command execution statistics.
 * - Handles reconnection logic and event listeners.
 *
 * Properties:
 * - `bridgeUrl` (string): The URL of the communication bridge.
 * - `commandCache` (Map): Cache of discovered commands.
 * - `documentationCache` (Map): Cache of command documentation.
 * - `stats` (object): Tracks command execution statistics.
 *
 * Example Usage:
 * ```
 * const client = new GameCommandClient('http://localhost:8082');
 * await client.checkBridgeConnection();
 * const commands = await client.discoverCommands();
 * console.log('Available commands:', commands);
 * ```
 */
class GameCommandClient {
    constructor(bridgeUrl = 'http://localhost:8082') {
        this.bridgeUrl = bridgeUrl.replace(/\/$/, ''); // Remove trailing slash
        this.commandCache = new Map();
        this.documentationCache = new Map();
        this.eventListeners = new Map();
        this.reconnectionAttempts = 0;
        this.maxReconnectionAttempts = 10;
        this.reconnectionDelay = 1000;
        this.isConnected = false;

        // Command execution statistics
        this.stats = {
            commandsExecuted: 0,
            successfulCommands: 0,
            failedCommands: 0,
            averageResponseTime: 0,
            lastCommandTime: null
        };

        this.initializeEventHandlers();
    }

    /**
     * Initialize event handlers for connection management
     */
    initializeEventHandlers() {
        // Listen for bridge events if available
        this.addEventListener('connected', () => {
            console.log('🌉 Connected to Communication Bridge');
            this.isConnected = true;
            this.reconnectionAttempts = 0;
        });

        this.addEventListener('disconnected', () => {
            console.log('❌ Disconnected from Communication Bridge');
            this.isConnected = false;
            this.handleReconnection();
        });

        this.addEventListener('command.executed', (data) => {
            this.updateStatistics(data.ExecutionTime, data.Success);
        });
    }

    /**
     * Check if the bridge is available
     */
    async checkBridgeConnection() {
        try {
            const response = await fetch(`${this.bridgeUrl}/status`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            if (response.ok) {
                const status = await response.json();
                this.isConnected = true;
                return status;
            } else {
                this.isConnected = false;
                return null;
            }
        } catch (error) {
            this.isConnected = false;
            console.warn('Bridge connection check failed:', error.message);
            return null;
        }
    }

    /**
     * Discover available commands from the registry
     */
    async discoverCommands(options = {}) {
        const {
            module = null,
            includeProtected = false,
            includeAdmin = false,
            forceRefresh = false
        } = options;

        const cacheKey = `commands_${module || 'all'}_${includeProtected}_${includeAdmin}`;

        if (!forceRefresh && this.commandCache.has(cacheKey)) {
            return this.commandCache.get(cacheKey);
        }

        try {
            const queryParams = new URLSearchParams();
            if (module) queryParams.append('module', module);
            if (includeProtected) queryParams.append('includeProtected', 'true');
            if (includeAdmin) queryParams.append('includeAdmin', 'true');

            const response = await fetch(`${this.bridgeUrl}/commands?${queryParams}`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`Failed to discover commands: ${response.status} ${response.statusText}`);
            }

            const discovery = await response.json();
            this.commandCache.set(cacheKey, discovery);

            console.log(`📋 Discovered ${discovery.Commands?.length || 0} commands from ${discovery.Modules?.length || 0} modules`);

            return discovery;
        } catch (error) {
            console.error('Command discovery failed:', error);

            // Return cached data if available
            if (this.commandCache.has(cacheKey)) {
                console.warn('Using cached command data due to discovery failure');
                return this.commandCache.get(cacheKey);
            }

            // Return fallback data
            return {
                RegistryAvailable: false,
                Commands: ['GetGameState', 'UpdateGameState', 'SaveGame', 'LoadGame', 'GetStatistics'],
                Modules: ['legacy'],
                Categories: ['Core'],
                Error: error.message
            };
        }
    }

    /**
     * Get detailed documentation for commands
     */
    async getCommandDocumentation(commandName = null, module = null) {
        const cacheKey = `docs_${commandName || 'all'}_${module || 'all'}`;

        if (this.documentationCache.has(cacheKey)) {
            return this.documentationCache.get(cacheKey);
        }

        try {
            const queryParams = new URLSearchParams();
            if (commandName) queryParams.append('command', commandName);
            if (module) queryParams.append('module', module);

            const response = await fetch(`${this.bridgeUrl}/commands/docs?${queryParams}`, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`Failed to get documentation: ${response.status} ${response.statusText}`);
            }

            const documentation = await response.json();
            this.documentationCache.set(cacheKey, documentation);

            return documentation;
        } catch (error) {
            console.error('Documentation retrieval failed:', error);
            return {
                Generated: false,
                Error: error.message,
                Data: {}
            };
        }
    }

    /**
     * Execute a command with advanced options
     */
    async executeCommand(commandName, parameters = {}, options = {}) {
        const {
            timeout = 30000,
            retries = 0,
            onProgress = null,
            validateParameters = true,
            clientInfo = {}
        } = options;

        const startTime = Date.now();
        const commandId = this.generateCommandId();

        try {
            // Validate parameters if enabled and documentation is available
            if (validateParameters) {
                const validationResult = await this.validateCommandParameters(commandName, parameters);
                if (!validationResult.isValid) {
                    throw new Error(`Parameter validation failed: ${validationResult.errors.join(', ')}`);
                }
            }

            const commandData = {
                Id: commandId,
                Command: commandName,
                Parameters: parameters,
                Timestamp: new Date().toISOString(),
                ClientInfo: {
                    UserAgent: navigator.userAgent,
                    URL: window.location.href,
                    ...clientInfo
                }
            };

            // Execute with timeout and retry logic
            const result = await this.executeWithRetry(commandData, timeout, retries);

            const executionTime = Date.now() - startTime;
            this.updateStatistics(executionTime, result.Success);

            if (onProgress) {
                onProgress({
                    phase: 'completed',
                    result: result,
                    executionTime: executionTime
                });
            }

            return result;
        } catch (error) {
            const executionTime = Date.now() - startTime;
            this.updateStatistics(executionTime, false);

            console.error(`Command execution failed: ${commandName}`, error);
            throw error;
        }
    }

    /**
     * Execute command with retry logic
     */
    async executeWithRetry(commandData, timeout, retries) {
        let lastError;

        for (let attempt = 0; attempt <= retries; attempt++) {
            try {
                const controller = new AbortController();
                const timeoutId = setTimeout(() => controller.abort(), timeout);

                const response = await fetch(`${this.bridgeUrl}/command`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Command-Id': commandData.Id
                    },
                    body: JSON.stringify(commandData),
                    signal: controller.signal
                });

                clearTimeout(timeoutId);

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }

                const result = await response.json();

                if (!result.Success && attempt < retries) {
                    console.warn(`Command attempt ${attempt + 1} failed: ${result.Error}. Retrying...`);
                    await this.delay(1000 * (attempt + 1)); // Exponential backoff
                    continue;
                }

                return result;
            } catch (error) {
                lastError = error;

                if (attempt < retries) {
                    console.warn(`Command attempt ${attempt + 1} failed: ${error.message}. Retrying...`);
                    await this.delay(1000 * (attempt + 1));
                } else {
                    throw lastError;
                }
            }
        }

        throw lastError;
    }

    /**
     * Validate command parameters against documentation
     */
    async validateCommandParameters(commandName, parameters) {
        try {
            const docs = await this.getCommandDocumentation(commandName);

            if (!docs.Generated || !docs.Command) {
                return { isValid: true, errors: [], warnings: ['No documentation available for validation'] };
            }

            const parameterDefs = docs.Command.Parameters || [];
            const errors = [];
            const warnings = [];

            // Check required parameters
            for (const paramDef of parameterDefs) {
                if (paramDef.Required && !(paramDef.Name in parameters)) {
                    errors.push(`Required parameter missing: ${paramDef.Name}`);
                }
            }

            // Check parameter types and constraints
            for (const [paramName, paramValue] of Object.entries(parameters)) {
                const paramDef = parameterDefs.find(p => p.Name === paramName);

                if (!paramDef) {
                    warnings.push(`Unknown parameter: ${paramName}`);
                    continue;
                }

                // Basic type checking
                const typeValidation = this.validateParameterType(paramValue, paramDef.Type);
                if (!typeValidation.isValid) {
                    errors.push(`Parameter ${paramName}: ${typeValidation.error}`);
                }

                // Constraint validation
                for (const constraint of paramDef.Constraints || []) {
                    const constraintValidation = this.validateParameterConstraint(paramValue, constraint);
                    if (!constraintValidation.isValid) {
                        errors.push(`Parameter ${paramName}: ${constraintValidation.error}`);
                    }
                }
            }

            return {
                isValid: errors.length === 0,
                errors: errors,
                warnings: warnings
            };
        } catch (error) {
            console.warn('Parameter validation failed:', error);
            return { isValid: true, errors: [], warnings: ['Validation service unavailable'] };
        }
    }

    /**
     * Validate parameter type
     */
    validateParameterType(value, expectedType) {
        switch (expectedType) {
            case 'String':
                return { isValid: typeof value === 'string', error: 'Expected string value' };
            case 'Integer':
                return {
                    isValid: Number.isInteger(Number(value)),
                    error: 'Expected integer value'
                };
            case 'Float':
                return {
                    isValid: !isNaN(Number(value)),
                    error: 'Expected numeric value'
                };
            case 'Boolean':
                return {
                    isValid: typeof value === 'boolean',
                    error: 'Expected boolean value'
                };
            case 'Array':
                return {
                    isValid: Array.isArray(value),
                    error: 'Expected array value'
                };
            case 'Object':
                return {
                    isValid: typeof value === 'object' && value !== null,
                    error: 'Expected object value'
                };
            default:
                return { isValid: true, error: null };
        }
    }

    /**
     * Validate parameter constraint
     */
    validateParameterConstraint(value, constraint) {
        switch (constraint.Type) {
            case 'MinValue':
                return {
                    isValid: Number(value) >= constraint.Value,
                    error: `Value must be at least ${constraint.Value}`
                };
            case 'MaxValue':
                return {
                    isValid: Number(value) <= constraint.Value,
                    error: `Value must not exceed ${constraint.Value}`
                };
            case 'MinLength':
                return {
                    isValid: String(value).length >= constraint.Value,
                    error: `Length must be at least ${constraint.Value} characters`
                };
            case 'MaxLength':
                return {
                    isValid: String(value).length <= constraint.Value,
                    error: `Length must not exceed ${constraint.Value} characters`
                };
            case 'Pattern':
                const regex = new RegExp(constraint.Value);
                return {
                    isValid: regex.test(String(value)),
                    error: `Value does not match required pattern`
                };
            case 'Enum':
                return {
                    isValid: constraint.Value.includes(value),
                    error: `Value must be one of: ${constraint.Value.join(', ')}`
                };
            default:
                return { isValid: true, error: null };
        }
    }

    /**
     * Batch execute multiple commands
     */
    async executeBatch(commands, options = {}) {
        const {
            parallel = false,
            stopOnError = false,
            timeout = 30000
        } = options;

        const results = [];

        if (parallel) {
            // Execute all commands in parallel
            const promises = commands.map(async (cmd, index) => {
                try {
                    const result = await this.executeCommand(cmd.command, cmd.parameters, { timeout });
                    return { index, success: true, result };
                } catch (error) {
                    return { index, success: false, error: error.message };
                }
            });

            const parallelResults = await Promise.all(promises);

            // Sort results by original order
            parallelResults.sort((a, b) => a.index - b.index);

            return parallelResults.map(r => r.success ? r.result : { Success: false, Error: r.error });
        } else {
            // Execute commands sequentially
            for (const cmd of commands) {
                try {
                    const result = await this.executeCommand(cmd.command, cmd.parameters, { timeout });
                    results.push(result);

                    if (!result.Success && stopOnError) {
                        break;
                    }
                } catch (error) {
                    const errorResult = { Success: false, Error: error.message };
                    results.push(errorResult);

                    if (stopOnError) {
                        break;
                    }
                }
            }

            return results;
        }
    }

    /**
     * Generate command shortcuts for known modules
     */
    async generateCommandShortcuts() {
        const discovery = await this.discoverCommands();
        const shortcuts = {};

        for (const module of discovery.Modules || []) {
            shortcuts[module] = {};

            const moduleCommands = discovery.Commands.filter(cmd => cmd.startsWith(`${module}.`));

            for (const fullCommandName of moduleCommands) {
                const shortName = fullCommandName.replace(`${module}.`, '');

                shortcuts[module][shortName] = async (parameters = {}, options = {}) => {
                    return await this.executeCommand(fullCommandName, parameters, options);
                };
            }
        }

        return shortcuts;
    }

    /**
     * Handle reconnection logic
     */
    async handleReconnection() {
        if (this.reconnectionAttempts >= this.maxReconnectionAttempts) {
            console.error('Max reconnection attempts reached');
            return;
        }

        this.reconnectionAttempts++;

        setTimeout(async () => {
            try {
                const status = await this.checkBridgeConnection();
                if (status) {
                    this.dispatchEvent('connected', status);
                } else {
                    this.handleReconnection();
                }
            } catch (error) {
                this.handleReconnection();
            }
        }, this.reconnectionDelay * Math.pow(2, this.reconnectionAttempts - 1));
    }

    /**
     * Event management
     */
    addEventListener(eventType, listener) {
        if (!this.eventListeners.has(eventType)) {
            this.eventListeners.set(eventType, []);
        }
        this.eventListeners.get(eventType).push(listener);
    }

    removeEventListener(eventType, listener) {
        if (this.eventListeners.has(eventType)) {
            const listeners = this.eventListeners.get(eventType);
            const index = listeners.indexOf(listener);
            if (index > -1) {
                listeners.splice(index, 1);
            }
        }
    }

    dispatchEvent(eventType, data = null) {
        if (this.eventListeners.has(eventType)) {
            this.eventListeners.get(eventType).forEach(listener => {
                try {
                    listener(data);
                } catch (error) {
                    console.error(`Event listener error for ${eventType}:`, error);
                }
            });
        }
    }

    /**
     * Utility methods
     */
    generateCommandId() {
        return `cmd_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    updateStatistics(executionTime, success) {
        this.stats.commandsExecuted++;
        this.stats.lastCommandTime = new Date();

        if (success) {
            this.stats.successfulCommands++;
        } else {
            this.stats.failedCommands++;
        }

        // Update average response time
        this.stats.averageResponseTime = (
            (this.stats.averageResponseTime * (this.stats.commandsExecuted - 1)) + executionTime
        ) / this.stats.commandsExecuted;
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Get client statistics
     */
    getStatistics() {
        return {
            ...this.stats,
            isConnected: this.isConnected,
            cacheStats: {
                commandsCached: this.commandCache.size,
                documentationCached: this.documentationCache.size
            }
        };
    }

    /**
     * Clear caches
     */
    clearCache() {
        this.commandCache.clear();
        this.documentationCache.clear();
        console.log('Command and documentation caches cleared');
    }
}

// Convenience functions for quick usage
window.GameCommands = {
    client: null,

    async init(bridgeUrl = 'http://localhost:8082') {
        this.client = new GameCommandClient(bridgeUrl);

        // Check initial connection
        const status = await this.client.checkBridgeConnection();
        if (status) {
            console.log('🎮 Game Command System initialized and connected');
            return status;
        } else {
            console.warn('⚠️ Game Command System initialized but bridge is not available');
            return null;
        }
    },

    async discover(options = {}) {
        if (!this.client) await this.init();
        return await this.client.discoverCommands(options);
    },

    async execute(command, parameters = {}, options = {}) {
        if (!this.client) await this.init();
        return await this.client.executeCommand(command, parameters, options);
    },

    async docs(command = null, module = null) {
        if (!this.client) await this.init();
        return await this.client.getCommandDocumentation(command, module);
    },

    async shortcuts() {
        if (!this.client) await this.init();
        return await this.client.generateCommandShortcuts();
    }
};

// Export for Node.js environments
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { GameCommandClient, GameCommands: window.GameCommands };
}

console.log('🚀 Game Command System JavaScript client loaded');
console.log('Use GameCommands.init() to connect to the bridge');
console.log('Use GameCommands.discover() to see available commands');
console.log('Use GameCommands.execute(command, parameters) to run commands');
