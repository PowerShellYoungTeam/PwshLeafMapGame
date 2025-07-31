/**
 * StateManager Class
 * 
 * The StateManager class is responsible for managing application state on the client side.
 * It provides features for state synchronization with a PowerShell backend, local storage
 * persistence, conflict resolution, and performance monitoring.
 * 
 * Key Features:
 * - Automatic state synchronization at configurable intervals.
 * - Local storage support for persisting state across sessions.
 * - Conflict resolution strategies (e.g., LastWriteWins, Manual).
 * - Validation and performance tracking for state operations.
 * 
 * Integration Patterns:
 * - The class interacts with local storage to save and load state data.
 * - It uses a configurable sync mode to merge or overwrite state with the backend.
 * - Event listeners can be registered to track state changes and synchronization events.
 */

class StateManager {
    /**
     * Creates a new instance of the StateManager class.
     * 
     * @param {Object} config - Configuration options for the StateManager.
     * @param {number} [config.autoSyncInterval=30000] - Interval (in ms) for automatic state synchronization.
     * @param {number} [config.maxLocalStates=10] - Maximum number of local state snapshots to keep.
     * @param {boolean} [config.compressionEnabled=true] - Whether to enable state compression.
     * @param {boolean} [config.encryptionEnabled=false] - Whether to enable state encryption.
     * @param {boolean} [config.persistToLocalStorage=true] - Whether to persist state to local storage.
     * @param {string} [config.syncMode='Merge'] - Synchronization mode ('Merge', 'Overwrite', 'Validate').
     * @param {string} [config.conflictResolution='LastWriteWins'] - Conflict resolution strategy.
     * @param {boolean} [config.validationEnabled=true] - Whether to enable state validation.
     * @param {boolean} [config.performanceMonitoring=true] - Whether to enable performance monitoring.
     */
    constructor(config = {}) {
        this.config = {
            autoSyncInterval: 30000, // 30 seconds
            maxLocalStates: 10,
            compressionEnabled: true,
            encryptionEnabled: false,
            persistToLocalStorage: true,
            syncMode: 'Merge', // Merge, Overwrite, Validate
            conflictResolution: 'LastWriteWins', // LastWriteWins, Manual, Merge
            validationEnabled: true,
            performanceMonitoring: true,
            ...config
        };

        this.state = {
            current: {},
            previous: {},
            snapshots: {},
            changeLog: [],
            syncQueue: [],
            validationErrors: [],
            trackers: new Map()
        };

        this.metrics = {
            saveCount: 0,
            loadCount: 0,
            syncCount: 0,
            averageSaveTime: 0,
            averageLoadTime: 0,
            averageSyncTime: 0,
            totalDataSize: 0,
            errorCount: 0,
            lastActivity: new Date()
        };

        this.isInitialized = false;
        this.autoSyncTimer = null;
        this.eventListeners = new Map();

        this.initializeStorage();
        this.setupAutoSync();
    }

    initializeStorage() {
        // Create local storage keys if they don't exist
        const keys = ['gameState', 'entityStates', 'stateMetrics', 'saveSlots'];
        keys.forEach(key => {
            if (!localStorage.getItem(`pwshGame_${key}`)) {
                localStorage.setItem(`pwshGame_${key}`, JSON.stringify({}));
            }
        });
    }

    setupAutoSync() {
        if (this.config.autoSyncInterval > 0) {
            this.autoSyncTimer = setInterval(() => {
                this.performAutoSync();
            }, this.config.autoSyncInterval);
            console.log(`Auto-sync timer started (interval: ${this.config.autoSyncInterval}ms)`);
        }
    }

    // Entity state tracking
    registerEntity(entityId, entityType, initialState) {
        const tracker = new StateChangeTracker(entityId, entityType, initialState);
        this.state.trackers.set(entityId, tracker);

        // Update current state
        if (!this.state.current[entityId]) {
            this.state.current[entityId] = {};
        }
        Object.assign(this.state.current[entityId], initialState);

        this.persistToLocalStorage();
        this.emit('entityRegistered', { entityId, entityType, initialState });

        console.log(`Registered entity for state tracking: ${entityType} (${entityId})`);
        return { success: true, entityId, entityType, timestamp: new Date() };
    }

    updateEntityState(entityId, property, newValue, changeType = 'Update') {
        const tracker = this.state.trackers.get(entityId);
        if (!tracker) {
            console.warn(`Entity ${entityId} not registered for state tracking`);
            return { success: false, error: 'Entity not registered' };
        }

        const oldValue = tracker.currentState[property];
        tracker.recordChange(property, oldValue, newValue, changeType);

        // Update current state
        if (!this.state.current[entityId]) {
            this.state.current[entityId] = {};
        }
        this.state.current[entityId][property] = newValue;

        this.persistToLocalStorage();
        this.emit('entityStateUpdated', { entityId, property, oldValue, newValue, changeType });

        console.log(`Updated entity state: ${entityId}.${property} = ${newValue}`);
        return { success: true, entityId, property, value: newValue, timestamp: new Date() };
    }

    getEntityState(entityId) {
        const tracker = this.state.trackers.get(entityId);
        return tracker ? { ...tracker.currentState } : {};
    }

    // Save/Load operations
    async saveGameState(saveName = 'default', additionalData = {}) {
        const startTime = performance.now();

        try {
            const saveData = this.compileSaveData(additionalData);
            const saveKey = `pwshGame_save_${saveName}`;

            // Create backup if save exists
            if (localStorage.getItem(saveKey)) {
                this.createBackup(saveName);
            }

            // Save data
            let serializedData = JSON.stringify(saveData);

            if (this.config.compressionEnabled) {
                serializedData = this.compressData(serializedData);
            }

            localStorage.setItem(saveKey, serializedData);

            // Update save slots registry
            this.updateSaveSlots(saveName, saveData);

            // Mark all trackers as clean
            this.state.trackers.forEach(tracker => tracker.markClean());

            const saveTime = performance.now() - startTime;
            this.updateSaveMetrics(saveTime, serializedData.length);

            const result = {
                success: true,
                saveName,
                saveSize: serializedData.length,
                saveTime,
                timestamp: new Date(),
                entities: this.state.trackers.size
            };

            this.emit('stateSaved', result);
            console.log(`Game state saved: ${saveName} (${result.saveSize} bytes, ${result.saveTime.toFixed(2)}ms)`);

            return result;
        }
        catch (error) {
            const saveTime = performance.now() - startTime;
            this.metrics.errorCount++;

            const result = {
                success: false,
                error: error.message,
                saveTime,
                timestamp: new Date()
            };

            this.emit('stateSaveError', result);
            throw new Error(`Save failed: ${error.message}`);
        }
    }

    async loadGameState(saveName = 'default') {
        const startTime = performance.now();

        try {
            const saveKey = `pwshGame_save_${saveName}`;
            let serializedData = localStorage.getItem(saveKey);

            if (!serializedData) {
                throw new Error(`Save file not found: ${saveName}`);
            }

            // Decompress if needed
            if (this.config.compressionEnabled) {
                serializedData = this.decompressData(serializedData);
            }

            const saveData = JSON.parse(serializedData);

            // Validate save data
            if (this.config.validationEnabled) {
                const validation = this.validateSaveData(saveData);
                if (!validation.isValid) {
                    throw new Error(`Save data validation failed: ${validation.errors.join('; ')}`);
                }
            }

            // Load entities into trackers
            this.loadEntitiesFromSave(saveData);

            // Update current state
            this.state.current = { ...saveData.gameState };
            this.state.previous = { ...this.state.current };

            const loadTime = performance.now() - startTime;
            this.updateLoadMetrics(loadTime);

            const result = {
                success: true,
                saveName,
                loadTime,
                timestamp: new Date(),
                entities: Object.keys(saveData.entities).length,
                saveData
            };

            this.emit('stateLoaded', result);
            console.log(`Game state loaded: ${saveName} (${result.entities} entities, ${result.loadTime.toFixed(2)}ms)`);

            return result;
        }
        catch (error) {
            const loadTime = performance.now() - startTime;
            this.metrics.errorCount++;

            const result = {
                success: false,
                error: error.message,
                loadTime,
                timestamp: new Date()
            };

            this.emit('stateLoadError', result);
            throw new Error(`Load failed: ${error.message}`);
        }
    }

    compileSaveData(additionalData) {
        const entities = {};

        this.state.trackers.forEach((tracker, entityId) => {
            entities[entityId] = {
                entityType: tracker.entityType,
                state: tracker.currentState,
                changes: tracker.changes,
                lastModified: tracker.lastModified,
                isDirty: tracker.isDirty
            };
        });

        return {
            version: '1.0.0',
            gameState: { ...this.state.current },
            entities,
            metadata: {
                savedAt: new Date(),
                gameVersion: '1.0.0',
                platform: 'JavaScript',
                playerCount: Object.values(entities).filter(e => e.entityType === 'Player').length,
                totalEntities: Object.keys(entities).length
            },
            additionalData,
            performance: { ...this.metrics }
        };
    }

    loadEntitiesFromSave(saveData) {
        this.state.trackers.clear();

        Object.keys(saveData.entities).forEach(entityId => {
            const entityData = saveData.entities[entityId];
            const tracker = new StateChangeTracker(entityId, entityData.entityType, entityData.state);

            // Restore change history
            if (entityData.changes) {
                tracker.changes = [...entityData.changes];
            }

            tracker.lastModified = entityData.lastModified ? new Date(entityData.lastModified) : new Date();
            tracker.isDirty = entityData.isDirty !== undefined ? entityData.isDirty : false;

            this.state.trackers.set(entityId, tracker);
        });

        console.log(`Loaded ${this.state.trackers.size} entities from save data`);
    }

    validateSaveData(saveData) {
        const validation = {
            isValid: true,
            errors: [],
            warnings: []
        };

        // Check required fields
        const requiredFields = ['version', 'gameState', 'entities', 'metadata'];
        requiredFields.forEach(field => {
            if (!(field in saveData)) {
                validation.isValid = false;
                validation.errors.push(`Missing required field: ${field}`);
            }
        });

        // Validate entities
        if (saveData.entities) {
            Object.keys(saveData.entities).forEach(entityId => {
                const entity = saveData.entities[entityId];
                if (!entity.entityType) {
                    validation.warnings.push(`Entity ${entityId} missing entityType`);
                }
                if (!entity.state) {
                    validation.warnings.push(`Entity ${entityId} missing state`);
                }
            });
        }

        return validation;
    }

    // PowerShell synchronization
    async syncWithPowerShell(syncMode = 'Merge') {
        const startTime = performance.now();

        try {
            const exportData = this.exportForPowerShell();

            // Send to PowerShell via event system
            const syncResult = await this.sendToPowerShell('state.sync', {
                browserState: exportData,
                syncMode: syncMode
            });

            // Process sync results
            if (syncResult.success) {
                if (syncResult.updatedEntities && syncResult.updatedEntities.length > 0) {
                    // Re-import updated entities
                    await this.importFromPowerShell(syncResult.updatedData);
                }
            }

            const syncTime = performance.now() - startTime;
            this.metrics.syncCount++;
            this.metrics.averageSyncTime = (
                (this.metrics.averageSyncTime * (this.metrics.syncCount - 1)) + syncTime
            ) / this.metrics.syncCount;

            const result = {
                success: syncResult.success,
                conflictCount: syncResult.conflictCount || 0,
                updatedEntities: syncResult.updatedEntities || [],
                syncTime,
                timestamp: new Date()
            };

            this.emit('powershellSynced', result);
            console.log(`PowerShell sync completed: ${result.updatedEntities.length} entities updated`);

            return result;
        }
        catch (error) {
            this.metrics.errorCount++;

            const result = {
                success: false,
                error: error.message,
                timestamp: new Date()
            };

            this.emit('powershellSyncError', result);
            throw new Error(`PowerShell sync failed: ${error.message}`);
        }
    }

    exportForPowerShell() {
        const exportData = {
            version: '1.0.0',
            timestamp: new Date(),
            entities: {},
            gameState: { ...this.state.current },
            metadata: {
                exportedAt: new Date(),
                entityCount: 0,
                platform: 'JavaScript'
            }
        };

        this.state.trackers.forEach((tracker, entityId) => {
            exportData.entities[entityId] = {
                entityType: tracker.entityType,
                state: tracker.currentState,
                lastModified: tracker.lastModified,
                isDirty: tracker.isDirty
            };
        });

        exportData.metadata.entityCount = Object.keys(exportData.entities).length;

        return exportData;
    }

    async importFromPowerShell(powershellData) {
        try {
            // Validate imported data
            if (this.config.validationEnabled) {
                const validation = this.validateSaveData(powershellData);
                if (!validation.isValid) {
                    throw new Error(`PowerShell data validation failed: ${validation.errors.join('; ')}`);
                }
            }

            let importedCount = 0;

            // Import entities
            Object.keys(powershellData.entities).forEach(entityId => {
                const entityData = powershellData.entities[entityId];

                if (this.state.trackers.has(entityId)) {
                    // Update existing entity
                    const tracker = this.state.trackers.get(entityId);
                    Object.keys(entityData.state).forEach(property => {
                        this.updateEntityState(entityId, property, entityData.state[property]);
                    });
                } else {
                    // Register new entity
                    this.registerEntity(entityId, entityData.entityType, entityData.state);
                }

                importedCount++;
            });

            // Update game state
            if (powershellData.gameState) {
                Object.keys(powershellData.gameState).forEach(key => {
                    this.state.current[key] = powershellData.gameState[key];
                });
            }

            const result = {
                success: true,
                importedEntities: importedCount,
                timestamp: new Date()
            };

            this.emit('powershellImported', result);
            return result;
        }
        catch (error) {
            const result = {
                success: false,
                error: error.message,
                timestamp: new Date()
            };

            this.emit('powershellImportError', result);
            throw error;
        }
    }

    // Utility methods
    persistToLocalStorage() {
        if (!this.config.persistToLocalStorage) return;

        try {
            // Save current state
            localStorage.setItem('pwshGame_gameState', JSON.stringify(this.state.current));

            // Save entity states
            const entityStates = {};
            this.state.trackers.forEach((tracker, entityId) => {
                entityStates[entityId] = {
                    entityType: tracker.entityType,
                    state: tracker.currentState,
                    isDirty: tracker.isDirty,
                    lastModified: tracker.lastModified
                };
            });
            localStorage.setItem('pwshGame_entityStates', JSON.stringify(entityStates));

            // Save metrics
            localStorage.setItem('pwshGame_stateMetrics', JSON.stringify(this.metrics));
        }
        catch (error) {
            console.warn('Failed to persist to localStorage:', error);
        }
    }

    loadFromLocalStorage() {
        if (!this.config.persistToLocalStorage) return;

        try {
            // Load current state
            const gameState = localStorage.getItem('pwshGame_gameState');
            if (gameState) {
                this.state.current = JSON.parse(gameState);
            }

            // Load entity states
            const entityStates = localStorage.getItem('pwshGame_entityStates');
            if (entityStates) {
                const states = JSON.parse(entityStates);
                Object.keys(states).forEach(entityId => {
                    const entityData = states[entityId];
                    const tracker = new StateChangeTracker(entityId, entityData.entityType, entityData.state);
                    tracker.isDirty = entityData.isDirty;
                    tracker.lastModified = new Date(entityData.lastModified);
                    this.state.trackers.set(entityId, tracker);
                });
            }

            // Load metrics
            const metrics = localStorage.getItem('pwshGame_stateMetrics');
            if (metrics) {
                Object.assign(this.metrics, JSON.parse(metrics));
            }

            console.log('State loaded from localStorage');
        }
        catch (error) {
            console.warn('Failed to load from localStorage:', error);
        }
    }

    createBackup(saveName) {
        const saveKey = `pwshGame_save_${saveName}`;
        const existingData = localStorage.getItem(saveKey);

        if (existingData) {
            const backupKey = `pwshGame_backup_${saveName}_${Date.now()}`;
            localStorage.setItem(backupKey, existingData);

            // Clean up old backups
            this.cleanupOldBackups();
        }
    }

    cleanupOldBackups() {
        const maxBackups = 5;
        const backupKeys = [];

        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith('pwshGame_backup_')) {
                backupKeys.push(key);
            }
        }

        // Sort by timestamp (newest first)
        backupKeys.sort((a, b) => {
            const timestampA = parseInt(a.split('_').pop());
            const timestampB = parseInt(b.split('_').pop());
            return timestampB - timestampA;
        });

        // Remove old backups
        if (backupKeys.length > maxBackups) {
            backupKeys.slice(maxBackups).forEach(key => {
                localStorage.removeItem(key);
            });
        }
    }

    updateSaveSlots(saveName, saveData) {
        const saveSlots = JSON.parse(localStorage.getItem('pwshGame_saveSlots') || '{}');

        saveSlots[saveName] = {
            name: saveName,
            size: JSON.stringify(saveData).length,
            created: saveSlots[saveName]?.created || new Date(),
            modified: new Date(),
            entities: Object.keys(saveData.entities).length,
            metadata: saveData.metadata
        };

        localStorage.setItem('pwshGame_saveSlots', JSON.stringify(saveSlots));
    }

    getSaveSlots() {
        return JSON.parse(localStorage.getItem('pwshGame_saveSlots') || '{}');
    }

    deleteSave(saveName) {
        const saveKey = `pwshGame_save_${saveName}`;
        localStorage.removeItem(saveKey);

        const saveSlots = this.getSaveSlots();
        delete saveSlots[saveName];
        localStorage.setItem('pwshGame_saveSlots', JSON.stringify(saveSlots));

        this.emit('saveDeleted', { saveName, timestamp: new Date() });
    }

    compressData(data) {
        // Simple compression using LZ-string or similar
        // For now, return as-is (implement compression library if needed)
        return data;
    }

    decompressData(data) {
        // Simple decompression
        // For now, return as-is
        return data;
    }

    updateSaveMetrics(saveTime, dataSize) {
        this.metrics.saveCount++;
        this.metrics.averageSaveTime = (
            (this.metrics.averageSaveTime * (this.metrics.saveCount - 1)) + saveTime
        ) / this.metrics.saveCount;
        this.metrics.totalDataSize += dataSize;
        this.metrics.lastActivity = new Date();
    }

    updateLoadMetrics(loadTime) {
        this.metrics.loadCount++;
        this.metrics.averageLoadTime = (
            (this.metrics.averageLoadTime * (this.metrics.loadCount - 1)) + loadTime
        ) / this.metrics.loadCount;
        this.metrics.lastActivity = new Date();
    }

    async performAutoSync() {
        try {
            // Check if any entities are dirty
            const dirtyEntities = Array.from(this.state.trackers.values()).filter(tracker => tracker.isDirty);

            if (dirtyEntities.length > 0) {
                await this.syncWithPowerShell('Merge');
                console.log(`Auto-sync completed: ${dirtyEntities.length} dirty entities`);
            }
        }
        catch (error) {
            console.error('Auto-sync failed:', error);
            this.emit('autoSyncError', { error: error.message, timestamp: new Date() });
        }
    }

    async sendToPowerShell(eventType, data) {
        // This would be implemented based on your communication method
        // For example, using WebSocket, HTTP requests, or event system
        return new Promise((resolve) => {
            // Simulate async PowerShell communication
            setTimeout(() => {
                resolve({
                    success: true,
                    updatedEntities: [],
                    conflictCount: 0
                });
            }, 100);
        });
    }

    // Event system
    on(eventType, callback) {
        if (!this.eventListeners.has(eventType)) {
            this.eventListeners.set(eventType, []);
        }
        this.eventListeners.get(eventType).push(callback);
    }

    emit(eventType, data) {
        const listeners = this.eventListeners.get(eventType);
        if (listeners) {
            listeners.forEach(callback => callback(data));
        }
    }

    getStateStatistics() {
        return {
            trackedEntities: this.state.trackers.size,
            dirtyEntities: Array.from(this.state.trackers.values()).filter(t => t.isDirty).length,
            totalChanges: Array.from(this.state.trackers.values())
                .reduce((sum, tracker) => sum + tracker.changes.length, 0),
            performance: { ...this.metrics },
            configuration: { ...this.config },
            lastActivity: this.metrics.lastActivity
        };
    }

    cleanup() {
        if (this.autoSyncTimer) {
            clearInterval(this.autoSyncTimer);
        }

        // Perform final persistence
        this.persistToLocalStorage();

        console.log('State manager cleanup completed');
    }
}

// State change tracker for JavaScript
class StateChangeTracker {
    constructor(entityId, entityType, initialState) {
        this.entityId = entityId;
        this.entityType = entityType;
        this.originalState = { ...initialState };
        this.currentState = { ...initialState };
        this.changes = [];
        this.createdAt = new Date();
        this.lastModified = new Date();
        this.isDirty = false;
    }

    recordChange(property, oldValue, newValue, changeType = 'Update') {
        const change = {
            id: this.generateGuid(),
            property,
            oldValue,
            newValue,
            changeType,
            timestamp: new Date(),
            source: 'StateManager'
        };

        this.changes.push(change);
        this.currentState[property] = newValue;
        this.lastModified = new Date();
        this.isDirty = true;
    }

    getChangesSince(since) {
        const recentChanges = this.changes.filter(change => change.timestamp > since);
        return {
            entityId: this.entityId,
            entityType: this.entityType,
            changes: recentChanges,
            changeCount: recentChanges.length,
            lastModified: this.lastModified
        };
    }

    markClean() {
        this.isDirty = false;
        this.originalState = { ...this.currentState };
    }

    getDiff() {
        const diff = {
            entityId: this.entityId,
            entityType: this.entityType,
            added: {},
            modified: {},
            removed: {}
        };

        // Compare current state with original
        Object.keys(this.currentState).forEach(key => {
            if (!(key in this.originalState)) {
                diff.added[key] = this.currentState[key];
            } else if (this.originalState[key] !== this.currentState[key]) {
                diff.modified[key] = {
                    oldValue: this.originalState[key],
                    newValue: this.currentState[key]
                };
            }
        });

        Object.keys(this.originalState).forEach(key => {
            if (!(key in this.currentState)) {
                diff.removed[key] = this.originalState[key];
            }
        });

        return diff;
    }

    generateGuid() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            const r = Math.random() * 16 | 0;
            const v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { StateManager, StateChangeTracker };
}

// Export for browser environments
if (typeof window !== 'undefined') {
    window.StateManager = StateManager;
    window.StateChangeTracker = StateChangeTracker;
}
