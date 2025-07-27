# Event System Integration Guide

## Overview

The PowerShell Leafmap RPG game features a comprehensive event-driven architecture that enables seamless communication between the PowerShell backend and JavaScript frontend. This system provides real-time synchronization, modular game mechanics, and extensible functionality.

## Architecture Components

### 1. JavaScript Event Manager (`js/events.js`)
- Centralized event registration and handling
- PowerShell communication via file polling
- Event queuing and processing
- Error handling and logging

### 2. PowerShell Event System (`Modules/CoreGame/EventSystem.psm1`)
- Event handler registration
- Command processing from JavaScript
- Event logging and auditing
- File-based communication

### 3. Integration Files
- `events.json` - Events from PowerShell to JavaScript
- `commands.json` - Commands from JavaScript to PowerShell
- `event_log.json` - Complete event audit trail
- `visit_log.json` - Location visit history

## Event Types

### Player Events
- `player.created` - New player initialization
- `player.levelUp` - Experience threshold reached
- `player.scoreChanged` - Score modification
- `player.inventoryChanged` - Items added/removed
- `player.died` - Health depleted

### Location Events
- `location.discovered` - New location found
- `location.visited` - Player enters location
- `location.completed` - All objectives met
- `location.unlocked` - Access granted by achievement
- `location.weatherEffect` - Weather impact on location

### Quest Events
- `quest.started` - New quest accepted
- `quest.completed` - Quest objectives met
- `quest.failed` - Quest conditions not met
- `quest.updated` - Progress changed

### System Events
- `system.startup` - Game initialization
- `system.dataLoaded` - Game data loaded from PowerShell
- `system.error` - Error occurred
- `system.weatherUpdate` - Weather condition changed

### UI Events
- `ui.showNotification` - Display notification to user
- `ui.updateMap` - Map display update
- `ui.playSound` - Audio feedback
- `ui.showSpecialNotification` - Special announcements

### PowerShell Communication Events
- `powershell.generateLocations` - Request location generation
- `powershell.saveProgress` - Save player progress
- `powershell.loadProgress` - Load player progress
- `powershell.commandCompleted` - PowerShell command finished

## Usage Examples

### JavaScript Event Registration

```javascript
// Initialize event manager
const eventManager = new EventManager();

// Register for player level up events
eventManager.register('player.levelUp', (data) => {
    console.log(`Player reached level ${data.newLevel}!`);
    showLevelUpAnimation(data.newLevel);
});

// Register for location discoveries
eventManager.register('location.discovered', (data) => {
    addLocationToMap(data.location);
    showDiscoveryNotification(data.location.name);
});

// Emit events
eventManager.emit('player.scoreChanged', {
    oldScore: 100,
    newScore: 250,
    pointsAdded: 150
});
```

### PowerShell Event Registration

```powershell
# Import the event system
Import-Module ".\Modules\CoreGame\EventSystem.psm1"

# Initialize the system
Initialize-EventSystem

# Register event handler
Register-GameEvent -EventType "location.visited" -ScriptBlock {
    param($Data, $Event)

    $location = $Data.location
    Write-Host "Player visited: $($location.name)"

    # Trigger additional logic
    if ($location.type -eq "treasure") {
        Send-GameEvent -EventType "player.foundTreasure" -Data @{
            treasure = $location.items
            value = $location.points
        }
    }
}

# Send event to JavaScript
Send-GameEvent -EventType "location.discovered" -Data @{
    location = @{
        id = "secret_cave"
        name = "Hidden Cave"
        lat = 40.7128
        lng = -74.0060
        type = "mystery"
        points = 200
    }
}
```

## Communication Patterns

### PowerShell → JavaScript

1. **File-based Events**: PowerShell writes events to `events.json`
2. **Polling**: JavaScript polls the file every second
3. **Processing**: JavaScript processes new events and clears the file

### JavaScript → PowerShell

1. **Command Queue**: JavaScript writes commands to `commands.json`
2. **Processing**: PowerShell reads and processes commands
3. **Response**: PowerShell sends results back via events

## Advanced Features

### Event Priorities

```javascript
// High priority event (processed first)
eventManager.register('system.error', errorHandler, { priority: 10 });

// Normal priority event
eventManager.register('player.levelUp', levelUpHandler, { priority: 0 });

// Low priority event (processed last)
eventManager.register('ui.updateStats', statsHandler, { priority: -5 });
```

### One-time Events

```javascript
// Handler that only executes once
eventManager.register('game.firstRun', setupHandler, { once: true });
```

### Asynchronous Processing

```javascript
// Queue event for async processing
eventManager.emit('heavy.computation', data, { async: true });
```

### PowerShell Command Integration

```javascript
// Request PowerShell to generate locations
eventManager.emit('powershell.generateLocations', {
    city: 'New York',
    locationCount: 15,
    difficulty: 'medium'
});

// Listen for completion
eventManager.register('powershell.commandCompleted', (data) => {
    if (data.commandType === 'generateLocations') {
        this.gameMap.loadLocations(data.result.locations);
    }
});
```

## Running the Event System

### Basic Setup

1. **Start the Game**:
   ```powershell
   .\Start-Game.ps1
   ```

2. **Start Event Manager**:
   ```powershell
   .\scripts\Enhanced-Game-Manager.ps1 -Action start
   ```

3. **Open Browser**: Navigate to `http://localhost:8080`

### Development Mode

1. **Event System Demo**:
   ```powershell
   .\scripts\Event-System-Demo.ps1 -Action demo
   ```

2. **Integration Test**:
   ```powershell
   .\scripts\Enhanced-Game-Manager.ps1 -Action test
   ```

3. **Monitor Events**:
   ```powershell
   .\scripts\Enhanced-Game-Manager.ps1 -Action status
   ```

## Error Handling

### JavaScript Error Handling

```javascript
// Global error handler
eventManager.register('system.error', (data) => {
    console.error('System Error:', data.message);
    showErrorNotification(data.message);

    // Log to external service if needed
    logErrorToService(data);
});

// Try-catch in event handlers
eventManager.register('location.visited', (data) => {
    try {
        processLocationVisit(data);
    } catch (error) {
        eventManager.emit('system.error', {
            message: error.message,
            context: 'location.visited',
            data: data
        });
    }
});
```

### PowerShell Error Handling

```powershell
# Error handling in event handlers
Register-GameEvent -EventType "data.process" -ScriptBlock {
    param($Data, $Event)

    try {
        # Process data
        $result = Process-GameData -Data $Data

        Send-GameEvent -EventType "data.processed" -Data @{
            result = $result
            success = $true
        }
    } catch {
        Send-GameEvent -EventType "system.error" -Data @{
            message = $_.Exception.Message
            context = "data.process"
            eventId = $Event.id
        }
    }
}
```

## Performance Considerations

### Event Batching

```javascript
// Batch multiple events together
const batchedEvents = [
    { type: 'player.moved', data: { x: 100, y: 200 } },
    { type: 'player.gainedXP', data: { amount: 10 } },
    { type: 'ui.updateHealth', data: { health: 95 } }
];

eventManager.emitBatch(batchedEvents);
```

### Event Log Management

```powershell
# Configure log size limits
$script:EventConfig.MaxEventLogSize = 5000

# Periodic log cleanup
Register-GameEvent -EventType "system.cleanup" -ScriptBlock {
    Clean-EventLogs -KeepDays 7
    Clean-VisitLogs -KeepRecords 1000
}
```

## Debugging and Monitoring

### Event Log Analysis

```javascript
// Get recent events for debugging
const recentEvents = eventManager.getEventLog('player.levelUp', 50);
console.table(recentEvents);

// Get all events of a specific type
const errorEvents = eventManager.getEventLog('system.error');
```

### PowerShell Event Statistics

```powershell
# Get comprehensive statistics
$stats = Get-EventStatistics

Write-Host "Total Events: $($stats.TotalEventsLogged)"
Write-Host "Event Types: $($stats.EventTypes.Count)"
Write-Host "Active Handlers: $($stats.RegisteredHandlers)"
```

## Extending the System

### Custom Event Types

1. **Define the Event**:
   ```javascript
   // Custom faction event
   eventManager.emit('faction.reputationChanged', {
       faction: 'Explorers Guild',
       change: 25,
       newReputation: 175
   });
   ```

2. **Register Handler**:
   ```powershell
   Register-GameEvent -EventType "faction.reputationChanged" -ScriptBlock {
       param($Data, $Event)

       # Custom logic for faction reputation
       Update-FactionStanding -Faction $Data.faction -Reputation $Data.newReputation

       # Unlock faction-specific content
       if ($Data.newReputation -ge 200) {
           Send-GameEvent -EventType "faction.unlockContent" -Data @{
               faction = $Data.faction
               content = "secret_missions"
           }
       }
   }
   ```

### Plugin Architecture

```javascript
// Plugin registration
class WeatherPlugin {
    constructor(eventManager) {
        this.eventManager = eventManager;
        this.register();
    }

    register() {
        this.eventManager.register('weather.changed', (data) => {
            this.handleWeatherChange(data);
        });
    }

    handleWeatherChange(data) {
        // Weather-specific logic
        this.updateVisualEffects(data.condition);
        this.modifyGameplay(data.effects);
    }
}

// Initialize plugin
const weatherPlugin = new WeatherPlugin(eventManager);
```

## Best Practices

1. **Event Naming**: Use hierarchical naming (e.g., `player.inventory.added`)
2. **Data Structure**: Keep event data consistent and well-structured
3. **Error Handling**: Always include try-catch blocks in event handlers
4. **Performance**: Use async events for heavy operations
5. **Documentation**: Document custom events and their data structures
6. **Testing**: Create unit tests for event handlers
7. **Logging**: Log important events for debugging and analytics

## Troubleshooting

### Common Issues

1. **Events Not Received**:
   - Check file permissions on `events.json`
   - Verify polling is active
   - Check event log for errors

2. **PowerShell Commands Not Processing**:
   - Ensure `commands.json` is writable
   - Check PowerShell execution policy
   - Verify module imports

3. **Memory Leaks**:
   - Unregister unused event handlers
   - Limit event log size
   - Clear processed events regularly

### Debug Commands

```powershell
# Check event system status
.\scripts\Enhanced-Game-Manager.ps1 -Action status

# View recent events
Get-Content event_log.json | ConvertFrom-Json | Select-Object -Last 10

# Test integration
.\scripts\Event-System-Demo.ps1 -Action test
```

This event system provides a robust foundation for building complex, interactive gameplay mechanics while maintaining clean separation between the PowerShell backend and JavaScript frontend.
