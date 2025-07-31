# PowerShell Leafmap Game - Communication Flow Diagrams

## Overview

This document provides visual representations of the communication flows between different components of the PowerShell Leafmap Game system. These diagrams illustrate how data moves through the system and how different modules interact.

## High-Level System Communication

### Overall System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              PowerShell Backend                                │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│   EventSystem   │ CommandRegistry │  StateManager   │      GameLogging        │
│                 │                 │                 │                         │
│ • Send Events   │ • Execute Cmds  │ • Save State    │ • Multi-output Logs     │
│ • Process Cmds  │ • Validate      │ • Load State    │ • Performance Metrics   │
│ • Queue Mgmt    │ • Monitor       │ • Track Changes │ • Error Tracking        │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────┘
         │                   │                   │                   │
         │                   │                   │                   │
         ▼                   ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          Communication Layer                                   │
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ events.json │    │commands.json│    │gamedata.json│    │  log files  │     │
│  │             │    │             │    │             │    │             │     │
│  │ PS -> JS    │    │ JS -> PS    │    │ State Data  │    │ Debug Info  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────────────────────────┘
         │                   │                   │                   │
         │                   │                   │                   │
         ▼                   ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           JavaScript Frontend                                  │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│   Event Handler │ Command Sender  │   UI Controller │     Game State          │
│                 │                 │                 │                         │
│ • Process Events│ • Send Commands │ • Update Display│ • Manage Local State    │
│ • Update UI     │ • Handle Errors │ • User Input    │ • Sync with Backend     │
│ • Trigger Actions│ • Queue Mgmt    │ • Animations    │ • Cache Management      │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────┘
```

## Event System Communication Flow

### PowerShell to JavaScript Event Flow

```
PowerShell Module
       │
       │ 1. Trigger Event
       ▼
┌─────────────────────┐
│   Send-GameEvent    │ ◄── Event Data
│                     │     (Type, Data, Source)
└─────────────────────┘
       │
       │ 2. Validate & Process
       ▼
┌─────────────────────┐
│  Event Validation   │
│  • Type Check       │
│  • Data Validation  │
│  • Security Check   │
└─────────────────────┘
       │
       │ 3. Add to Queue
       ▼
┌─────────────────────┐
│   Global Event      │
│      Queue          │
│                     │
│ [Event1, Event2...] │
└─────────────────────┘
       │
       │ 4. Serialize to File
       ▼
┌─────────────────────┐
│   events.json       │
│                     │
│ [{type:"event",     │
│   data:{...},       │
│   timestamp:"..."}] │
└─────────────────────┘
       │
       │ 5. JavaScript Polling
       ▼
┌─────────────────────┐
│ JavaScript Frontend │
│                     │
│ setInterval(() => { │
│   fetchEvents();    │
│ }, 1000);           │
└─────────────────────┘
       │
       │ 6. Process Events
       ▼
┌─────────────────────┐
│   Event Handlers    │
│                     │
│ • UI Updates        │
│ • State Changes     │
│ • User Notifications│
└─────────────────────┘
```

### JavaScript to PowerShell Command Flow

```
JavaScript Frontend
       │
       │ 1. User Action/Timer
       ▼
┌─────────────────────┐
│  Generate Command   │ ◄── User Input
│                     │     (Click, Form, etc.)
└─────────────────────┘
       │
       │ 2. Create Command Object
       ▼
┌─────────────────────┐
│  Command Object     │
│  {                  │
│    type: "cmd",     │
│    data: {...},     │
│    id: "uuid"       │
│  }                  │
└─────────────────────┘
       │
       │ 3. Add to Queue
       ▼
┌─────────────────────┐
│   Command Queue     │
│                     │
│ [Cmd1, Cmd2, ...]   │
└─────────────────────┘
       │
       │ 4. Serialize to File
       ▼
┌─────────────────────┐
│  commands.json      │
│                     │
│ [{type:"cmd",       │
│   data:{...},       │
│   id:"..."}]        │
└─────────────────────┘
       │
       │ 5. PowerShell Processing
       ▼
┌─────────────────────┐
│Process-JSCommands   │
│                     │
│ • Read File         │
│ • Parse Commands    │
│ • Execute Each      │
└─────────────────────┘
       │
       │ 6. Command Execution
       ▼
┌─────────────────────┐
│  Command Registry   │
│                     │
│ • Validate Params   │
│ • Check Permissions │
│ • Execute Handler   │
│ • Return Result     │
└─────────────────────┘
       │
       │ 7. Send Response Event
       ▼
┌─────────────────────┐
│  Response Event     │
│                     │
│ Send-GameEvent      │
│ "cmd.completed"     │
│ {result: ...}       │
└─────────────────────┘
```

## State Management Flow

### State Persistence Flow

```
Game Entity Changes
       │
       │ 1. Entity Modified
       ▼
┌─────────────────────┐
│   Entity Update     │
│                     │
│ • Player moved      │
│ • Item acquired     │
│ • Quest progress    │
└─────────────────────┘
       │
       │ 2. Trigger Save
       ▼
┌─────────────────────┐
│   StateManager      │
│                     │
│ Save-EntityState    │
│ • Validate data     │
│ • Track changes     │
└─────────────────────┘
       │
       │ 3. Serialize State
       ▼
┌─────────────────────┐
│  JSON Serialization │
│                     │
│ ConvertTo-Json      │
│ -Depth 10           │
│ -Compress           │
└─────────────────────┘
       │
       │ 4. Write to File
       ▼
┌─────────────────────┐
│   gamedata.json     │
│                     │
│ {                   │
│   "entities": [...],│
│   "metadata": {...} │
│ }                   │
└─────────────────────┘
       │
       │ 5. Backup & Cleanup
       ▼
┌─────────────────────┐
│   File Management   │
│                     │
│ • Create backup     │
│ • Rotate old files  │
│ • Clean temp data   │
└─────────────────────┘
```

### State Loading Flow

```
Application Startup
       │
       │ 1. Initialize System
       ▼
┌─────────────────────┐
│   StateManager      │
│                     │
│ Initialize-State    │
│ • Check files       │
│ • Validate integrity│
└─────────────────────┘
       │
       │ 2. Read State File
       ▼
┌─────────────────────┐
│   gamedata.json     │
│                     │
│ Get-Content         │
│ -Raw                │
└─────────────────────┘
       │
       │ 3. Parse JSON
       ▼
┌─────────────────────┐
│  JSON Parsing       │
│                     │
│ ConvertFrom-Json    │
│ • Error handling    │
│ • Validation        │
└─────────────────────┘
       │
       │ 4. Reconstruct Entities
       ▼
┌─────────────────────┐
│ Entity Reconstruction│
│                     │
│ • Create objects    │
│ • Restore references│
│ • Validate data     │
└─────────────────────┘
       │
       │ 5. Load into Memory
       ▼
┌─────────────────────┐
│   Game State        │
│                     │
│ • Entities loaded   │
│ • Ready for use     │
│ • Change tracking   │
└─────────────────────┘
```

## Command Execution Flow

### Complete Command Lifecycle

```
User Input (JavaScript)
       │
       │ 1. UI Interaction
       ▼
┌─────────────────────┐
│  Event Handler      │
│                     │
│ • Button click      │
│ • Form submission   │
│ • Timer trigger     │
└─────────────────────┘
       │
       │ 2. Generate Command
       ▼
┌─────────────────────┐
│  Command Creation   │
│                     │
│ createCommand({     │
│   type: "action",   │
│   params: {...}     │
│ })                  │
└─────────────────────┘
       │
       │ 3. Queue Command
       ▼
┌─────────────────────┐
│  JavaScript Queue   │
│                     │
│ commandQueue.push() │
│ saveToFile()        │
└─────────────────────┘
       │
       │ 4. PowerShell Polling
       ▼
┌─────────────────────┐
│ Process-JSCommands  │
│                     │
│ • Read commands.json│
│ • Parse each command│
│ • Clear processed   │
└─────────────────────┘
       │
       │ 5. Command Registry
       ▼
┌─────────────────────┐
│  Invoke-GameCommand │
│                     │
│ • Find handler      │
│ • Validate params   │
│ • Check permissions │
│ • Execute           │
└─────────────────────┘
       │
       ├─ 6a. Success Path
       │      │
       │      ▼
       │ ┌─────────────────────┐
       │ │   Handler Execution │
       │ │                     │
       │ │ • Business logic    │
       │ │ • State updates     │
       │ │ • Return result     │
       │ └─────────────────────┘
       │      │
       │      ▼
       │ ┌─────────────────────┐
       │ │  Success Response   │
       │ │                     │
       │ │ Send-GameEvent      │
       │ │ "cmd.completed"     │
       │ │ {success: true}     │
       │ └─────────────────────┘
       │
       └─ 6b. Error Path
              │
              ▼
         ┌─────────────────────┐
         │   Error Handling    │
         │                     │
         │ • Log error         │
         │ • Generate event    │
         │ • Cleanup resources │
         └─────────────────────┘
              │
              ▼
         ┌─────────────────────┐
         │   Error Response    │
         │                     │
         │ Send-GameEvent      │
         │ "cmd.error"         │
         │ {error: "..."}      │
         └─────────────────────┘
       │
       │ 7. Response Processing
       ▼
┌─────────────────────┐
│ JavaScript Handler  │
│                     │
│ • Process response  │
│ • Update UI         │
│ • Handle errors     │
└─────────────────────┘
```

## Logging and Monitoring Flow

### Centralized Logging Flow

```
System Component
       │
       │ 1. Generate Log Entry
       ▼
┌─────────────────────┐
│   Write-GameLog     │
│                     │
│ • Message           │
│ • Level (Info/Warn) │
│ • Module name       │
│ • Context data      │
└─────────────────────┘
       │
       │ 2. Log Processing
       ▼
┌─────────────────────┐
│  Log Formatter      │
│                     │
│ • Add timestamp     │
│ • Structure data    │
│ • Apply filters     │
└─────────────────────┘
       │
       ├─ 3a. Console Output
       │      │
       │      ▼
       │ ┌─────────────────────┐
       │ │   Console Writer    │
       │ │                     │
       │ │ Write-Host          │
       │ │ • Color coding      │
       │ │ • Format text       │
       │ └─────────────────────┘
       │
       ├─ 3b. File Output
       │      │
       │      ▼
       │ ┌─────────────────────┐
       │ │   File Writer       │
       │ │                     │
       │ │ Add-Content         │
       │ │ • Rotate logs       │
       │ │ • Manage size       │
       │ └─────────────────────┘
       │
       └─ 3c. Event Output
              │
              ▼
         ┌─────────────────────┐
         │   Event Publisher   │
         │                     │
         │ Send-GameEvent      │
         │ "system.log"        │
         │ {log: {...}}        │
         └─────────────────────┘
```

### Performance Monitoring Flow

```
Command Execution Start
       │
       │ 1. Start Timer
       ▼
┌─────────────────────┐
│   Performance       │
│   Monitoring        │
│                     │
│ $startTime = Get-Date│
└─────────────────────┘
       │
       │ 2. Execute Operation
       ▼
┌─────────────────────┐
│   Business Logic    │
│                     │
│ • Process command   │
│ • Update state      │
│ • Generate response │
└─────────────────────┘
       │
       │ 3. End Timer
       ▼
┌─────────────────────┐
│   Calculate Metrics │
│                     │
│ $duration =         │
│   (Get-Date) -      │
│   $startTime        │
└─────────────────────┘
       │
       │ 4. Update Statistics
       ▼
┌─────────────────────┐
│   Metrics Update    │
│                     │
│ • Average time      │
│ • Min/Max times     │
│ • Success rate      │
│ • Error count       │
└─────────────────────┘
       │
       │ 5. Log Performance
       ▼
┌─────────────────────┐
│   Performance Log   │
│                     │
│ Write-GameLog       │
│ -Level Debug        │
│ -Data $metrics      │
└─────────────────────┘
       │
       │ 6. Send Metrics Event
       ▼
┌─────────────────────┐
│   Metrics Event     │
│                     │
│ Send-GameEvent      │
│ "system.metrics"    │
│ {perf: {...}}       │
└─────────────────────┘
```

## Error Handling and Recovery Flow

### Error Propagation Flow

```
Error Occurrence
       │
       │ 1. Exception Thrown
       ▼
┌─────────────────────┐
│   Error Catch       │
│                     │
│ try {               │
│   # operation       │
│ } catch {           │
│   # handle error    │
│ }                   │
└─────────────────────┘
       │
       │ 2. Error Logging
       ▼
┌─────────────────────┐
│   Write-ErrorLog    │
│                     │
│ • Exception details │
│ • Stack trace       │
│ • Context data      │
│ • Module info       │
└─────────────────────┘
       │
       │ 3. Error Classification
       ▼
┌─────────────────────┐
│   Error Analysis    │
│                     │
│ • Severity level    │
│ • Error category    │
│ • Recovery options  │
│ • User impact       │
└─────────────────────┘
       │
       ├─ 4a. Recoverable Error
       │      │
       │      ▼
       │ ┌─────────────────────┐
       │ │   Error Recovery    │
       │ │                     │
       │ │ • Retry operation   │
       │ │ • Use fallback      │
       │ │ • Restore state     │
       │ └─────────────────────┘
       │      │
       │      ▼
       │ ┌─────────────────────┐
       │ │   Recovery Event    │
       │ │                     │
       │ │ Send-GameEvent      │
       │ │ "system.recovered"  │
       │ └─────────────────────┘
       │
       └─ 4b. Critical Error
              │
              ▼
         ┌─────────────────────┐
         │   Critical Handler  │
         │                     │
         │ • Stop processing   │
         │ • Save state        │
         │ • Notify admin      │
         └─────────────────────┘
              │
              ▼
         ┌─────────────────────┐
         │   Alert Event       │
         │                     │
         │ Send-GameEvent      │
         │ "system.critical"   │
         │ Priority: High      │
         └─────────────────────┘
```

## Module Interaction Patterns

### Cross-Module Communication

```
Module A (Source)                Module B (Target)
       │                               │
       │ 1. Generate Event             │
       ▼                               │
┌─────────────────────┐                │
│   Send-GameEvent    │                │
│   "module.action"   │                │
│   {data: {...}}     │                │
└─────────────────────┘                │
       │                               │
       │ 2. Event Queue                │
       ▼                               │
┌─────────────────────┐                │
│   Global Event      │                │
│      System         │                │
└─────────────────────┘                │
       │                               │
       │ 3. Event Distribution         │
       ▼                               ▼
┌─────────────────────┐    ┌─────────────────────┐
│   Module A          │    │   Module B          │
│   Event Handler     │    │   Event Handler     │
│                     │    │                     │
│ Register-GameEvent  │    │ Register-GameEvent  │
│ "module.*"          │    │ "module.action"     │
└─────────────────────┘    └─────────────────────┘
       │                               │
       │ 4. Process Event              │ 4. Process Event
       ▼                               ▼
┌─────────────────────┐    ┌─────────────────────┐
│   Handler Logic     │    │   Handler Logic     │
│                     │    │                     │
│ • Log action        │    │ • Update state      │
│ • Update metrics    │    │ • Trigger response  │
└─────────────────────┘    └─────────────────────┘
```

## Summary

These communication flow diagrams illustrate the sophisticated interaction patterns within the PowerShell Leafmap Game system. Key characteristics include:

### Design Principles
- **Asynchronous Communication**: Events and commands are queued for processing
- **Loose Coupling**: Modules communicate through well-defined interfaces
- **Error Resilience**: Comprehensive error handling and recovery mechanisms
- **Performance Monitoring**: Built-in metrics collection and analysis

### Performance Considerations
- **Efficient Serialization**: JSON-based data exchange
- **Queue Management**: Bounded queues with overflow handling
- **Resource Cleanup**: Automatic cleanup of processed items
- **Caching**: Strategic caching of frequently accessed data

### Scalability Features
- **Modular Architecture**: Easy addition of new modules
- **Event-Driven Design**: Scalable message passing
- **State Persistence**: Reliable state management
- **Monitoring Integration**: Comprehensive observability

---

**Document Version**: 1.0
**Last Updated**: [Current Date]
**Author**: Development Team
**Next Review**: [Review Date]
