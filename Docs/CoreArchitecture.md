# Core Architecture Design Document

## Event System Architecture

### Overview
The event system provides a centralized communication layer between PowerShell backend and JavaScript frontend, enabling real-time game state synchronization and responsive gameplay mechanics.

### Core Components

#### 1. Event Types
- **Game Events**: Player actions, state changes, location visits
- **System Events**: PowerShell script execution, data loading, error handling
- **UI Events**: Map interactions, inventory updates, quest notifications
- **Network Events**: WebSocket communication, API calls, data synchronization

#### 2. Event Flow Architecture
```
PowerShell Backend ←→ Event Bridge ←→ JavaScript Frontend
                          ↓
                    Event Registry
                          ↓
                    Event Handlers
```

#### 3. Communication Patterns

**PowerShell → JavaScript**
- File-based event queue (`events.json`)
- HTTP POST to local server
- WebSocket messages (for real-time features)

**JavaScript → PowerShell**
- Command queue in `commands.json`
- localStorage triggers
- HTTP GET requests to PowerShell endpoints

### Event Registration Patterns

#### JavaScript Event Registration
```javascript
EventManager.register('location.visited', (data) => {
    // Handle location visit
});

EventManager.register('player.levelUp', (data) => {
    // Handle level up
});
```

#### PowerShell Event Registration
```powershell
Register-GameEvent -EventType "player.action" -ScriptBlock {
    param($EventData)
    # Process player action
}
```

### Event Handling Mechanisms

#### 1. Synchronous Events
- Immediate processing required
- Used for critical game state changes
- Error handling with rollback capability

#### 2. Asynchronous Events
- Background processing
- Non-blocking operations
- Queued execution with retry logic

#### 3. Batched Events
- Multiple events processed together
- Performance optimization for frequent events
- Reduced I/O operations

### Event Categories

#### Player Events
- `player.created` - New player initialization
- `player.levelUp` - Experience threshold reached
- `player.died` - Health depleted
- `player.inventoryChanged` - Items added/removed

#### Location Events
- `location.discovered` - New location found
- `location.visited` - Player enters location
- `location.completed` - All objectives met
- `location.respawned` - Location reset

#### Quest Events
- `quest.started` - New quest accepted
- `quest.completed` - Quest objectives met
- `quest.failed` - Quest conditions not met
- `quest.updated` - Progress changed

#### System Events
- `system.dataLoaded` - Game data loaded from PowerShell
- `system.error` - Error occurred
- `system.saveComplete` - Game state saved
- `system.commandExecuted` - PowerShell command completed

### Error Handling Strategy
- Event validation before processing
- Graceful degradation for missing handlers
- Automatic retry for failed events
- Comprehensive logging and debugging

## Data Models

### Entity Base Class
```javascript
class Entity {
    constructor(id, type) {
        this.id = id;
        this.type = type;
        this.events = new EventEmitter();
    }
}
```

### Player Model
```javascript
class Player extends Entity {
    constructor(name) {
        super(generateId(), 'player');
        this.name = name;
        this.level = 1;
        this.experience = 0;
        this.health = 100;
        this.inventory = [];
        this.location = null;
    }
}
```

### NPC Model
```javascript
class NPC extends Entity {
    constructor(name, type) {
        super(generateId(), 'npc');
        this.name = name;
        this.npcType = type;
        this.dialogue = [];
        this.quests = [];
        this.faction = null;
    }
}
```

### Item Model
```javascript
class Item extends Entity {
    constructor(name, type) {
        super(generateId(), 'item');
        this.name = name;
        this.itemType = type;
        this.value = 0;
        this.rarity = 'common';
        this.effects = [];
    }
}
```

## Game State Management

### State Persistence
- **Local Storage**: Browser-based temporary state
- **File System**: PowerShell-managed persistent state
- **Event Log**: Complete action history for replay
- **Checkpoints**: Periodic state snapshots

### Save/Load Functionality
- **Auto-save**: Triggered by significant events
- **Manual save**: Player-initiated state preservation
- **Cloud sync**: Optional remote state backup
- **Version control**: State migration between game versions

### State Synchronization
- **Conflict resolution**: Handle concurrent modifications
- **Validation**: Ensure state integrity
- **Rollback**: Revert to previous valid state
- **Merge**: Combine changes from multiple sources
