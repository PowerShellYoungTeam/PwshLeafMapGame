# CoreGame Module

Enhanced core functionality for the PowerShell Leafmap RPG game system.

## Overview
The CoreGame module provides a comprehensive foundation with event-driven architecture, structured logging, dynamic command system, and persistent state management. All modules are designed to work together seamlessly with cross-module communication capabilities.

## Enhanced Modules

### 🎯 **GameLogging.psm1**
Centralized structured logging system with multi-output support.

**Key Features:**
- Multiple output targets (console, file, events)
- Structured data logging with JSON support
- Configurable log levels and filtering
- Performance monitoring integration
- Automatic verbose support via `$VerbosePreference`

**Quick Start:**
```powershell
Import-Module .\Modules\CoreGame\GameLogging.psm1

# Basic logging
Write-GameLog -Message "Player connected" -Level Info -Module "PlayerSystem"

# Structured data logging
Write-GameLog -Message "Combat result" -Level Debug -Module "Combat" -Data @{
    Attacker = "Player1"
    Defender = "Enemy2"
    Damage = 15
    Critical = $true
}

# Enable verbose output
$VerbosePreference = 'Continue'
Write-GameLog -Message "Debug info" -Level Debug -Module "AI"
```

### 🔄 **EventSystem.psm1**
Event-driven communication framework with JavaScript integration.

**Key Features:**
- Event registration with priority support
- Automatic event deduplication
- JavaScript/PowerShell communication bridge
- Performance monitoring and metrics
- Cross-module event propagation

**Quick Start:**
```powershell
Import-Module .\Modules\CoreGame\EventSystem.psm1

# Initialize event system
Initialize-EventSystem -GamePath "."

# Register event handler
Register-GameEvent -EventType "player.levelup" -ScriptBlock {
    param($Data, $Event)
    Write-Host "Player $($Data.Name) reached level $($Data.Level)!"
}

# Send events with priority and deduplication
Send-GameEvent -EventType "player.levelup" -Data @{ Name = "John"; Level = 5 } -Priority High
Send-GameEvent -EventType "system.status" -Data @{ Status = "OK" } -Deduplicate
```

### ⚡ **CommandRegistry.psm1**
Dynamic command registration and execution system.

**Key Features:**
- Runtime command registration
- Parameter validation and constraints
- Built-in help and documentation
- Performance metrics and monitoring
- Middleware and extensibility support

**Quick Start:**
```powershell
Import-Module .\Modules\CoreGame\CommandRegistry.psm1

# Initialize command registry
$registry = Initialize-CommandRegistry

# Create and register custom command
$cmd = New-CommandDefinition -Name "heal" -Module "magic" -Handler {
    param($Parameters, $Context)
    return @{
        Message = "Healed $($Parameters.Target) for $($Parameters.Amount) HP"
        Success = $true
    }
} -Description "Heal a target"

# Add parameters
$targetParam = New-CommandParameter -Name "Target" -Type "String" -Required $true
$amountParam = New-CommandParameter -Name "Amount" -Type "Int32" -DefaultValue 50
$cmd.AddParameter($targetParam)
$cmd.AddParameter($amountParam)

Register-GameCommand -Command $cmd

# Execute commands
Invoke-GameCommand -CommandName "magic.heal" -Parameters @{ Target = "Player1"; Amount = 75 }
```

### 💾 **StateManager.psm1**
Entity persistence and state management system.

**Key Features:**
- Automatic entity state tracking
- Save/load functionality with versioning
- Change detection and dirty tracking
- Entity lifecycle management
- Integration with DataModels for proper entity creation

**Quick Start:**
```powershell
Import-Module .\Modules\CoreGame\StateManager.psm1
Import-Module .\Modules\CoreGame\DataModels.psm1

# Initialize state manager
Initialize-StateManager -GameDataPath ".\gamedata.json"

# Create and register entities
$player = New-GameEntity @{
    id = "player1"
    type = "player"
    data = @{ name = "John"; level = 1; hp = 100 }
}

Register-Entity -Entity $player

# Save and load game state
Save-GameState -SaveName "checkpoint1"
$entities = Load-EntityCollection -SaveName "checkpoint1"
```

## Cross-Module Communication

The enhanced modules work together through the event system:

```powershell
# Example: Command that triggers events and logs results
Register-GameEvent -EventType "command.executed" -ScriptBlock {
    param($Data, $Event)
    Write-GameLog -Message "Command executed: $($Data.CommandName)" -Level Info -Module "CommandSystem" -Data $Data
}

# Commands automatically trigger events when executed
Invoke-GameCommand -CommandName "registry.listCommands"
```

## Verbose Output Control

All modules respect `$VerbosePreference` for detailed logging:

```powershell
# Enable verbose output globally
$VerbosePreference = 'Continue'

# Or for specific operations
& {
    $VerbosePreference = 'Continue'
    Initialize-EventSystem -GamePath "."
    Register-GameEvent -EventType "test" -ScriptBlock { }
}
```

## Error Handling

Comprehensive error handling with structured logging:

```powershell
try {
    Invoke-GameCommand -CommandName "nonexistent.command"
} catch {
    Write-GameLog -Message "Command execution failed" -Level Error -Module "GameEngine" -Data @{
        Command = "nonexistent.command"
        Error = $_.Exception.Message
    } -Exception $_
}
```

## Performance Monitoring

Built-in performance tracking across all modules:

```powershell
# Get command execution statistics
$stats = Invoke-GameCommand -CommandName "registry.getStatistics"
Write-Host "Average execution time: $($stats.AverageExecutionTime)ms"

# Monitor event system performance
$eventStats = Get-EventSystemStats
Write-Host "Events processed: $($eventStats.TotalEvents)"
```

## Migration Guide

### From Previous Versions

**Verbose Parameter Changes:**
- **Old:** `-Verbose` parameter on functions
- **New:** Use `$VerbosePreference = 'Continue'`

**Example Migration:**
```powershell
# Old approach (will cause errors)
# Initialize-EventSystem -GamePath "." -Verbose

# New approach
$VerbosePreference = 'Continue'
Initialize-EventSystem -GamePath "."
```

**StateManager Entity Requirements:**
- **Old:** Hashtables could be registered directly
- **New:** Must use `New-GameEntity` to create proper entity objects

```powershell
# Old approach (will cause errors)
# Register-Entity -Entity @{ id = "test"; data = @{} }

# New approach
$entity = New-GameEntity @{ id = "test"; type = "item"; data = @{} }
Register-Entity -Entity $entity
```

## Testing

Run the comprehensive test suite to validate all functionality:

```powershell
& .\Test-EnhancedModules.ps1
```

## Advanced Features

### Event Deduplication
```powershell
# Prevent duplicate events
Send-GameEvent -EventType "player.status" -Data @{ HP = 100 } -Deduplicate
Send-GameEvent -EventType "player.status" -Data @{ HP = 100 } -Deduplicate  # Ignored
```

### Command Middleware
```powershell
# Commands support validation and preprocessing
$cmd = New-CommandDefinition -Name "restricted" -Module "admin" -Handler {
    # Command logic
} -Middleware @("AuthenticationCheck", "RateLimiting")
```

### Structured Logging with Context
```powershell
Write-GameLog -Message "AI decision" -Level Debug -Module "AI" -Data @{
    EntityId = "npc_001"
    Decision = "attack"
    Confidence = 0.87
    Factors = @("player_nearby", "low_health")
}
```

---

**For detailed API documentation, use PowerShell's built-in help:**
```powershell
Get-Help Write-GameLog -Full
Get-Help Send-GameEvent -Examples
Get-Help Register-GameCommand -Detailed
```

=======