# PowerShell Leafmap Game - System Architecture Documentation

## Overview

The PowerShell Leafmap Game is a sophisticated hybrid web-based game that combines PowerShell backend processing with JavaScript frontend interaction. The architecture is designed for modularity, scalability, and real-time communication between different system components.

> **Note on Naming**: The game is named "Leafmap" as a play on words, but the frontend uses **Leaflet.js** (a JavaScript mapping library), not the Python package "leafmap" which is designed for Jupyter notebooks and cannot be used in browser-based applications.

## Core Architecture Principles

### 1. Modular Design
- **Separation of Concerns**: Each module handles specific functionality
- **Loose Coupling**: Modules communicate through well-defined interfaces
- **High Cohesion**: Related functionality is grouped together
- **Plugin Architecture**: New modules can be added without affecting existing code

### 2. Event-Driven Architecture
- **Asynchronous Communication**: Components communicate through events
- **Decoupled Processing**: Event publishers don't need to know about subscribers
- **Scalable Message Handling**: Events are queued and processed efficiently
- **Cross-Platform Integration**: Events bridge PowerShell and JavaScript environments

### 3. Hybrid Technology Stack
- **Backend**: PowerShell modules for business logic and data processing
- **Frontend**: HTML5/CSS3/JavaScript for user interface
- **Communication**: JSON-based message passing between frontend and backend
- **State Management**: Centralized state persistence with JSON serialization

## System Components

### Core Modules (Modules/CoreGame/)

#### 1. EventSystem.psm1
**Purpose**: Event-driven communication framework
**Key Features**:
- Bidirectional PowerShell-JavaScript communication
- Event queue management and persistence
- Handler registration and wildcard pattern matching
- Performance monitoring and metrics collection
- Event deduplication and priority handling

**Architecture**:
```
PowerShell Environment          JavaScript Environment
┌─────────────────────┐        ┌─────────────────────┐
│   Event Handlers    │        │   Event Listeners   │
│                     │        │                     │
├─────────────────────┤        ├─────────────────────┤
│   EventSystem       │◄──────►│   Communication     │
│   - Send Events     │  JSON  │   Bridge            │
│   - Process Commands│  Files │   - Read Events     │
│   - Queue Management│        │   - Send Commands   │
└─────────────────────┘        └─────────────────────┘
```

#### 2. StateManager.psm1
**Purpose**: Centralized game state persistence and management
**Key Features**:
- Entity serialization and reconstruction
- State change tracking and history
- Data integrity validation
- Performance-optimized state operations

**Data Flow**:
```
Game Entities ──► StateManager ──► JSON Storage
     ▲                               │
     │                               │
     └─── Entity Reconstruction ◄────┘
```

#### 3. CommandRegistry.psm1
**Purpose**: Command registration and execution framework
**Key Features**:
- Dynamic command registration
- Parameter validation and type checking
- Access control and security
- Performance monitoring and caching

**Command Lifecycle**:
```
Registration ──► Validation ──► Storage ──► Execution ──► Monitoring
     │               │              │            │           │
     │               └─ Parameters  │            │           └─ Metrics
     │                              │            │
     └─ Security Checks             │            └─ Context Injection
                                    │
                                    └─ Handler Mapping
```

#### 4. GameLogging.psm1
**Purpose**: Comprehensive logging and monitoring system
**Key Features**:
- Multi-output logging (console, file, event)
- Structured logging with metadata
- Log rotation and retention management
- Performance tracking and metrics

**Logging Architecture**:
```
Log Sources ──► GameLogging ──► Multiple Outputs
│                   │              │
│ - Modules         │              ├─ Console
│ - Events          │              ├─ Log Files
│ - Commands        │              ├─ Event System
│ - Errors          │              └─ External Systems
│                   │
└─ Context Data ────┘
```

## Module Loading Architecture

The CoreGame module uses an **Import-Module approach** in the root module rather than `NestedModules` in the manifest. This design decision was made to properly handle function scoping across PowerShell versions.

### Load Order
```
CoreGame.psm1 (root)
    ├── Import GameLogging.psm1       (no dependencies)
    ├── Import DataModels.psm1        (no dependencies)
    ├── Import EventSystem.psm1       (depends on GameLogging)
    ├── Import StateManager.psm1      (depends on DataModels, EventSystem)
    ├── Import PathfindingSystem.psm1 (depends on GameLogging, EventSystem, StateManager, DataModels)
    ├── Import CommunicationBridge.psm1 (depends on GameLogging, EventSystem)
    └── Import CommandRegistry.psm1   (depends on GameLogging, EventSystem)
```

### Usage Pattern
```powershell
# Single import loads all subsystems
Import-Module ./Modules/CoreGame/CoreGame.psd1 -Force

# Initialize all systems at once
Initialize-GameEngine -DebugMode

# Or initialize individually
Initialize-GameLogging
Initialize-EventSystem
Initialize-StateManager
```

### Function Export Strategy
The manifest (`CoreGame.psd1`) explicitly lists all exported functions from all submodules. This follows Microsoft best practices for:
- **Performance**: Explicit exports are faster than wildcards
- **Discoverability**: Clear documentation of public API
- **Maintainability**: Changes to exports are version-controlled

### Specialized Modules

#### Character System (Modules/CharacterSystem/)
- Player management and progression
- Character statistics and abilities
- Inventory and equipment systems

#### World System (Modules/WorldSystem/)
- Location management and mapping
- Geographic data processing
- Real-world coordinate integration

#### Quest System (Modules/QuestSystem/)
- Dynamic quest generation
- Progress tracking and validation
- Reward distribution

#### Shop System (Modules/ShopSystem/)
- Item transactions and pricing
- Inventory management
- Economic balancing

#### Faction System (Modules/FactionSystem/)
- Player allegiance tracking
- Faction-based interactions
- Reputation management

#### Terminal System (Modules/TerminalSystem/)
- Command-line interface emulation
- Interactive terminal sessions
- Script execution environment

#### Drone System (Modules/DroneSystem/)
- Automated game entities
- AI behavior patterns
- Environmental monitoring

## Communication Flow

### PowerShell to JavaScript Communication

1. **Event Generation**: PowerShell modules generate events using `Send-GameEvent`
2. **Queue Management**: Events are added to the global event queue
3. **File Serialization**: Event queue is serialized to `events.json`
4. **JavaScript Polling**: Frontend polls for new events periodically
5. **Event Processing**: JavaScript processes events and updates UI

```
PowerShell Module
       │
       ▼
Send-GameEvent()
       │
       ▼
Global Event Queue
       │
       ▼
events.json File
       │
       ▼
JavaScript Frontend
       │
       ▼
UI Updates
```

### JavaScript to PowerShell Communication

1. **Command Creation**: JavaScript creates command objects
2. **Queue Addition**: Commands are added to command queue
3. **File Serialization**: Command queue is written to `commands.json`
4. **PowerShell Processing**: Backend processes command queue
5. **Response Generation**: Results are sent back as events

```
JavaScript Frontend
       │
       ▼
Command Generation
       │
       ▼
commands.json File
       │
       ▼
PowerShell Processing
       │
       ▼
Result Events
```

## Data Architecture

### State Persistence

The game uses a multi-layered persistence approach:

```
┌─────────────────────────────────────────────────────┐
│                Application Layer                    │
├─────────────────────────────────────────────────────┤
│              StateManager Module                   │
├─────────────────────────────────────────────────────┤
│               JSON Serialization                   │
├─────────────────────────────────────────────────────┤
│               File System Storage                  │
└─────────────────────────────────────────────────────┘
```

### Entity Model

Entities follow a consistent structure:
```json
{
  "id": "unique-identifier",
  "type": "entity-type",
  "data": {
    "properties": "values"
  },
  "metadata": {
    "created": "timestamp",
    "modified": "timestamp",
    "version": "version-number"
  }
}
```

## Performance Considerations

### Memory Management
- **Lazy Loading**: Entities are loaded on demand
- **Cache Management**: Frequently accessed data is cached
- **Garbage Collection**: Unused objects are explicitly cleaned up

### Scalability Features
- **Modular Loading**: Only required modules are loaded
- **Event Batching**: Multiple events can be processed together
- **Asynchronous Processing**: Long-running operations don't block the UI

### Optimization Strategies
- **Command Caching**: Frequently used commands are cached
- **State Differencing**: Only changed state is persisted
- **Performance Monitoring**: Built-in metrics collection and analysis

## Security Architecture

### Access Control
- **Role-Based Security**: Commands have access level requirements
- **Parameter Validation**: All inputs are validated before processing
- **Execution Context**: Commands run with appropriate privileges

### Data Protection
- **Input Sanitization**: All external input is sanitized
- **State Validation**: Game state is validated before persistence
- **Error Isolation**: Errors in one module don't affect others

## Error Handling and Resilience

### Error Recovery
- **Graceful Degradation**: System continues functioning with reduced features
- **State Recovery**: Corrupted state can be restored from backups
- **Module Isolation**: Errors in one module don't crash the entire system

### Monitoring and Alerting
- **Comprehensive Logging**: All operations are logged with context
- **Performance Metrics**: Real-time performance monitoring
- **Health Checks**: System health is continuously monitored

## Extension Points

### Adding New Modules
1. Create module following the established patterns
2. Implement required interfaces
3. Register with the module system
4. Add appropriate documentation

### Custom Event Handlers
1. Register event handlers using `Register-GameEvent`
2. Implement handler logic following conventions
3. Add error handling and logging
4. Test with various event scenarios

### Command Extensions
1. Create command definitions using the CommandRegistry
2. Implement parameter validation
3. Add security and access controls
4. Register with appropriate modules

## OpenStreetMap Integration

The game integrates with OpenStreetMap data through the Overpass API to provide real-world terrain awareness, building data, and transport information.

### OSMDataService (js/osmDataService.js)

**Purpose**: Query and cache OpenStreetMap data for terrain validation, building locations, and transport stops.

**Key Features**:
- **Pre-caching**: Queries Overpass API once on game load for entire city bounds (~10km²)
- **Fallback Chain**: Primary endpoint → Secondary endpoint → Random generation
- **Local Storage Cache**: 24-hour TTL with manual refresh option
- **Terrain Validation**: Check if coordinates are on land vs water using Turf.js

**Data Types Cached**:
| Data Type | OSM Tags | Usage |
|-----------|----------|-------|
| Water Bodies | `natural=water`, `natural=wetland` | Position validation |
| Buildings | `building=*`, `addr:*` | Location placement with real addresses |
| Transport Stops | `highway=bus_stop`, `railway=station`, etc. | Transit mode travel |
| Footpaths | `highway=footway\|pedestrian\|path` | Walkable route visualization |
| Surface Types | `surface=*` | Speed modifiers for travel time |

**Overpass API Endpoints**:
- Primary: `https://overpass-api.de/api/interpreter`
- Fallback: `https://overpass.kumi.systems/api/interpreter`

**Architecture**:
```
Game Initialization
        │
        ▼
┌─────────────────────────┐
│   Check localStorage    │
│   for cached OSM data   │
└───────────┬─────────────┘
            │
    ┌───────┴───────┐
    │ Cache Valid?  │
    └───────┬───────┘
            │
     Yes ◄──┴──► No
      │          │
      │          ▼
      │    ┌─────────────────┐
      │    │ Query Overpass  │
      │    │ API (primary)   │
      │    └───────┬─────────┘
      │            │
      │     ┌──────┴──────┐
      │     │   Success?  │
      │     └──────┬──────┘
      │            │
      │     Yes ◄──┴──► No
      │      │          │
      │      │          ▼
      │      │    ┌─────────────────┐
      │      │    │ Try fallback    │
      │      │    │ endpoint        │
      │      │    └───────┬─────────┘
      │      │            │
      │      │     ┌──────┴──────┐
      │      │     │   Success?  │
      │      │     └──────┬──────┘
      │      │            │
      │      │     Yes ◄──┴──► No
      │      │      │          │
      │      │      │          ▼
      │      │      │    ┌─────────────────┐
      │      │      │    │ Random fallback │
      │      │      │    │ generation      │
      │      │      │    └───────┬─────────┘
      │      │      │            │
      ▼      ▼      ▼            ▼
┌─────────────────────────────────────┐
│   Game Ready with OSM/Fallback Data │
└─────────────────────────────────────┘
```

### Surface-Based Speed Modifiers

The pathfinding system uses OSM surface data to adjust travel times:

| Surface Type | Speed Modifier | Notes |
|--------------|----------------|-------|
| asphalt, concrete, paved | 1.0 | Full speed |
| paving_stones | 0.95 | Slight reduction |
| sett, cobblestone | 0.85-0.90 | Uneven surface |
| gravel, compacted | 0.75-0.85 | Loose material |
| dirt, earth | 0.65-0.70 | Unpaved |
| grass | 0.60 | Off-path |
| sand | 0.50 | Difficult terrain |
| mud | 0.40 | Very difficult |

### Transit Mode

Transit travel requires:
1. Player must be within 200m of a transit stop
2. Destination must be within 200m of a transit stop
3. Travel time includes: walk to stop + transit time + walk from stop

Transport stop types:
- 🚌 Bus (`highway=bus_stop`)
- 🚂 Train (`railway=station`)
- 🚇 Subway (`railway=subway_entrance`)
- 🚊 Tram (`railway=tram_stop`)
- ⛴️ Ferry (`amenity=ferry_terminal`)

## Development Guidelines

### Code Standards
- **PowerShell Best Practices**: Follow established PowerShell conventions
- **Error Handling**: Comprehensive try-catch blocks with logging
- **Documentation**: Inline documentation for all public functions
- **Testing**: Unit and integration tests for all modules

### Module Development
- **Interface Consistency**: All modules follow the same interface patterns
- **Dependency Management**: Minimal dependencies between modules
- **Configuration**: Configurable behavior through parameter files
- **Versioning**: Semantic versioning for all modules

## Deployment Architecture

### Development Environment
- Local PowerShell execution
- File-based communication
- Console-based monitoring

### Production Considerations
- Web server deployment
- Database integration
- Monitoring and alerting systems
- Backup and recovery procedures

---

**Document Version**: 1.0
**Last Updated**: [Current Date]
**Author**: Development Team
**Next Review**: [Review Date]
