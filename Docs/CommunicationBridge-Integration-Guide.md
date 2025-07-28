# PowerShell-JavaScript Communication Bridge Integration Guide

## Overview

The Communication Bridge provides a robust, multi-protocol architecture for real-time communication between your PowerShell RPG backend and JavaScript/Leaflet frontend. This guide covers integration patterns, usage examples, and best practices.

## Architecture Components

### PowerShell Side
- **CommunicationBridge.psm1**: Core bridge module with HTTP/WebSocket servers
- **StateManager.psm1**: Game state persistence and synchronization
- **EventSystem.psm1**: Event broadcasting and handling

### JavaScript Side
- **communicationBridge.js**: Client-side bridge for browser/Node.js
- **HTML Demo**: Interactive demonstration and testing interface

## Communication Methods

### 1. HTTP REST API
**Best for**: Command execution, request-response patterns
```powershell
# PowerShell
Start-CommunicationBridge

# JavaScript
const bridge = new CommunicationBridge();
await bridge.initialize();
const result = await bridge.sendCommand('GetGameState');
```

### 2. Server-Sent Events (SSE)
**Best for**: Real-time updates from PowerShell to browser
```javascript
// Automatic event stream connection
bridge.on('game:stateChanged', (data) => {
    console.log('State updated:', data);
});
```

### 3. File-Based Communication
**Best for**: Offline scenarios, debugging, high-reliability transfers
```powershell
# PowerShell automatically watches for command files
# JavaScript creates command files when HTTP unavailable
```

## Integration Steps

### Step 1: Initialize PowerShell Backend

```powershell
# Import required modules
Import-Module ".\Modules\CoreGame\StateManager.psm1" -Force
Import-Module ".\Modules\CoreGame\CommunicationBridge.psm1" -Force

# Initialize State Manager
Initialize-StateManager

# Configure and start Communication Bridge
$bridgeConfig = @{
    HttpPort = 8080
    WebSocketPort = 8081
    DebugMode = $true
    LoggingEnabled = $true
}

Initialize-CommunicationBridge -Configuration $bridgeConfig
Start-CommunicationBridge
```

### Step 2: Initialize JavaScript Frontend

```javascript
// Initialize the bridge
const bridge = new CommunicationBridge({
    httpBaseUrl: 'http://localhost:8080',
    webSocketUrl: 'ws://localhost:8081/gamebridge',
    eventStreamUrl: 'http://localhost:8080/events',
    debugMode: true
});

// Connect and register event handlers
await bridge.initialize();

bridge.on('bridge:connected', (data) => {
    console.log('Connected to PowerShell backend');
});

bridge.on('game:stateChanged', (data) => {
    updateGameUI(data);
});
```

### Step 3: Implement Game Commands

#### PowerShell Command Handlers
```powershell
# Extend the bridge with custom commands
function Handle-CustomCommand {
    param([hashtable]$Parameters)

    switch ($Parameters.Action) {
        "MovePlayer" {
            # Handle player movement
            Update-GameEntityState -EntityId $Parameters.PlayerId -Property "Location" -Value $Parameters.NewLocation
            return @{ Success = $true; NewLocation = $Parameters.NewLocation }
        }
        "UseItem" {
            # Handle item usage
            # ... game logic
            return @{ Success = $true; ItemUsed = $Parameters.ItemId }
        }
    }
}
```

#### JavaScript Command Execution
```javascript
// Move player
async function movePlayer(playerId, newLocation) {
    try {
        const result = await bridge.sendCommand('UpdateGameState', {
            EntityId: playerId,
            Property: 'Location',
            Value: newLocation
        });

        if (result.Success) {
            updatePlayerLocation(newLocation);
        }
    } catch (error) {
        console.error('Move failed:', error);
    }
}

// Use item
async function useItem(itemId) {
    const result = await bridge.sendCommand('CustomCommand', {
        Action: 'UseItem',
        ItemId: itemId
    });
    return result;
}
```

## Data Transfer Patterns

### 1. State Synchronization
```javascript
// Get current game state
const gameState = await bridge.getGameState();

// Update specific entity
await bridge.updateGameState('player_001', 'Experience', 1500);

// Save/Load operations
await bridge.saveGame('checkpoint_1');
await bridge.loadGame('checkpoint_1');
```

### 2. Real-Time Events
```powershell
# PowerShell: Broadcast events
Send-BridgeEvent -EventType "player.levelUp" -EventData @{
    PlayerId = "player_001"
    NewLevel = 15
    ExperienceGained = 500
}
```

```javascript
// JavaScript: Handle events
bridge.on('player.levelUp', (data) => {
    showLevelUpAnimation(data.PlayerId, data.NewLevel);
    updatePlayerStats(data.PlayerId);
});
```

### 3. Batch Operations
```javascript
// Batch multiple commands for efficiency
const commands = [
    { Command: 'UpdateGameState', Parameters: { EntityId: 'player1', Property: 'Health', Value: 100 } },
    { Command: 'UpdateGameState', Parameters: { EntityId: 'player1', Property: 'Mana', Value: 50 } },
    { Command: 'SaveGame', Parameters: { SaveName: 'auto_save' } }
];

for (const cmd of commands) {
    await bridge.sendCommand(cmd.Command, cmd.Parameters);
}
```

## Error Handling

### PowerShell Error Handling
```powershell
try {
    $result = Send-BridgeCommand -Command "RiskyOperation" -Parameters $params
}
catch {
    Write-Error "Command failed: $($_.Exception.Message)"
    Send-BridgeEvent -EventType "error.commandFailed" -EventData @{
        Command = "RiskyOperation"
        Error = $_.Exception.Message
        Timestamp = Get-Date
    }
}
```

### JavaScript Error Handling
```javascript
// Command error handling
try {
    const result = await bridge.sendCommand('RiskyCommand');
} catch (error) {
    console.error('Command failed:', error.message);
    showErrorMessage(error.message);
}

// Connection error handling
bridge.on('bridge:disconnected', (data) => {
    showConnectionLostMessage();
    attemptReconnection();
});

bridge.on('bridge:failed', (data) => {
    showFatalError('Cannot connect to game server');
});
```

## Performance Optimization

### 1. Compression
```powershell
# Enable compression in bridge config
$bridgeConfig = @{
    CompressionEnabled = $true
    BatchingEnabled = $true
    BatchSize = 10
}
```

### 2. Batching
```javascript
// Use batching for multiple operations
const bridge = new CommunicationBridge({
    batchingEnabled: true,
    batchSize: 10,
    batchTimeout: 100
});
```

### 3. Caching
```javascript
// Cache frequently accessed data
class GameDataCache {
    constructor(bridge) {
        this.bridge = bridge;
        this.cache = new Map();
    }

    async getPlayerData(playerId) {
        if (this.cache.has(playerId)) {
            return this.cache.get(playerId);
        }

        const data = await this.bridge.sendCommand('GetPlayerData', { PlayerId: playerId });
        this.cache.set(playerId, data);
        return data;
    }
}
```

## Security Considerations

### 1. Command Validation
```powershell
# Validate commands before execution
function Validate-BridgeCommand {
    param([hashtable]$CommandData)

    $allowedCommands = @('GetGameState', 'UpdateGameState', 'SaveGame', 'LoadGame')

    if ($CommandData.Command -notin $allowedCommands) {
        throw "Command not allowed: $($CommandData.Command)"
    }

    # Additional validation logic...
}
```

### 2. Input Sanitization
```javascript
// Sanitize user input before sending commands
function sanitizeInput(input) {
    if (typeof input === 'string') {
        return input.replace(/[<>'"&]/g, '');
    }
    return input;
}

async function updatePlayerName(playerId, newName) {
    const sanitizedName = sanitizeInput(newName);
    await bridge.updateGameState(playerId, 'Username', sanitizedName);
}
```

## Testing and Debugging

### 1. Enable Debug Mode
```powershell
# PowerShell
Initialize-CommunicationBridge -Configuration @{
    DebugMode = $true
    LoggingEnabled = $true
}
```

```javascript
// JavaScript
const bridge = new CommunicationBridge({
    debugMode: true,
    loggingEnabled: true
});
```

### 2. Monitor Statistics
```javascript
// Monitor bridge performance
setInterval(async () => {
    const stats = await bridge.getStatistics();
    console.log('Bridge stats:', stats);
}, 5000);
```

### 3. Test Connection
```javascript
// Test connection health
async function testConnection() {
    try {
        await bridge.sendCommand('Heartbeat');
        console.log('Connection healthy');
    } catch (error) {
        console.error('Connection unhealthy:', error);
    }
}
```

## Integration with Game Modules

### Character System Integration
```powershell
# Register character event handlers
Register-GameEventHandler -EventType "character.*" -Handler {
    param($EventData)
    Send-BridgeEvent -EventType $EventData.EventType -EventData $EventData.Data
}
```

### Quest System Integration
```javascript
// Handle quest events
bridge.on('quest.completed', (data) => {
    showQuestCompletedNotification(data.QuestId);
    updateQuestLog();
});

bridge.on('quest.started', (data) => {
    addQuestToLog(data.Quest);
});
```

### World System Integration
```javascript
// Sync world state changes
bridge.on('world.locationChanged', (data) => {
    map.setView([data.Latitude, data.Longitude], data.ZoomLevel);
    updateLocationMarkers(data.Location);
});
```

## Production Deployment

### 1. Configuration
```powershell
# Production configuration
$prodConfig = @{
    HttpPort = 80
    WebSocketPort = 443
    DebugMode = $false
    LoggingEnabled = $true
    AuthenticationEnabled = $true
    CompressionEnabled = $true
}
```

### 2. Error Logging
```powershell
# Set up error logging
$Global:BridgeErrorLog = ".\Logs\bridge_errors.log"

Register-GameEventHandler -EventType "bridge.error" -Handler {
    param($EventData)
    Add-Content -Path $Global:BridgeErrorLog -Value "$(Get-Date): $($EventData.Error)"
}
```

### 3. Health Monitoring
```javascript
// Production health monitoring
class BridgeHealthMonitor {
    constructor(bridge) {
        this.bridge = bridge;
        this.isHealthy = true;
        this.startMonitoring();
    }

    startMonitoring() {
        setInterval(async () => {
            try {
                await this.bridge.sendCommand('Heartbeat');
                this.isHealthy = true;
            } catch (error) {
                this.isHealthy = false;
                this.handleUnhealthyState(error);
            }
        }, 30000);
    }

    handleUnhealthyState(error) {
        // Implement recovery logic
        console.error('Bridge unhealthy:', error);
    }
}
```

## API Reference

### PowerShell Functions
- `Initialize-CommunicationBridge($Configuration)`
- `Start-CommunicationBridge()`
- `Stop-CommunicationBridge()`
- `Send-BridgeCommand($Command, $Parameters)`
- `Send-BridgeEvent($EventType, $EventData)`
- `Get-BridgeStatistics()`

### JavaScript Methods
- `bridge.initialize()`
- `bridge.sendCommand(command, parameters)`
- `bridge.getGameState()`
- `bridge.updateGameState(entityId, property, value)`
- `bridge.saveGame(saveName)`
- `bridge.loadGame(saveName)`
- `bridge.on(eventType, handler)`
- `bridge.disconnect()`

### HTTP Endpoints
- `GET /status` - Bridge status and statistics
- `POST /command` - Execute commands
- `GET /events` - Server-sent events stream

## Best Practices

1. **Always handle connection failures gracefully**
2. **Use events for real-time updates, commands for actions**
3. **Implement proper error logging and monitoring**
4. **Cache frequently accessed data on the client side**
5. **Use compression for large data transfers**
6. **Validate all input before processing**
7. **Monitor performance statistics regularly**
8. **Test with realistic network conditions**

## Troubleshooting

### Common Issues
1. **Port conflicts**: Ensure ports 8080/8081 are available
2. **CORS errors**: Check allowed origins configuration
3. **Connection timeouts**: Verify firewall settings
4. **Event loss**: Implement event acknowledgment if critical

### Debug Commands
```powershell
# Check bridge status
Get-BridgeStatistics

# Test HTTP endpoint
Invoke-RestMethod -Uri "http://localhost:8080/status"

# View recent logs
Get-EventLog -LogName "Application" -Source "CommunicationBridge"
```

This communication bridge provides a solid foundation for your PowerShell-JavaScript RPG game architecture. The modular design allows for easy extension and customization based on your specific game requirements.
