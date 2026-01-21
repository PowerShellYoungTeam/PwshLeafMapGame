# DroneSystem

Tactical drone deployment, reconnaissance, combat support, and automated unit control system.

## Overview

This module handles all drone-related operations for the PowerShell Leafmap RPG including:
- Multiple drone types (Scout, Combat, Support, EMP, Heavy, Stealth, Carrier, Turret)
- Drone inventory and deployment management
- Automated missions and patrol systems
- Combat actions (attack, scan, heal, EMP blast, cloak)
- Drone override/hacking system
- Upgrade and leveling system
- Event processing for time/combat integration

## Drone Types

| Type | Category | HP | Speed | Attack | Special |
|------|----------|-----|-------|--------|---------|
| Scout | Recon | 30 | 80 | 0 | Scan, MarkTarget, Stealth |
| Combat | Combat | 60 | 50 | 25 | Attack, Suppression, Strafe |
| Support | Support | 50 | 40 | 0 | Heal, Shield, Boost |
| EMP | Utility | 40 | 60 | 0 | EMPBlast, Jamming, Hack |
| Heavy | Combat | 120 | 25 | 50 | HeavyAttack, MissileSalvo |
| Stealth | Recon | 25 | 70 | 10 | Cloak, SilentScan, Sabotage |
| Carrier | Support | 80 | 35 | 0 | Deploy, Resupply, Evac |
| Turret | Defense | 100 | 0 | 35 | AutoTarget, Overwatch, SelfDestruct |

## Mission Types

- **Patrol** - Automated area patrol
- **Reconnaissance** - Gather intel on area
- **Escort** - Protect a target
- **Search** - Search for targets
- **Strike** - Attack designated target
- **Suppression** - Provide covering fire
- **Overwatch** - Guard position
- **Sabotage** - Disable enemy systems
- **MedEvac** - Medical evacuation

## Functions

### Initialization
- `Initialize-DroneSystem` - Initialize the drone system with configuration

### Drone Management
- `New-Drone` - Create a new drone
- `Get-Drone` - Retrieve drone(s) by ID, type, owner, or status
- `Remove-Drone` - Remove/destroy a drone
- `Set-DroneStatus` - Change drone status

### Inventory
- `Add-DroneToInventory` - Add drone to player inventory
- `Get-DroneInventory` - List inventory drones
- `Remove-DroneFromInventory` - Remove from inventory

### Deployment
- `Deploy-Drone` - Deploy drone from inventory to field
- `Recall-Drone` - Recall drone back to inventory

### Actions
- `Invoke-DroneAction` - Execute drone ability (Scan, Attack, Heal, Shield, EMPBlast, Cloak, etc.)
- `Move-Drone` - Move drone to new position

### Missions
- `Start-DroneMission` - Start an automated mission
- `Get-DroneMission` - Get active/completed missions
- `Complete-DroneMission` - Complete a mission
- `Cancel-DroneMission` - Cancel active mission

### Combat
- `Invoke-DroneDamage` - Apply damage to drone (with EMP bonus)
- `Repair-Drone` - Repair drone HP
- `Recharge-Drone` - Recharge drone energy

### Hacking
- `Invoke-DroneOverride` - Attempt to hack/override enemy drone

### Upgrades
- `Get-DroneUpgrade` - List available upgrades
- `Install-DroneUpgrade` - Install upgrade on drone

### State Management
- `Get-DroneSystemState` - Get system state summary
- `Get-DroneStatistics` - Get drone/overall statistics
- `Export-DroneData` - Export to JSON
- `Import-DroneData` - Import from JSON

### Events
- `Process-DroneEvent` - Process game events (time, combat, EMP, area)

## Usage

```powershell
Import-Module .\Modules\DroneSystem\DroneSystem.psm1

# Initialize
Initialize-DroneSystem

# Add drones to inventory
Add-DroneToInventory -Type 'Scout' -Quantity 2
Add-DroneToInventory -Type 'Combat'

# Deploy a scout drone
$result = Deploy-Drone -Type 'Scout' -Position @{ X = 100; Y = 100; Z = 50 }
$droneId = $result.DroneId

# Perform actions
Invoke-DroneAction -DroneId $droneId -Action 'Scan'
Move-Drone -DroneId $droneId -TargetPosition @{ X = 200; Y = 150; Z = 50 }

# Start a mission
Start-DroneMission -DroneId $droneId -MissionType 'Patrol'

# Recall when done
Recall-Drone -DroneId $droneId
```

## Override/Hacking System

Override enemy drones using Intelligence and Hacking skill:

```powershell
# Create enemy drone
New-Drone -DroneId 'enemy_01' -Type 'Combat' -IsEnemy $true

# Attempt override
$result = Invoke-DroneOverride -DroneId 'enemy_01' -Intelligence 15 -HackingSkill 3
# Success rate based on: base chance + INT bonus + skill bonus - drone level - type difficulty
```

## Configuration

```powershell
Initialize-DroneSystem -Configuration @{
    MaxActiveDrones = 5        # Max deployed at once
    MaxDroneInventory = 20     # Max in inventory
    BaseDetectionRange = 150   # Enemy detection range
    OverrideBaseDifficulty = 50
    OverrideIntelBonus = 3     # Per INT point above 10
}
```