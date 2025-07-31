# Enhanced Modules Architecture Guide

## Overview

The PowerShell Leafmap Game enhanced modules provide a comprehensive foundation for game development with event-driven architecture, structured logging, dynamic commands, and persistent state management.

## Architecture Principles

### 1. Event-Driven Communication
All modules communicate through a centralized event system, reducing coupling and improving modularity.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GameLogging   │    │   EventSystem   │    │ CommandRegistry │
│                 │◄──►│                 │◄──►│                 │
│ • Multi-output  │    │ • Event routing │    │ • Dynamic cmds  │
│ • Structured    │    │ • Deduplication │    │ • Validation    │
│ • Performance   │    │ • Priority      │    │ • Documentation │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                        ▲                        ▲
         │                        │                        │
         └──────────────────────┬─┴────────────────────────┘
                                │
                    ┌─────────────────┐
                    │  StateManager   │
                    │                 │
                    │ • Entity mgmt   │
                    │ • Persistence   │
                    │ • Change track  │
                    └─────────────────┘
```

### 2. Verbose Parameter Migration

**Problem Solved:** Previous modules defined custom `-Verbose` parameters that conflicted with PowerShell's automatic `[CmdletBinding()]` common parameters.

**Solution:**
- Removed custom `-Verbose` parameters
- Use `$VerbosePreference` for verbose output control
- Standardized verbose logging across all modules

### 3. Cross-Module Integration

Modules are designed to work together seamlessly:

```powershell
# Command execution triggers events, which are logged
Invoke-GameCommand -CommandName "player.heal" -Parameters @{ Amount = 50 }
  ↓ (triggers event)
Send-GameEvent -EventType "command.executed" -Data @{ Command = "player.heal" }
  ↓ (logs via event handler)
Write-GameLog -Message "Command executed" -Level Info -Module "CommandSystem"
```

## Module Deep Dive

### GameLogging.psm1

**Purpose:** Centralized structured logging with multiple output targets.

**Key Enhancements:**
- **Multi-Output:** Console, file, and event logging simultaneously
- **Structured Data:** JSON support for complex data logging
- **Performance Integration:** Automatic timing and performance metrics
- **Verbose Support:** Respects `$VerbosePreference` globally

**Implementation Pattern:**
```powershell
function Write-GameLog {
    [CmdletBinding()]  # Provides automatic -Verbose support
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Level = "Info",
        [hashtable]$Data = @{}
    )

    # Use VerbosePreference instead of custom -Verbose parameter
    if ($VerbosePreference -eq 'Continue') {
        Write-Host "VERBOSE: $Message" -ForegroundColor Gray
    }
}
```

### EventSystem.psm1

**Purpose:** Event-driven communication with deduplication and priority support.

**Key Enhancements:**
- **Deduplication:** Prevents event spam with content-based deduplication
- **Priority System:** High/Normal/Low priority event processing
- **JavaScript Bridge:** Seamless PowerShell/JavaScript communication
- **Performance Monitoring:** Event processing metrics and timing

**Event Flow:**
```
Send-GameEvent → Deduplication Check → Priority Queue → Handler Execution → Logging
```

### CommandRegistry.psm1

**Purpose:** Dynamic command system with runtime registration and validation.

**Key Enhancements:**
- **Runtime Registration:** Commands can be added/removed during execution
- **Parameter Validation:** Type checking, constraints, and default values
- **Documentation Generation:** Automatic help and documentation
- **Performance Metrics:** Command execution timing and statistics

**Helper Function Pattern:**
```powershell
# Fixed array handling in helper functions
function New-CommandDefinition {
    $result = [CommandDefinition]::new($Name, $Module, $Handler)
    return $result  # Return single object, not array
}

# Usage requires explicit array handling
$cmd = New-CommandDefinition -Name "test" -Module "test" -Handler { }
$cmd = @($cmd)[0]  # Force single object if array returned
```

### StateManager.psm1

**Purpose:** Entity persistence and state management with change tracking.

**Key Enhancements:**
- **Entity Integration:** Requires proper GameEntity objects from DataModels
- **Change Tracking:** Automatic dirty state detection
- **Versioned Saves:** Multiple save slots with backup management
- **Performance Optimization:** Efficient serialization and loading

**Entity Creation Pattern:**
```powershell
# Must use DataModels for proper entity creation
Import-Module .\Modules\CoreGame\DataModels.psm1

$entity = New-GameEntity @{
    id = "unique-id"
    type = "entity-type"
    data = @{ /* entity data */ }
}

Register-Entity -Entity $entity  # Requires GameEntity object
```

## Best Practices

### 1. Verbose Output Control
```powershell
# Global verbose enable
$VerbosePreference = 'Continue'

# Scoped verbose enable
& {
    $VerbosePreference = 'Continue'
    Initialize-EventSystem -GamePath "."
}

# Check verbose preference in custom functions
if ($VerbosePreference -eq 'Continue') {
    Write-Host "Verbose output here"
}
```

### 2. Error Handling with Structured Logging
```powershell
try {
    $result = Invoke-GameCommand -CommandName "risky.operation"
} catch {
    Write-GameLog -Message "Operation failed" -Level Error -Module "GameEngine" -Data @{
        Operation = "risky.operation"
        ErrorType = $_.Exception.GetType().Name
        StackTrace = $_.ScriptStackTrace
    } -Exception $_

    # Also send error event for other modules to handle
    Send-GameEvent -EventType "error.operation" -Data @{
        Operation = "risky.operation"
        Error = $_.Exception.Message
    } -Priority High
}
```

### 3. Cross-Module Communication
```powershell
# Register cross-module event handlers
Register-GameEvent -EventType "player.*" -ScriptBlock {
    param($Data, $Event)
    Write-GameLog -Message "Player event: $($Event.EventType)" -Level Debug -Module "PlayerSystem" -Data $Data
}

# Send events from any module
Send-GameEvent -EventType "player.levelup" -Data @{
    PlayerId = "player1"
    NewLevel = 5
    Experience = 1250
} -Priority Normal
```

### 4. Performance Monitoring
```powershell
# Enable performance monitoring
$registry = Initialize-CommandRegistry -Configuration @{
    EnablePerformanceMonitoring = $true
}

# Get performance metrics
$stats = Invoke-GameCommand -CommandName "registry.getStatistics"
Write-Host "Commands executed: $($stats.CommandsExecuted)"
Write-Host "Average execution time: $($stats.AverageExecutionTime)ms"
```

## Testing Strategy

The enhanced modules include comprehensive testing:

```powershell
# Run full test suite
& .\Test-EnhancedModules.ps1

# Test specific areas
& {
    Import-Module .\Modules\CoreGame\GameLogging.psm1 -Force
    Write-GameLog -Message "Test message" -Level Info -Module "Test"
}
```

## Migration Checklist

### From Previous Versions

- [ ] **Remove `-Verbose` parameters** from function calls
- [ ] **Use `$VerbosePreference = 'Continue'`** for verbose output
- [ ] **Import DataModels module** when using StateManager
- [ ] **Use `New-GameEntity`** instead of direct hashtables
- [ ] **Handle array returns** from helper functions explicitly
- [ ] **Update documentation** to reflect new parameter patterns
- [ ] **Test cross-module communication** functionality

### Validation Steps

1. **Parameter Validation:** Ensure no custom `-Verbose` parameters in calls
2. **Entity Creation:** Verify all entities use `New-GameEntity`
3. **Module Loading:** Check proper module import order
4. **Event Flow:** Test event communication between modules
5. **Performance:** Verify performance monitoring works
6. **Persistence:** Test save/load functionality
7. **Error Handling:** Validate error logging and recovery

## Troubleshooting

### Common Issues

**Issue:** "Parameter set cannot be resolved"
- **Cause:** Using removed `-Verbose` parameter
- **Fix:** Remove `-Verbose` and use `$VerbosePreference = 'Continue'`

**Issue:** "Cannot register entity"
- **Cause:** Passing hashtable instead of GameEntity
- **Fix:** Use `New-GameEntity` to create proper entity objects

**Issue:** "Helper function returns array"
- **Cause:** PowerShell array behavior in helper functions
- **Fix:** Use `@($result)[0]` to force single object

**Issue:** "Module not found"
- **Cause:** Missing module imports for cross-module features
- **Fix:** Import required modules (GameLogging, DataModels, etc.)

## Future Enhancements

### Planned Features
- **Command Middleware:** Pre/post execution hooks
- **Event Filters:** Advanced event filtering and routing
- **Distributed Logging:** Network logging support
- **Hot Reloading:** Dynamic module reloading
- **Plugin System:** Third-party module integration

### Extension Points
- **Custom Event Handlers:** Module-specific event processing
- **Command Validators:** Custom parameter validation
- **State Serializers:** Custom entity serialization
- **Performance Collectors:** Custom metrics collection

---

This architecture provides a solid foundation for building complex PowerShell game systems with proper separation of concerns, excellent testability, and comprehensive observability.
