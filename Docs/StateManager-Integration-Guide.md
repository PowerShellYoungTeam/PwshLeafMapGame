# State Management Integration Guide
## PowerShell Leafmap Game - Comprehensive State Architecture

### Overview

This document provides integration examples and best practices for implementing the comprehensive state management system in your PowerShell Leafmap RPG game. The architecture provides seamless state persistence, save/load functionality, and real-time synchronization between PowerShell backend and JavaScript frontend.

## Core Architecture Components

### 1. PowerShell State Manager (`StateManager.psm1`)
- **StateChangeTracker**: Tracks entity modifications with full audit trail
- **GameStateManager**: Core state management with auto-save and compression
- **Browser Synchronization**: Import/export functionality for browser communication
- **Performance Monitoring**: Comprehensive metrics and statistics

### 2. JavaScript State Manager (`stateManager.js`)
- **StateManager Class**: Browser-side state management and persistence
- **StateChangeTracker Class**: Client-side change tracking
- **LocalStorage Integration**: Automatic persistence to browser storage
- **PowerShell Communication**: Bi-directional sync capabilities

### 3. Demo Applications
- **PowerShell Demo**: `Test-StateManager.ps1` - Backend functionality showcase
- **HTML Demo**: `test-state-manager.html` - Frontend integration demonstration

## Integration Examples

### Basic PowerShell Integration

```powershell
# 1. Initialize State Manager
Import-Module .\Modules\CoreGame\StateManager.psm1
$result = Initialize-StateManager -Configuration @{
    AutoSaveInterval = 300  # 5 minutes
    CompressionEnabled = $true
    StateValidation = $true
    ConflictResolution = "LastWriteWins"
}

# 2. Register Game Entities
$playerData = @{
    Username = "Player1"
    Level = 1
    Experience = 0
    Location = @{ Name = "Starter Town"; Id = "town_001" }
    Inventory = @()
    Currency = 100
}

Register-GameEntity -EntityId "player_001" -EntityType "Player" -InitialState $playerData

# 3. Update Entity State
Update-GameEntityState -EntityId "player_001" -Property "Experience" -Value 1500
Update-GameEntityState -EntityId "player_001" -Property "Level" -Value 2

# 4. Save Game State
$saveResult = Save-GameState -SaveName "checkpoint_1" -AdditionalData @{
    GameMode = "Adventure"
    Difficulty = "Normal"
}

# 5. Load Game State
$loadResult = Load-GameState -SaveName "checkpoint_1"
```

### Basic JavaScript Integration

```javascript
// 1. Initialize State Manager
const stateManager = new StateManager({
    autoSyncInterval: 30000,
    persistToLocalStorage: true,
    syncMode: 'Merge',
    validationEnabled: true
});

// 2. Register Game Entities
const playerData = {
    username: 'Player1',
    level: 1,
    experience: 0,
    location: { name: 'Starter Town', id: 'town_001' },
    inventory: [],
    currency: 100
};

stateManager.registerEntity('player_001', 'Player', playerData);

// 3. Update Entity State
stateManager.updateEntityState('player_001', 'experience', 1500);
stateManager.updateEntityState('player_001', 'level', 2);

// 4. Save Game State
await stateManager.saveGameState('checkpoint_1', {
    gameMode: 'Adventure',
    difficulty: 'Normal'
});

// 5. Load Game State
await stateManager.loadGameState('checkpoint_1');
```

## Game Module Integration

### Player System Integration

```powershell
# PlayerSystem.psm1 Integration
function Update-PlayerExperience {
    param(
        [string]$PlayerId,
        [int]$ExperienceGained
    )

    # Get current player state
    $currentState = $Global:StateManager.GetEntityState($PlayerId)
    $newExperience = $currentState.Experience + $ExperienceGained

    # Update state
    Update-GameEntityState -EntityId $PlayerId -Property "Experience" -Value $newExperience

    # Check for level up
    $newLevel = [math]::Floor($newExperience / 1000) + 1
    if ($newLevel -gt $currentState.Level) {
        Update-GameEntityState -EntityId $PlayerId -Property "Level" -Value $newLevel

        # Trigger level up event
        Send-GameEvent -EventType "player.levelUp" -Data @{
            PlayerId = $PlayerId
            OldLevel = $currentState.Level
            NewLevel = $newLevel
            TotalExperience = $newExperience
        }
    }

    # Auto-save if significant progress
    if ($ExperienceGained -gt 500) {
        Save-GameState -SaveName "auto_save_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
}
```

### Inventory System Integration

```javascript
// Inventory management with state synchronization
class InventoryManager {
    constructor(stateManager) {
        this.stateManager = stateManager;
    }

    addItem(playerId, item) {
        const playerState = this.stateManager.getEntityState(playerId);
        const inventory = [...(playerState.inventory || [])];

        inventory.push(item);

        this.stateManager.updateEntityState(playerId, 'inventory', inventory);

        // Trigger inventory update event
        this.stateManager.emit('inventoryUpdated', {
            playerId,
            item,
            action: 'add',
            inventorySize: inventory.length
        });
    }

    removeItem(playerId, itemId) {
        const playerState = this.stateManager.getEntityState(playerId);
        const inventory = (playerState.inventory || []).filter(item => item.id !== itemId);

        this.stateManager.updateEntityState(playerId, 'inventory', inventory);

        this.stateManager.emit('inventoryUpdated', {
            playerId,
            itemId,
            action: 'remove',
            inventorySize: inventory.length
        });
    }
}
```

### Quest System Integration

```powershell
# QuestSystem.psm1 Integration
function Complete-Quest {
    param(
        [string]$PlayerId,
        [string]$QuestId,
        [hashtable]$QuestRewards
    )

    # Update quest progress
    $playerState = $Global:StateManager.GetEntityState($PlayerId)
    $questProgress = $playerState.QuestProgress.Clone()
    $questProgress[$QuestId] = @{
        Status = "Completed"
        CompletedAt = Get-Date
        Rewards = $QuestRewards
    }

    Update-GameEntityState -EntityId $PlayerId -Property "QuestProgress" -Value $questProgress

    # Apply rewards
    if ($QuestRewards.Experience) {
        Update-PlayerExperience -PlayerId $PlayerId -ExperienceGained $QuestRewards.Experience
    }

    if ($QuestRewards.Currency) {
        $newCurrency = $playerState.Currency + $QuestRewards.Currency
        Update-GameEntityState -EntityId $PlayerId -Property "Currency" -Value $newCurrency
    }

    # Add to completed quests
    $completedQuests = @($playerState.CompletedQuests) + $QuestId
    Update-GameEntityState -EntityId $PlayerId -Property "CompletedQuests" -Value $completedQuests

    # Trigger quest completion event
    Send-GameEvent -EventType "quest.completed" -Data @{
        PlayerId = $PlayerId
        QuestId = $QuestId
        Rewards = $QuestRewards
    }

    # Save progress
    Save-GameState -SaveName "quest_completed_$QuestId"
}
```

## Real-time Synchronization

### PowerShell to JavaScript Communication

```powershell
# Export state for browser
function Send-StateToClient {
    param([string[]]$EntityIds = @())

    $exportData = Export-StateForBrowser -EntityIds $EntityIds -Format "JSON"

    # Send via HTTP endpoint, WebSocket, or file
    $response = @{
        Type = "StateUpdate"
        Data = $exportData
        Timestamp = Get-Date
    }

    # Example: Save to file for web server pickup
    $response | ConvertTo-Json -Depth 20 | Set-Content ".\www\state_update.json"

    # Or send via HTTP
    # Invoke-RestMethod -Uri "http://localhost:8080/api/state" -Method POST -Body $exportData -ContentType "application/json"
}

# Handle incoming browser state
function Receive-StateFromClient {
    param([string]$BrowserData)

    $syncResult = Import-StateFromBrowser -BrowserData $BrowserData -ValidateBeforeImport $true

    if ($syncResult.Success) {
        Write-Host "✅ Browser state synchronized: $($syncResult.ImportedEntities) entities updated"

        # Broadcast updates to other clients if needed
        Send-StateToClient
    }
    else {
        Write-Warning "❌ Browser state sync failed: $($syncResult.Error)"
    }
}
```

### JavaScript to PowerShell Communication

```javascript
// Browser state synchronization
class PowerShellSync {
    constructor(stateManager) {
        this.stateManager = stateManager;
        this.syncEndpoint = '/api/state';
        this.pollInterval = 5000; // 5 seconds

        this.startPolling();
    }

    async sendStateToPowerShell() {
        try {
            const exportData = this.stateManager.exportForPowerShell();

            const response = await fetch(this.syncEndpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(exportData)
            });

            if (response.ok) {
                const result = await response.json();
                console.log('State sent to PowerShell:', result);
                return result;
            } else {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
        } catch (error) {
            console.error('Failed to send state to PowerShell:', error);
            throw error;
        }
    }

    async receiveStateFromPowerShell() {
        try {
            const response = await fetch(`${this.syncEndpoint}/latest`);

            if (response.ok) {
                const powershellData = await response.json();
                const result = await this.stateManager.importFromPowerShell(powershellData);
                console.log('State received from PowerShell:', result);
                return result;
            }
        } catch (error) {
            console.error('Failed to receive state from PowerShell:', error);
        }
    }

    startPolling() {
        setInterval(async () => {
            await this.receiveStateFromPowerShell();
        }, this.pollInterval);
    }
}
```

## Advanced Features

### Conflict Resolution

```powershell
# Advanced conflict resolution
function Resolve-StateConflicts {
    param(
        [hashtable]$BrowserState,
        [string]$ResolutionStrategy = "Interactive"
    )

    switch ($ResolutionStrategy) {
        "Interactive" {
            # Present conflicts to user for manual resolution
            $conflicts = Find-StateConflicts -BrowserState $BrowserState
            foreach ($conflict in $conflicts) {
                $choice = Read-Host "Conflict in $($conflict.EntityId).$($conflict.Property): PowerShell=($($conflict.PowerShellValue)) vs Browser=($($conflict.BrowserValue)). Choose (P)owerShell or (B)rowser"
                if ($choice -eq "B") {
                    Update-GameEntityState -EntityId $conflict.EntityId -Property $conflict.Property -Value $conflict.BrowserValue
                }
            }
        }
        "PowerShellWins" {
            # Keep PowerShell state, ignore browser changes
            Write-Host "Conflict resolution: PowerShell state preserved"
        }
        "BrowserWins" {
            # Accept all browser changes
            Import-StateFromBrowser -BrowserData ($BrowserState | ConvertTo-Json -Depth 20) -ValidateBeforeImport $false
        }
        "Merge" {
            # Smart merge based on timestamps and change types
            $mergeResult = Merge-BrowserState -BrowserState $BrowserState
            Write-Host "Merged $($mergeResult.UpdatedEntities.Count) entities with $($mergeResult.ConflictCount) conflicts"
        }
    }
}
```

### Performance Optimization

```javascript
// Performance optimization techniques
class OptimizedStateManager extends StateManager {
    constructor(config) {
        super(config);
        this.batchQueue = [];
        this.batchTimeout = null;
        this.batchSize = 50;
        this.batchDelay = 100; // ms
    }

    // Batched state updates
    updateEntityStateBatched(entityId, property, value, changeType = 'Update') {
        this.batchQueue.push({ entityId, property, value, changeType });

        if (this.batchQueue.length >= this.batchSize) {
            this.processBatch();
        } else if (!this.batchTimeout) {
            this.batchTimeout = setTimeout(() => this.processBatch(), this.batchDelay);
        }
    }

    processBatch() {
        if (this.batchQueue.length === 0) return;

        const batch = [...this.batchQueue];
        this.batchQueue = [];

        if (this.batchTimeout) {
            clearTimeout(this.batchTimeout);
            this.batchTimeout = null;
        }

        // Process all updates
        batch.forEach(update => {
            super.updateEntityState(update.entityId, update.property, update.value, update.changeType);
        });

        console.log(`Processed batch of ${batch.length} state updates`);
    }

    // Delta synchronization
    getSyncDelta(lastSyncTime) {
        const delta = {
            entities: {},
            deletedEntities: [],
            timestamp: new Date()
        };

        this.state.trackers.forEach((tracker, entityId) => {
            const changes = tracker.getChangesSince(lastSyncTime);
            if (changes.changeCount > 0) {
                delta.entities[entityId] = {
                    entityType: tracker.entityType,
                    changes: changes.changes,
                    currentState: tracker.currentState
                };
            }
        });

        return delta;
    }
}
```

### Data Validation and Security

```powershell
# Enhanced validation and security
function Validate-EntityState {
    param(
        [string]$EntityType,
        [hashtable]$State
    )

    $validation = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
        SecurityIssues = @()
    }

    switch ($EntityType) {
        "Player" {
            # Validate player-specific constraints
            if ($State.Level -lt 1 -or $State.Level -gt 100) {
                $validation.IsValid = $false
                $validation.Errors += "Player level must be between 1 and 100"
            }

            if ($State.Currency -lt 0) {
                $validation.IsValid = $false
                $validation.Errors += "Player currency cannot be negative"
            }

            if ($State.Experience -lt 0) {
                $validation.IsValid = $false
                $validation.Errors += "Player experience cannot be negative"
            }

            # Security checks
            if ($State.Currency -gt 1000000) {
                $validation.SecurityIssues += "Suspicious currency amount detected"
            }
        }

        "Item" {
            if ($State.Value -lt 0) {
                $validation.IsValid = $false
                $validation.Errors += "Item value cannot be negative"
            }

            if ($State.Durability -gt $State.MaxDurability) {
                $validation.IsValid = $false
                $validation.Errors += "Item durability cannot exceed maximum"
            }
        }
    }

    return $validation
}
```

## Best Practices

### 1. State Management Patterns

```powershell
# Use consistent entity naming
$entityId = "$EntityType_$UniqueIdentifier"  # e.g., "player_001", "item_sword_123"

# Always validate before state changes
$validation = Validate-EntityState -EntityType $EntityType -State $NewState
if (-not $validation.IsValid) {
    throw "Invalid state: $($validation.Errors -join '; ')"
}

# Use descriptive change types
Update-GameEntityState -EntityId $EntityId -Property $Property -Value $Value -ChangeType "LevelUp"
```

### 2. Error Handling

```javascript
// Robust error handling
async function safeStateOperation(operation, fallback = null) {
    try {
        return await operation();
    } catch (error) {
        console.error('State operation failed:', error);

        // Log error for debugging
        stateManager.emit('stateError', {
            error: error.message,
            operation: operation.name,
            timestamp: new Date()
        });

        // Return fallback or rethrow
        if (fallback !== null) {
            return fallback;
        }
        throw error;
    }
}
```

### 3. Performance Monitoring

```powershell
# Monitor state manager performance
function Monitor-StatePerformance {
    $stats = Get-StateStatistics

    if ($stats.Performance.AverageSaveTime -gt 1000) {
        Write-Warning "Save times are getting slow: $($stats.Performance.AverageSaveTime)ms average"
    }

    if ($stats.Performance.ErrorCount -gt 0) {
        Write-Warning "State errors detected: $($stats.Performance.ErrorCount) total"
    }

    if ($stats.TrackedEntities -gt 1000) {
        Write-Information "Large entity count: $($stats.TrackedEntities) entities tracked"
    }
}
```

## Testing and Validation

### Unit Testing Examples

```powershell
# PowerShell unit tests
Describe "StateManager Tests" {
    BeforeEach {
        Initialize-StateManager
    }

    It "Should register entities correctly" {
        $result = Register-GameEntity -EntityId "test_001" -EntityType "Player" -InitialState @{ Name = "Test" }
        $result.Success | Should -Be $true
    }

    It "Should save and load state" {
        Register-GameEntity -EntityId "test_001" -EntityType "Player" -InitialState @{ Level = 1 }
        $saveResult = Save-GameState -SaveName "test_save"
        $saveResult.Success | Should -Be $true

        $loadResult = Load-GameState -SaveName "test_save"
        $loadResult.Success | Should -Be $true
    }

    AfterEach {
        $Global:StateManager.Cleanup()
    }
}
```

```javascript
// JavaScript unit tests
describe('StateManager', () => {
    let stateManager;

    beforeEach(() => {
        stateManager = new StateManager();
    });

    test('should register entities correctly', () => {
        const result = stateManager.registerEntity('test_001', 'Player', { name: 'Test' });
        expect(result.success).toBe(true);
    });

    test('should save and load state', async () => {
        stateManager.registerEntity('test_001', 'Player', { level: 1 });

        const saveResult = await stateManager.saveGameState('test_save');
        expect(saveResult.success).toBe(true);

        const loadResult = await stateManager.loadGameState('test_save');
        expect(loadResult.success).toBe(true);
    });
});
```

## Conclusion

This comprehensive state management architecture provides:

✅ **Robust State Persistence** - Reliable save/load with compression and validation
✅ **Real-time Synchronization** - Seamless PowerShell ↔ JavaScript communication
✅ **Change Tracking** - Complete audit trail with conflict resolution
✅ **Performance Monitoring** - Detailed metrics and optimization
✅ **Scalable Architecture** - Supports thousands of entities efficiently
✅ **Developer Friendly** - Simple APIs with comprehensive error handling

The system is production-ready and can be easily integrated into your existing game modules. Use the demo applications to test functionality and adapt the integration examples to your specific needs.
