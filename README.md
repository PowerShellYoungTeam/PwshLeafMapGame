# PowerShell Leafmap RPG Game

An interactive RPG game built with PowerShell and Leafmap.js featuring drones, factions, and interactive terminals with enhanced modular architecture.

- **Enhanced Core Architecture** with event-driven modules
- **Structured Logging** with multi-output support
- **Dynamic Command System** with runtime registration
- **Persistent State Management** with entity tracking
- **Cross-Module Communication** via events

## Enhanced Core Modules

### 🎯 GameLogging
Centralized structured logging with console, file, and event outputs.

### 🔄 EventSystem
Event-driven communication framework with deduplication and priority support.

### ⚡ CommandRegistry
Dynamic command registration system with validation and documentation.

### 💾 StateManager
Entity persistence and state management with change tracking.

## Getting Started

### Quick Start
```powershell
.\Start-Game.ps1
```

### Development Setup
```powershell
# Test enhanced modules
.\Test-EnhancedModules.ps1

# Enable verbose output for debugging
$VerbosePreference = 'Continue'
.\Start-Game.ps1
```

## Documentation

- **[Enhanced Modules Guide](Docs/EnhancedModulesGuide.md)** - Architecture and design patterns
- **[Migration Guide](Docs/MigrationGuide.md)** - Upgrading from previous versions
- **[CoreGame README](Modules/CoreGame/README.md)** - Detailed module documentation
- **[Test Suite](Test-EnhancedModules.ps1)** - Comprehensive validation

## Architecture

The game uses an event-driven architecture with cross-module communication:

```
GameLogging ←→ EventSystem ←→ CommandRegistry
     ↑              ↑              ↑
     └──────────────┼──────────────┘
                    ↓
               StateManager
```

All modules support:
- Verbose output via `$VerbosePreference`
- Structured data logging
- Performance monitoring
- Cross-module events

---

**Ready for Production:** All enhanced functionality has been thoroughly tested and validated. ✅