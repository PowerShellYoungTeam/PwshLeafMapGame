# PowerShell Leafmap Game - Commands Documentation

## Overview

This document provides comprehensive documentation for all available commands in the PowerShell Leafmap Game system. Commands are organized by module and include detailed information about parameters, usage examples, and expected outputs.

## Command Structure

### Naming Convention
Commands follow the pattern: `module.commandName`

### Parameter Types
- **String**: Text values
- **Integer**: Whole numbers
- **Float**: Decimal numbers
- **Boolean**: True/false values
- **Object**: Complex data structures
- **Array**: Lists of values

### Access Levels
- **Public**: Available to all users
- **Protected**: Requires elevated permissions
- **Admin**: Administrative access required
- **System**: Internal system use only

## Core System Commands

### Registry Module Commands

#### registry.listCommands
**Description**: List all available commands with optional filtering

**Parameters**:
- `Module` (String, Optional): Filter commands by module name
- `IncludeProtected` (Boolean, Optional): Include protected commands (default: false)
- `IncludeAdmin` (Boolean, Optional): Include admin commands (default: false)

**Access Level**: Public

**Examples**:
```powershell
# List all public commands
Invoke-GameCommand -CommandName "registry.listCommands"

# List commands for a specific module
Invoke-GameCommand -CommandName "registry.listCommands" -Parameters @{ Module = "player" }

# List all commands including protected ones
Invoke-GameCommand -CommandName "registry.listCommands" -Parameters @{ IncludeProtected = $true }
```

**Output**:
```json
{
  "Commands": ["module.command1", "module.command2"],
  "TotalCount": 2,
  "AccessLevel": "Public",
  "FilterModule": null
}
```

#### registry.getDocumentation
**Description**: Get comprehensive command documentation

**Parameters**:
- `CommandName` (String, Optional): Specific command to document
- `Module` (String, Optional): Module to document
- `Format` (String, Optional): Documentation format (JSON, Markdown, XML) (default: "JSON")

**Access Level**: Public

**Examples**:
```powershell
# Get documentation for a specific command
Invoke-GameCommand -CommandName "registry.getDocumentation" -Parameters @{ CommandName = "player.move" }

# Get documentation for an entire module
Invoke-GameCommand -CommandName "registry.getDocumentation" -Parameters @{ Module = "player"; Format = "Markdown" }
```

**Output**:
```json
{
  "CommandName": "player.move",
  "Description": "Move player to a new location",
  "Parameters": [...],
  "Examples": [...],
  "AccessLevel": "Public"
}
```

#### registry.getStatistics
**Description**: Get detailed registry performance and usage statistics

**Access Level**: Public

**Examples**:
```powershell
Invoke-GameCommand -CommandName "registry.getStatistics"
```

**Output**:
```json
{
  "TotalCommands": 45,
  "CommandsExecuted": 1234,
  "AverageExecutionTime": 50.2,
  "MostUsedCommands": [...],
  "ErrorRate": 0.02
}
```

#### registry.getPerformanceMetrics
**Description**: Get detailed performance metrics for commands

**Parameters**:
- `CommandName` (String, Optional): Specific command to analyze
- `TimeRange` (String, Optional): Time range for metrics (1h, 24h, 7d) (default: "1h")

**Access Level**: Public

**Examples**:
```powershell
# Get performance metrics for all commands in the last hour
Invoke-GameCommand -CommandName "registry.getPerformanceMetrics"

# Get performance metrics for a specific command over the last 24 hours
Invoke-GameCommand -CommandName "registry.getPerformanceMetrics" -Parameters @{ CommandName = "player.move"; TimeRange = "24h" }
```

## Player Module Commands

### player.create
**Description**: Create a new player character

**Parameters**:
- `Name` (String, Required): Player character name
- `StartingLocation` (String, Optional): Initial location (default: "spawn")
- `CharacterClass` (String, Optional): Character class (default: "explorer")

**Access Level**: Public

**Examples**:
```powershell
# Create a basic player
Invoke-GameCommand -CommandName "player.create" -Parameters @{ Name = "John" }

# Create a player with specific settings
Invoke-GameCommand -CommandName "player.create" -Parameters @{
    Name = "Jane"
    StartingLocation = "city_center"
    CharacterClass = "warrior"
}
```

### player.move
**Description**: Move player to a new location

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `Direction` (String, Optional): Movement direction (north, south, east, west)
- `LocationId` (String, Optional): Specific location to move to
- `Distance` (Float, Optional): Distance to move in specified direction

**Access Level**: Public

**Examples**:
```powershell
# Move player north
Invoke-GameCommand -CommandName "player.move" -Parameters @{
    PlayerId = "player123"
    Direction = "north"
}

# Move to specific location
Invoke-GameCommand -CommandName "player.move" -Parameters @{
    PlayerId = "player123"
    LocationId = "location456"
}
```

### player.getInfo
**Description**: Get comprehensive player information

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `IncludeInventory` (Boolean, Optional): Include inventory details (default: true)
- `IncludeStats` (Boolean, Optional): Include player statistics (default: true)

**Access Level**: Public

**Examples**:
```powershell
# Get basic player info
Invoke-GameCommand -CommandName "player.getInfo" -Parameters @{ PlayerId = "player123" }

# Get player info without inventory
Invoke-GameCommand -CommandName "player.getInfo" -Parameters @{
    PlayerId = "player123"
    IncludeInventory = $false
}
```

## World Module Commands

### world.getLocation
**Description**: Get detailed information about a specific location

**Parameters**:
- `LocationId` (String, Required): Location identifier
- `IncludeNearby` (Boolean, Optional): Include nearby locations (default: false)
- `Radius` (Float, Optional): Search radius for nearby locations (default: 1.0)

**Access Level**: Public

**Examples**:
```powershell
# Get location info
Invoke-GameCommand -CommandName "world.getLocation" -Parameters @{ LocationId = "location123" }

# Get location with nearby areas
Invoke-GameCommand -CommandName "world.getLocation" -Parameters @{
    LocationId = "location123"
    IncludeNearby = $true
    Radius = 2.5
}
```

### world.findNearby
**Description**: Find locations near specific coordinates

**Parameters**:
- `Latitude` (Float, Required): Latitude coordinate
- `Longitude` (Float, Required): Longitude coordinate
- `Radius` (Float, Optional): Search radius in kilometers (default: 1.0)
- `LocationType` (String, Optional): Filter by location type

**Access Level**: Public

**Examples**:
```powershell
# Find nearby locations
Invoke-GameCommand -CommandName "world.findNearby" -Parameters @{
    Latitude = 40.7128
    Longitude = -74.0060
    Radius = 5.0
}

# Find specific type of locations
Invoke-GameCommand -CommandName "world.findNearby" -Parameters @{
    Latitude = 40.7128
    Longitude = -74.0060
    LocationType = "shop"
}
```

### world.generateLocations
**Description**: Generate new locations based on parameters

**Parameters**:
- `Count` (Integer, Optional): Number of locations to generate (default: 10)
- `LocationType` (String, Optional): Type of locations to generate
- `CenterLatitude` (Float, Optional): Center latitude for generation
- `CenterLongitude` (Float, Optional): Center longitude for generation
- `SpreadRadius` (Float, Optional): Maximum distance from center (default: 5.0)

**Access Level**: Protected

**Examples**:
```powershell
# Generate random locations
Invoke-GameCommand -CommandName "world.generateLocations" -Parameters @{ Count = 20 }

# Generate shops near specific coordinates
Invoke-GameCommand -CommandName "world.generateLocations" -Parameters @{
    Count = 5
    LocationType = "shop"
    CenterLatitude = 40.7128
    CenterLongitude = -74.0060
    SpreadRadius = 2.0
}
```

## Quest Module Commands

### quest.create
**Description**: Create a new quest

**Parameters**:
- `Title` (String, Required): Quest title
- `Description` (String, Required): Quest description
- `Objectives` (Array, Required): List of quest objectives
- `Rewards` (Object, Optional): Quest rewards
- `Difficulty` (String, Optional): Quest difficulty level (easy, medium, hard)

**Access Level**: Protected

**Examples**:
```powershell
# Create a simple quest
Invoke-GameCommand -CommandName "quest.create" -Parameters @{
    Title = "Explore the Forest"
    Description = "Discover hidden locations in the mystical forest"
    Objectives = @("Visit 3 forest locations", "Find the hidden grove")
    Difficulty = "medium"
}
```

### quest.getAvailable
**Description**: Get available quests for a player

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `Difficulty` (String, Optional): Filter by difficulty level
- `LocationId` (String, Optional): Filter by location

**Access Level**: Public

**Examples**:
```powershell
# Get all available quests
Invoke-GameCommand -CommandName "quest.getAvailable" -Parameters @{ PlayerId = "player123" }

# Get easy quests only
Invoke-GameCommand -CommandName "quest.getAvailable" -Parameters @{
    PlayerId = "player123"
    Difficulty = "easy"
}
```

### quest.accept
**Description**: Accept a quest for a player

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `QuestId` (String, Required): Quest identifier

**Access Level**: Public

**Examples**:
```powershell
Invoke-GameCommand -CommandName "quest.accept" -Parameters @{
    PlayerId = "player123"
    QuestId = "quest456"
}
```

### quest.updateProgress
**Description**: Update quest progress for a player

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `QuestId` (String, Required): Quest identifier
- `ObjectiveIndex` (Integer, Required): Objective to update
- `Progress` (Float, Optional): Progress amount (default: 1.0)

**Access Level**: Public

**Examples**:
```powershell
# Mark first objective as complete
Invoke-GameCommand -CommandName "quest.updateProgress" -Parameters @{
    PlayerId = "player123"
    QuestId = "quest456"
    ObjectiveIndex = 0
}

# Partial progress on an objective
Invoke-GameCommand -CommandName "quest.updateProgress" -Parameters @{
    PlayerId = "player123"
    QuestId = "quest456"
    ObjectiveIndex = 1
    Progress = 0.5
}
```

## Shop Module Commands

### shop.getItems
**Description**: Get available items in a shop

**Parameters**:
- `ShopId` (String, Required): Shop identifier
- `Category` (String, Optional): Filter by item category
- `MinPrice` (Float, Optional): Minimum price filter
- `MaxPrice` (Float, Optional): Maximum price filter

**Access Level**: Public

**Examples**:
```powershell
# Get all shop items
Invoke-GameCommand -CommandName "shop.getItems" -Parameters @{ ShopId = "shop123" }

# Get weapons under 100 gold
Invoke-GameCommand -CommandName "shop.getItems" -Parameters @{
    ShopId = "shop123"
    Category = "weapon"
    MaxPrice = 100
}
```

### shop.purchase
**Description**: Purchase an item from a shop

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `ShopId` (String, Required): Shop identifier
- `ItemId` (String, Required): Item identifier
- `Quantity` (Integer, Optional): Number of items to purchase (default: 1)

**Access Level**: Public

**Examples**:
```powershell
# Purchase single item
Invoke-GameCommand -CommandName "shop.purchase" -Parameters @{
    PlayerId = "player123"
    ShopId = "shop123"
    ItemId = "item456"
}

# Purchase multiple items
Invoke-GameCommand -CommandName "shop.purchase" -Parameters @{
    PlayerId = "player123"
    ShopId = "shop123"
    ItemId = "item789"
    Quantity = 5
}
```

### shop.sell
**Description**: Sell an item to a shop

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `ShopId` (String, Required): Shop identifier
- `ItemId` (String, Required): Item identifier
- `Quantity` (Integer, Optional): Number of items to sell (default: 1)

**Access Level**: Public

**Examples**:
```powershell
# Sell single item
Invoke-GameCommand -CommandName "shop.sell" -Parameters @{
    PlayerId = "player123"
    ShopId = "shop123"
    ItemId = "item456"
}
```

## Inventory Module Commands

### inventory.getItems
**Description**: Get player's inventory items

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `Category` (String, Optional): Filter by item category
- `SortBy` (String, Optional): Sort criteria (name, value, quantity)

**Access Level**: Public

**Examples**:
```powershell
# Get all inventory items
Invoke-GameCommand -CommandName "inventory.getItems" -Parameters @{ PlayerId = "player123" }

# Get weapons sorted by value
Invoke-GameCommand -CommandName "inventory.getItems" -Parameters @{
    PlayerId = "player123"
    Category = "weapon"
    SortBy = "value"
}
```

### inventory.useItem
**Description**: Use an item from inventory

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `ItemId` (String, Required): Item identifier
- `TargetId` (String, Optional): Target for item use

**Access Level**: Public

**Examples**:
```powershell
# Use a consumable item
Invoke-GameCommand -CommandName "inventory.useItem" -Parameters @{
    PlayerId = "player123"
    ItemId = "potion456"
}

# Use item on target
Invoke-GameCommand -CommandName "inventory.useItem" -Parameters @{
    PlayerId = "player123"
    ItemId = "key789"
    TargetId = "door123"
}
```

## Administrative Commands

### admin.resetPlayer
**Description**: Reset a player's progress and state

**Parameters**:
- `PlayerId` (String, Required): Player identifier
- `KeepInventory` (Boolean, Optional): Preserve inventory items (default: false)
- `KeepProgress` (Boolean, Optional): Preserve quest progress (default: false)

**Access Level**: Admin

**Examples**:
```powershell
# Complete player reset
Invoke-GameCommand -CommandName "admin.resetPlayer" -Parameters @{ PlayerId = "player123" }

# Reset but keep inventory
Invoke-GameCommand -CommandName "admin.resetPlayer" -Parameters @{
    PlayerId = "player123"
    KeepInventory = $true
}
```

### admin.generateReport
**Description**: Generate comprehensive system reports

**Parameters**:
- `ReportType` (String, Required): Type of report (player, system, performance)
- `TimeRange` (String, Optional): Time range for report (1h, 24h, 7d, 30d)
- `Format` (String, Optional): Report format (JSON, CSV, HTML)

**Access Level**: Admin

**Examples**:
```powershell
# Generate player activity report
Invoke-GameCommand -CommandName "admin.generateReport" -Parameters @{
    ReportType = "player"
    TimeRange = "24h"
    Format = "HTML"
}
```

### admin.maintenance
**Description**: Perform system maintenance operations

**Parameters**:
- `Operation` (String, Required): Maintenance operation (cleanup, optimize, backup)
- `Scope` (String, Optional): Operation scope (logs, cache, database)

**Access Level**: Admin

**Examples**:
```powershell
# Clean up old log files
Invoke-GameCommand -CommandName "admin.maintenance" -Parameters @{
    Operation = "cleanup"
    Scope = "logs"
}

# Optimize system cache
Invoke-GameCommand -CommandName "admin.maintenance" -Parameters @{
    Operation = "optimize"
    Scope = "cache"
}
```

## Error Handling

### Common Error Responses
All commands may return error responses in the following format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": {
      "parameter": "Invalid parameter value",
      "context": "Additional context information"
    }
  }
}
```

### Error Codes
- **INVALID_PARAMETER**: Parameter validation failed
- **ACCESS_DENIED**: Insufficient permissions
- **RESOURCE_NOT_FOUND**: Requested resource doesn't exist
- **SYSTEM_ERROR**: Internal system error
- **TIMEOUT**: Operation timed out
- **CONCURRENT_MODIFICATION**: Resource was modified by another operation

## Performance Considerations

### Command Caching
- Frequently used commands are cached for improved performance
- Cache invalidation occurs automatically when underlying data changes
- Cache size and retention can be configured per module

### Rate Limiting
- Commands may be rate limited to prevent abuse
- Limits are configurable per command and access level
- Exceeded limits result in temporary command blocking

### Asynchronous Execution
- Long-running commands support asynchronous execution
- Progress can be monitored through the event system
- Results are delivered via events when complete

---

**Document Version**: 1.0
**Last Updated**: [Current Date]
**Author**: Development Team
**Next Review**: [Review Date]
