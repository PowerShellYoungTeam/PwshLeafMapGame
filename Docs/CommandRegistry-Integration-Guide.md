# PowerShell Leafmap Game - Command Registry System Documentation

## Overview

The Command Registry System is a comprehensive, modular architecture that enables game modules to register commands dynamically with the Communication Bridge. This system provides:

- **Dynamic Command Registration**: Modules can register commands at runtime
- **Parameter Validation**: Automatic validation with type checking and constraints
- **Command Namespacing**: Prevent conflicts with module-based naming (`module.command`)
- **Access Control**: Role-based permissions for commands
- **Middleware Support**: Pre/post execution hooks for cross-cutting concerns
- **Auto Documentation**: Generate API documentation automatically
- **Performance Monitoring**: Built-in telemetry and statistics

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Communication Bridge                        │
├─────────────────────────────────────────────────────────────────┤
│  HTTP Server  │  Event System  │  Command Execution Engine     │
└─────────────────┬───────────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────────┐
│                    Command Registry                             │
├─────────────────────────────────────────────────────────────────┤
│ • Command Definitions        • Parameter Validation             │
│ • Middleware Pipeline       • Access Control                   │
│ • Documentation Generator   • Performance Monitoring           │
└─────────────────┬───────────────────────────────────────────────┘
                  │
        ┌─────────┼─────────┐
        │         │         │
┌───────▼───┐ ┌───▼───┐ ┌───▼────┐
│ Drone     │ │Faction│ │ Quest  │
│ System    │ │System │ │ System │
│ Module    │ │Module │ │ Module │
└───────────┘ └───────┘ └────────┘
```

## Core Components

### 1. CommandRegistry.psm1

The central registry that manages all commands:

```powershell
# Initialize the registry
Initialize-CommandRegistry -Configuration @{
    EnableAccessControl = $true
    EnableTelemetry = $true
    EnableValidation = $true
}

# Register a command
$command = New-CommandDefinition -Name "launch" -Module "drone" -Handler {
    param($Parameters, $Context)
    # Command implementation
} -Description "Launch a new drone" -Category "Deployment"

Register-GameCommand -Command $command
```

### 2. Command Definition Structure

Commands are defined using the `CommandDefinition` class:

```powershell
class CommandDefinition {
    [string]$Name           # Command name (e.g., "launch")
    [string]$FullName       # Full name (e.g., "drone.launch")
    [string]$Module         # Module name (e.g., "drone")
    [string]$Description    # Human-readable description
    [string]$Category       # Logical grouping
    [AccessLevel]$AccessLevel # Public, Protected, Admin, System
    [List[CommandParameter]]$Parameters # Parameter definitions
    [scriptblock]$Handler   # Execution logic
    [List[CommandMiddleware]]$Middleware # Command-specific middleware
    [hashtable]$Examples    # Usage examples
    [string]$Version        # Command version
}
```

### 3. Parameter Validation

Robust parameter validation with multiple constraint types:

```powershell
# Define a parameter with validation
$speedParam = New-CommandParameter -Name "Speed" -Type ([ParameterType]::Integer) -Required $true -Description "Drone speed (1-200)"

# Add constraints
$speedParam.AddConstraint((New-ParameterConstraint -Type ([ConstraintType]::MinValue) -Value 1 -ErrorMessage "Speed must be at least 1"))
$speedParam.AddConstraint((New-ParameterConstraint -Type ([ConstraintType]::MaxValue) -Value 200 -ErrorMessage "Speed cannot exceed 200"))

# Custom validation
$customConstraint = New-ParameterConstraint -CustomValidator {
    param($value)
    return $value % 5 -eq 0  # Must be divisible by 5
} -CustomErrorMessage "Speed must be divisible by 5"

$speedParam.AddConstraint($customConstraint)
```

### 4. Middleware System

Implement cross-cutting concerns with middleware:

```powershell
# Create custom middleware
$authMiddleware = New-CommandMiddleware -Name "CustomAuth" -Priority 5
$authMiddleware.SetPreExecute({
    param($Context)
    if (-not $Context.Context.UserToken) {
        throw "Authentication required"
    }
})

# Add to command
$command.AddMiddleware($authMiddleware)
```

Built-in middleware includes:
- **Telemetry**: Performance monitoring and event publishing
- **Validation**: Parameter validation and type checking
- **AccessControl**: Role-based permission checking

## Module Integration Guide

### Creating a Command-Enabled Module

1. **Import Required Modules**
```powershell
Import-Module (Join-Path $PSScriptRoot "..\CoreGame\CommandRegistry.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\CoreGame\EventSystem.psm1") -Force
```

2. **Define Command Registration Function**
```powershell
function Register-ModuleCommands {
    if (-not $script:GlobalCommandRegistry) {
        Write-Warning "Command Registry not available"
        return
    }

    # Define commands here...
}
```

3. **Create Command Definitions**
```powershell
# Basic command
$simpleCmd = New-CommandDefinition -Name "action" -Module "mymodule" -Handler {
    param($Parameters, $Context)
    return @{ Success = $true; Message = "Action completed" }
} -Description "Perform a simple action" -Category "Basic"

Register-GameCommand -Command $simpleCmd
```

4. **Add Parameters**
```powershell
# Command with parameters
$complexCmd = New-CommandDefinition -Name "complexAction" -Module "mymodule" -Handler {
    param($Parameters, $Context)

    # Access validated parameters
    $entityId = $Parameters.EntityId
    $amount = $Parameters.Amount

    # Implementation logic...
    return @{ Success = $true; EntityId = $entityId; ProcessedAmount = $amount }
} -Description "Perform a complex action" -Category "Advanced"

# Add required parameter
$complexCmd.AddParameter((New-CommandParameter -Name "EntityId" -Type ([ParameterType]::String) -Required $true -Description "Entity to process"))

# Add optional parameter with constraints
$amountParam = (New-CommandParameter -Name "Amount" -Type ([ParameterType]::Integer) -Description "Amount to process" -DefaultValue 1)
$amountParam.AddConstraint((New-ParameterConstraint -Type ([ConstraintType]::MinValue) -Value 1))
$amountParam.AddConstraint((New-ParameterConstraint -Type ([ConstraintType]::MaxValue) -Value 1000))
$complexCmd.AddParameter($amountParam)

Register-GameCommand -Command $complexCmd
```

5. **Initialize Module**
```powershell
function Initialize-MyModule {
    param([hashtable]$Configuration = @{})

    try {
        # Module initialization logic...

        # Register commands
        Register-ModuleCommands

        Write-Host "MyModule initialized successfully" -ForegroundColor Green
        return @{ Success = $true; CommandsRegistered = 2 }
    }
    catch {
        Write-Error "Failed to initialize MyModule: $($_.Exception.Message)"
        throw
    }
}
```

### Example: Drone System Module

Complete example from the included DroneSystem module:

```powershell
# Launch Drone Command
$launchDroneCmd = New-CommandDefinition -Name "launch" -Module "drone" -Handler {
    param($Parameters, $Context)

    $droneName = if ($Parameters.Name) { $Parameters.Name } else { "Drone-$($script:DroneSystemState.DroneCounter + 1)" }

    if ($script:DroneSystemState.ActiveDrones.Count -ge $script:DroneSystemConfig.MaxDrones) {
        throw "Maximum drone limit reached ($($script:DroneSystemConfig.MaxDrones))"
    }

    $drone = [Drone]::new($droneName)

    if ($Parameters.Position) {
        $drone.Position = $Parameters.Position
    }

    if ($Parameters.Speed) {
        $drone.Speed = [Math]::Min($Parameters.Speed, 200)
    }

    $script:DroneSystemState.ActiveDrones[$drone.Id] = $drone
    $script:DroneSystemState.DroneCounter++

    # Publish event
    Publish-GameEvent -EventType "drone.launched" -Data @{
        DroneId = $drone.Id
        DroneName = $drone.Name
        Position = $drone.Position
    }

    return $drone.GetStatus()
} -Description "Launch a new drone" -Category "Deployment"

# Add parameters
$launchDroneCmd.AddParameter((New-CommandParameter -Name "Name" -Type ([ParameterType]::String) -Description "Custom name for the drone"))
$launchDroneCmd.AddParameter((New-CommandParameter -Name "Position" -Type ([ParameterType]::Object) -Description "Initial position {X, Y, Z}"))

$speedParam = (New-CommandParameter -Name "Speed" -Type ([ParameterType]::Integer) -Description "Drone speed (1-200)")
$speedParam.AddConstraint((New-ParameterConstraint -Type ([ConstraintType]::MinValue) -Value 1 -ErrorMessage "Speed must be at least 1"))
$speedParam.AddConstraint((New-ParameterConstraint -Type ([ConstraintType]::MaxValue) -Value 200 -ErrorMessage "Speed cannot exceed 200"))
$launchDroneCmd.AddParameter($speedParam)

# Add examples
$launchDroneCmd.AddExample("BasicLaunch", @{
    Description = "Launch a basic drone"
    Parameters = @{}
    ExpectedResult = "Drone status object"
})

$launchDroneCmd.AddExample("CustomLaunch", @{
    Description = "Launch a drone with custom settings"
    Parameters = @{
        Name = "Scout-Alpha"
        Position = @{ X = 100; Y = 50; Z = 120 }
        Speed = 75
    }
    ExpectedResult = "Drone status object with custom settings"
})

Register-GameCommand -Command $launchDroneCmd
```

## JavaScript Client Integration

### Basic Usage

```javascript
// Initialize the client
await GameCommands.init('http://localhost:8082');

// Discover available commands
const discovery = await GameCommands.discover();
console.log('Available commands:', discovery.Commands);

// Execute a command
const result = await GameCommands.execute('drone.launch', {
    Name: 'TestDrone',
    Position: { X: 100, Y: 50, Z: 120 },
    Speed: 85
});

if (result.Success) {
    console.log('Drone launched:', result.Data);
} else {
    console.error('Launch failed:', result.Error);
}
```

### Advanced Features

```javascript
// Get command documentation
const docs = await GameCommands.docs('drone.launch');

// Execute with validation and retry
const result = await GameCommands.execute('drone.move', {
    DroneId: 'drone-id-here',
    Position: { X: 200, Y: 150, Z: 100 }
}, {
    timeout: 10000,
    retries: 2,
    validateParameters: true
});

// Batch execution
const commands = [
    { command: 'drone.launch', parameters: { Name: 'Drone1' } },
    { command: 'drone.launch', parameters: { Name: 'Drone2' } },
    { command: 'drone.list', parameters: {} }
];

const results = await GameCommands.client.executeBatch(commands, {
    parallel: true,
    stopOnError: false
});

// Generate shortcut functions
const shortcuts = await GameCommands.shortcuts();
// Now you can call: shortcuts.drone.launch({ Name: 'TestDrone' })
```

## HTTP API Endpoints

The Communication Bridge exposes several HTTP endpoints for command interaction:

### Command Execution
- **POST** `/command` - Execute a command
  ```json
  {
    "Id": "unique-command-id",
    "Command": "drone.launch",
    "Parameters": {
      "Name": "TestDrone",
      "Speed": 85
    },
    "Timestamp": "2025-07-28T10:30:00Z"
  }
  ```

### Command Discovery
- **GET** `/commands` - List available commands
  - Query parameters: `module`, `includeProtected`, `includeAdmin`

### Documentation
- **GET** `/commands/docs` - Get command documentation
  - Query parameters: `command`, `module`, `format`

### System Status
- **GET** `/status` - Get bridge and registry status

### Event Stream
- **GET** `/events` - Server-sent events for real-time updates

## Command Categories and Patterns

### Common Command Categories
- **Core**: Basic system operations (save, load, status)
- **Deployment**: Resource creation and initialization
- **Management**: Resource lifecycle operations
- **Navigation**: Movement and positioning
- **Reconnaissance**: Information gathering
- **Operations**: Mission and task management
- **Diagnostics**: System monitoring and debugging

### Naming Conventions
- Use descriptive, action-oriented names
- Follow module.command pattern
- Use camelCase for multi-word commands
- Examples: `drone.launch`, `faction.joinFaction`, `quest.startQuest`

### Parameter Patterns
- Use consistent parameter names across modules (`Id`, `Name`, `Position`)
- Provide meaningful defaults where appropriate
- Include comprehensive validation
- Use objects for complex parameters

## Error Handling

### Command Execution Errors
```powershell
# In command handler
if (-not $Parameters.EntityId) {
    throw "EntityId parameter is required"
}

$entity = Get-Entity -Id $Parameters.EntityId
if (-not $entity) {
    throw "Entity not found: $($Parameters.EntityId)"
}
```

### Client-Side Error Handling
```javascript
try {
    const result = await GameCommands.execute('command.name', parameters);
    if (!result.Success) {
        console.error('Command failed:', result.Error);
    }
} catch (error) {
    console.error('Execution error:', error.message);
}
```

## Performance Optimization

### Best Practices
1. **Use Validation**: Enable parameter validation to catch errors early
2. **Implement Caching**: Cache frequently accessed data
3. **Batch Operations**: Use batch execution for multiple commands
4. **Monitor Performance**: Use built-in telemetry for optimization
5. **Optimize Handlers**: Keep command handlers lightweight and focused

### Telemetry and Monitoring
```powershell
# Get registry statistics
$stats = Get-CommandRegistryStatistics

# Access metrics
Write-Host "Commands executed: $($stats.CommandsExecuted)"
Write-Host "Average execution time: $($stats.AverageExecutionTime)ms"
Write-Host "Error rate: $(($stats.ExecutionErrors / $stats.CommandsExecuted) * 100)%"
```

## Testing and Validation

### Testing Commands
```powershell
# Test command registration
$testResult = Invoke-GameCommand -CommandName "registry.listCommands"
$commands = $testResult.Data.Commands

# Test parameter validation
try {
    Invoke-GameCommand -CommandName "drone.launch" -Parameters @{ Speed = 300 } # Should fail
} catch {
    Write-Host "Validation working: $($_.Exception.Message)"
}
```

### Integration Testing
```javascript
// Test client integration
const client = new GameCommandClient('http://localhost:8082');
const status = await client.checkBridgeConnection();
console.assert(status !== null, 'Bridge should be available');

const commands = await client.discoverCommands();
console.assert(commands.Commands.length > 0, 'Commands should be available');
```

## Deployment Guide

### Development Environment
1. Import all required modules
2. Initialize systems in order: EventSystem → StateManager → CommandRegistry → CommunicationBridge
3. Load and initialize game modules
4. Start the Communication Bridge
5. Open the demo interface for testing

### Production Considerations
1. **Security**: Enable authentication and authorization
2. **Logging**: Configure comprehensive logging
3. **Monitoring**: Set up performance monitoring
4. **Backup**: Implement command audit trails
5. **Scalability**: Consider load balancing for high-traffic scenarios

### Configuration Options
```powershell
$config = @{
    # Registry settings
    EnableAccessControl = $true
    EnableTelemetry = $true
    EnableValidation = $true
    MaxExecutionTime = 30000

    # Bridge settings
    HttpPort = 8080
    HttpHost = "0.0.0.0"  # For external access
    LoggingEnabled = $true
    DebugMode = $false    # Disable in production
}
```

## Troubleshooting

### Common Issues

1. **Commands Not Registered**
   - Ensure CommandRegistry is initialized before module loading
   - Check module initialization order
   - Verify `Register-GameCommand` is called

2. **Parameter Validation Failures**
   - Check parameter types match definitions
   - Verify constraint values are within bounds
   - Ensure required parameters are provided

3. **Connection Issues**
   - Verify bridge is running on correct port
   - Check firewall settings
   - Confirm CORS configuration for web clients

4. **Performance Issues**
   - Monitor command execution times
   - Check for blocking operations in handlers
   - Consider middleware optimization

### Debug Tools
```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Check registry state
$registry = $script:GlobalCommandRegistry
Write-Host "Commands registered: $($registry.Commands.Count)"

# Monitor command execution
Register-GameEvent -EventType "command.executed" -ScriptBlock {
    param($EventData)
    Write-Host "Command executed: $($EventData.Data.Command) in $($EventData.Data.ExecutionTime)ms"
}
```

## Conclusion

The Command Registry System provides a robust, scalable foundation for modular game development. By following the patterns and practices outlined in this documentation, you can create well-structured, maintainable game modules that integrate seamlessly with the Communication Bridge and provide excellent developer and player experiences.
