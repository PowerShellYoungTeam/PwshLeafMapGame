# Core Data Models Specification
## PowerShell Leafmap RPG Game

**Version:** 1.0
**Date:** July 27, 2025
**Status:** Design Specification

---

## Table of Contents

1. [Overview](#overview)
2. [Design Principles](#design-principles)
3. [Base Entity Model](#base-entity-model)
4. [Player Model](#player-model)
5. [NPC Model](#npc-model)
6. [Item Model](#item-model)
7. [Inheritance Patterns](#inheritance-patterns)
8. [Serialization Architecture](#serialization-architecture)
9. [PowerShell-JavaScript Communication](#powershell-javascript-communication)
10. [Data Validation](#data-validation)
11. [Performance Considerations](#performance-considerations)
12. [Implementation Examples](#implementation-examples)

---

## Overview

This specification defines the core data models for the PowerShell Leafmap RPG game, establishing a unified architecture for entity management, inheritance patterns, and cross-platform serialization between PowerShell backend and JavaScript frontend.

### Core Models Hierarchy

```
Entity (Base)
├── Character (Abstract)
│   ├── Player
│   └── NPC
│       ├── Companion
│       ├── Vendor
│       └── Enemy
└── Item
    ├── Equipment
    │   ├── Weapon
    │   └── Armor
    ├── Consumable
    └── QuestItem
```

---

## Design Principles

### 1. **Consistency**
- Uniform property naming conventions
- Standardized type definitions
- Consistent serialization patterns

### 2. **Extensibility**
- Modular inheritance design
- Plugin-friendly architecture
- Version-compatible schemas

### 3. **Performance**
- Efficient serialization/deserialization
- Minimal data transfer overhead
- Lazy loading for complex objects

### 4. **Cross-Platform Compatibility**
- PowerShell/JavaScript type mapping
- JSON-first serialization
- Platform-agnostic identifiers

---

## Base Entity Model

### Core Properties

```powershell
# PowerShell Definition
class Entity {
    [string]$Id                    # Unique identifier (GUID format)
    [string]$Type                  # Entity type discriminator
    [string]$Name                  # Display name
    [string]$Description           # Detailed description
    [hashtable]$Tags               # Flexible tagging system
    [hashtable]$Metadata           # Custom properties storage
    [DateTime]$CreatedAt           # Creation timestamp
    [DateTime]$UpdatedAt           # Last modification timestamp
    [string]$Version               # Schema version
    [bool]$IsActive                # Active/inactive state
    [hashtable]$CustomProperties   # Extension properties
}
```

```javascript
// JavaScript Definition
class Entity {
    constructor(data = {}) {
        this.id = data.id || this.generateId();
        this.type = data.type || 'Entity';
        this.name = data.name || '';
        this.description = data.description || '';
        this.tags = data.tags || {};
        this.metadata = data.metadata || {};
        this.createdAt = data.createdAt || new Date().toISOString();
        this.updatedAt = data.updatedAt || new Date().toISOString();
        this.version = data.version || '1.0.0';
        this.isActive = data.isActive !== false;
        this.customProperties = data.customProperties || {};
    }
}
```

### Property Specifications

| Property | Type | Required | Description | Validation |
|----------|------|----------|-------------|------------|
| `Id` | String | ✅ | Unique entity identifier | GUID format |
| `Type` | String | ✅ | Entity type discriminator | Enum values |
| `Name` | String | ✅ | Human-readable name | 1-100 chars |
| `Description` | String | ❌ | Detailed description | Max 1000 chars |
| `Tags` | Hashtable | ❌ | Key-value tags | Max 50 tags |
| `Metadata` | Hashtable | ❌ | System metadata | JSON serializable |
| `CreatedAt` | DateTime | ✅ | Creation timestamp | ISO 8601 format |
| `UpdatedAt` | DateTime | ✅ | Last update timestamp | ISO 8601 format |
| `Version` | String | ✅ | Schema version | Semantic versioning |
| `IsActive` | Boolean | ✅ | Active state | true/false |
| `CustomProperties` | Hashtable | ❌ | Extension data | JSON serializable |

---

## Player Model

### Inheritance Structure

```powershell
# PowerShell Definition
class Player : Entity {
    # Identity Properties
    [string]$Username              # Unique username
    [string]$Email                 # Player email
    [string]$DisplayName           # Public display name

    # Character Properties
    [int]$Level                    # Character level
    [long]$Experience              # Total experience points
    [long]$ExperienceToNext        # XP needed for next level
    [hashtable]$Attributes         # Core attributes (Str, Dex, Int, etc.)
    [hashtable]$Skills             # Skill levels

    # Game State
    [hashtable]$Location           # Current location data
    [string]$LastLocationId        # Last known location
    [array]$VisitedLocations       # List of visited location IDs
    [long]$Score                   # Total game score
    [string]$GameState             # Current game state

    # Inventory & Equipment
    [array]$Inventory              # Inventory items
    [hashtable]$Equipment          # Equipped items by slot
    [int]$InventoryCapacity        # Maximum inventory size
    [decimal]$Currency             # Game currency

    # Progress & Achievements
    [array]$Achievements           # Unlocked achievements
    [hashtable]$QuestProgress      # Active quests and progress
    [hashtable]$Statistics         # Player statistics
    [array]$CompletedQuests        # Completed quest IDs

    # Social & Multiplayer
    [array]$Friends                # Friend list
    [string]$GuildId               # Guild membership
    [hashtable]$Reputation         # Faction reputation

    # Preferences & Settings
    [hashtable]$Preferences        # Game preferences
    [hashtable]$UISettings         # UI configuration
    [string]$Theme                 # Visual theme

    # Session Data
    [DateTime]$LastLogin           # Last login timestamp
    [TimeSpan]$PlayTime           # Total play time
    [DateTime]$SessionStart        # Current session start
    [bool]$IsOnline                # Online status

    # Backup & Recovery
    [string]$BackupData            # Compressed backup data
    [DateTime]$LastBackup          # Last backup timestamp
}
```

### Advanced Properties

#### Attributes System
```powershell
# Core Attributes
$Attributes = @{
    Strength = @{
        Base = 10
        Current = 15
        Modifiers = @()
        Maximum = 20
    }
    Dexterity = @{
        Base = 10
        Current = 12
        Modifiers = @()
        Maximum = 20
    }
    Intelligence = @{
        Base = 10
        Current = 18
        Modifiers = @()
        Maximum = 20
    }
    Constitution = @{
        Base = 10
        Current = 14
        Modifiers = @()
        Maximum = 20
    }
    Wisdom = @{
        Base = 10
        Current = 13
        Modifiers = @()
        Maximum = 20
    }
    Charisma = @{
        Base = 10
        Current = 11
        Modifiers = @()
        Maximum = 20
    }
}
```

#### Skills System
```powershell
$Skills = @{
    Combat = @{
        Level = 5
        Experience = 2500
        Specializations = @("Melee", "Ranged")
    }
    Exploration = @{
        Level = 8
        Experience = 6400
        Specializations = @("Navigation", "Treasure Hunting")
    }
    Social = @{
        Level = 3
        Experience = 900
        Specializations = @("Persuasion", "Intimidation")
    }
    Crafting = @{
        Level = 7
        Experience = 4900
        Specializations = @("Alchemy", "Enchanting")
    }
}
```

---

## NPC Model

### Base NPC Structure

```powershell
class NPC : Entity {
    # Identity
    [string]$NPCType               # NPC type (Vendor, Guard, Quest Giver, etc.)
    [string]$Race                  # Character race
    [string]$Gender                # Character gender
    [string]$Age                   # Character age

    # Appearance
    [hashtable]$Appearance         # Physical appearance data
    [string]$Portrait              # Portrait image path
    [array]$Animations             # Available animations

    # Behavior
    [hashtable]$AIBehavior         # AI behavior configuration
    [string]$PersonalityType       # Personality archetype
    [array]$DialogueOptions        # Available dialogue
    [hashtable]$Reactions          # Reaction to player actions

    # Location & Movement
    [hashtable]$SpawnLocation      # Default spawn location
    [array]$PatrolRoute            # Movement pattern
    [decimal]$MovementSpeed        # Movement speed
    [bool]$IsStationary            # Static vs mobile

    # Interaction
    [array]$AvailableServices      # Services offered
    [hashtable]$Inventory          # NPC inventory (for vendors)
    [array]$QuestsOffered          # Quests this NPC can give
    [hashtable]$RelationshipData   # Relationship with player

    # Combat (if applicable)
    [hashtable]$CombatStats        # Combat-related statistics
    [array]$Abilities              # Special abilities
    [string]$Faction               # Faction allegiance
    [string]$HostilityLevel        # Hostility towards player

    # Schedule & Availability
    [hashtable]$Schedule           # Daily/weekly schedule
    [array]$AvailableHours         # When NPC is available
    [bool]$IsCurrentlyAvailable   # Current availability status
}
```

### NPC Specializations

#### Companion NPC
```powershell
class Companion : NPC {
    # Companion-specific properties
    [string]$CompanionType         # Type of companion
    [hashtable]$LoyaltyData        # Loyalty/affection system
    [array]$LearnedBehaviors       # Learned player preferences
    [hashtable]$CombatRole         # Role in combat
    [bool]$IsRecruited             # Whether currently recruited
    [DateTime]$RecruitedAt         # When recruited
    [hashtable]$Equipment          # Companion equipment
    [array]$SpecialAbilities       # Unique companion abilities
}
```

#### Vendor NPC
```powershell
class Vendor : NPC {
    # Vendor-specific properties
    [string]$VendorType            # Type of vendor (General, Weapons, etc.)
    [array]$ItemCategories         # Categories of items sold
    [hashtable]$PriceModifiers     # Price adjustment factors
    [decimal]$RepairCost           # Cost for repair services
    [bool]$BuysItems               # Whether vendor buys items
    [array]$PreferredItems         # Items vendor prefers to buy
    [hashtable]$RestockSchedule    # When inventory restocks
    [decimal]$AvailableCurrency    # Vendor's available money
}
```

---

## Item Model

### Base Item Structure

```powershell
class Item : Entity {
    # Core Properties
    [string]$ItemType              # Item category/type
    [string]$Rarity               # Rarity level
    [int]$StackSize               # Maximum stack size
    [decimal]$Weight               # Item weight
    [decimal]$Value                # Base value
    [string]$IconPath              # Icon image path

    # Usage Properties
    [bool]$IsConsumable            # Can be consumed/used
    [bool]$IsEquippable            # Can be equipped
    [bool]$IsTradeable             # Can be traded
    [bool]$IsDroppable            # Can be dropped
    [int]$Durability              # Current durability
    [int]$MaxDurability           # Maximum durability

    # Requirements
    [hashtable]$Requirements       # Usage requirements
    [int]$LevelRequirement         # Level required to use
    [array]$ClassRestrictions      # Class restrictions

    # Effects
    [array]$Effects                # Item effects when used/equipped
    [hashtable]$Bonuses            # Stat bonuses
    [array]$EnchantmentSlots       # Available enchantment slots
    [array]$CurrentEnchantments    # Current enchantments

    # Crafting
    [bool]$IsCraftable             # Can be crafted
    [array]$CraftingRecipe         # Recipe to craft this item
    [string]$CraftingSkill         # Required crafting skill
    [int]$CraftingLevel            # Required crafting level

    # Lore & Story
    [string]$FlavorText            # Lore/flavor description
    [string]$OriginStory           # Item's origin story
    [bool]$IsQuestItem             # Quest-related item
    [string]$QuestId               # Associated quest ID
}
```

### Item Specializations

#### Equipment Item
```powershell
class Equipment : Item {
    # Equipment-specific properties
    [string]$EquipmentSlot         # Equipment slot (Head, Chest, etc.)
    [hashtable]$StatModifiers      # Stat modifications
    [array]$SetBonuses             # Set bonus information
    [string]$SetName               # Equipment set name
    [hashtable]$SocketedGems       # Socketed gems/runes
    [int]$UpgradeLevel             # Enhancement level
    [decimal]$UpgradeCost          # Cost to upgrade
}
```

#### Consumable Item
```powershell
class Consumable : Item {
    # Consumable-specific properties
    [int]$UsesRemaining            # Number of uses left
    [TimeSpan]$CooldownDuration    # Cooldown between uses
    [DateTime]$LastUsed            # When last used
    [array]$ImmediateEffects       # Instant effects
    [array]$OverTimeEffects        # Effects over time
    [bool]$RequiresTarget          # Needs target to use
    [decimal]$EffectPotency        # Effect strength
}
```

#### Weapon
```powershell
class Weapon : Equipment {
    # Weapon-specific properties
    [string]$WeaponType            # Weapon category
    [hashtable]$DamageData         # Damage information
    [decimal]$AttackSpeed          # Attack speed
    [decimal]$CriticalChance       # Critical hit chance
    [decimal]$CriticalMultiplier   # Critical damage multiplier
    [array]$WeaponSkills           # Associated weapon skills
    [hashtable]$SpecialAttacks     # Special attack abilities
    [int]$Range                    # Weapon range
}
```

---

## Inheritance Patterns

### 1. **Single Table Inheritance**
All entities share a common base structure with type discriminators.

```powershell
# Type Discriminator Pattern
$EntityTypes = @{
    'player' = 'Player'
    'npc.companion' = 'Companion'
    'npc.vendor' = 'Vendor'
    'npc.enemy' = 'Enemy'
    'item.weapon' = 'Weapon'
    'item.armor' = 'Armor'
    'item.consumable' = 'Consumable'
}
```

### 2. **Composition over Inheritance**
Complex behaviors implemented as components.

```powershell
# Component System
class EntityComponent {
    [string]$ComponentType
    [hashtable]$ComponentData
    [bool]$IsEnabled
}

# Example: Inventory Component
$InventoryComponent = @{
    ComponentType = 'Inventory'
    ComponentData = @{
        Items = @()
        Capacity = 30
        Weight = 0.0
        MaxWeight = 100.0
    }
    IsEnabled = $true
}
```

### 3. **Mixin Pattern**
Reusable behavior modules.

```powershell
# Mixin: Combatant
$CombatantMixin = @{
    Health = @{ Current = 100; Maximum = 100 }
    Mana = @{ Current = 50; Maximum = 50 }
    Armor = 10
    Resistances = @{}
    StatusEffects = @()
}

# Mixin: Tradeable
$TradeableMixin = @{
    TradeValue = 0
    IsTradeable = $true
    TradeRestrictions = @()
}
```

---

## Serialization Architecture

### 1. **JSON Schema Definitions**

#### Entity Schema
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "id": { "type": "string", "format": "uuid" },
    "type": { "type": "string", "enum": ["Entity", "Player", "NPC", "Item"] },
    "name": { "type": "string", "minLength": 1, "maxLength": 100 },
    "description": { "type": "string", "maxLength": 1000 },
    "tags": { "type": "object" },
    "metadata": { "type": "object" },
    "createdAt": { "type": "string", "format": "date-time" },
    "updatedAt": { "type": "string", "format": "date-time" },
    "version": { "type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$" },
    "isActive": { "type": "boolean" },
    "customProperties": { "type": "object" }
  },
  "required": ["id", "type", "name", "createdAt", "updatedAt", "version", "isActive"]
}
```

### 2. **PowerShell Serialization Functions**

```powershell
function ConvertTo-GameEntity {
    param(
        [hashtable]$EntityData,
        [string]$EntityType
    )

    # Add type discriminator
    $EntityData.Type = $EntityType

    # Ensure required timestamps
    if (-not $EntityData.CreatedAt) {
        $EntityData.CreatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    }
    if (-not $EntityData.UpdatedAt) {
        $EntityData.UpdatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    }

    # Generate ID if missing
    if (-not $EntityData.Id) {
        $EntityData.Id = [System.Guid]::NewGuid().ToString()
    }

    # Set default version
    if (-not $EntityData.Version) {
        $EntityData.Version = '1.0.0'
    }

    return $EntityData
}

function ConvertTo-JsonSafe {
    param(
        [object]$InputObject,
        [int]$Depth = 10
    )

    # Handle PowerShell-specific types
    $jsonData = $InputObject | ConvertTo-Json -Depth $Depth

    # Clean up PowerShell-specific artifacts
    $jsonData = $jsonData -replace '@{', '{'
    $jsonData = $jsonData -replace ';}', '}'

    return $jsonData
}

function ConvertFrom-JsonSafe {
    param(
        [string]$JsonString
    )

    try {
        $object = $JsonString | ConvertFrom-Json
        return Convert-PSCustomObjectToHashtable -InputObject $object
    }
    catch {
        Write-Error "Failed to deserialize JSON: $($_.Exception.Message)"
        return $null
    }
}

function Convert-PSCustomObjectToHashtable {
    param(
        [object]$InputObject
    )

    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $hashtable = @{}
        $InputObject.PSObject.Properties | ForEach-Object {
            $hashtable[$_.Name] = Convert-PSCustomObjectToHashtable -InputObject $_.Value
        }
        return $hashtable
    }
    elseif ($InputObject -is [System.Array]) {
        return @($InputObject | ForEach-Object { Convert-PSCustomObjectToHashtable -InputObject $_ })
    }
    else {
        return $InputObject
    }
}
```

### 3. **JavaScript Deserialization**

```javascript
class EntityDeserializer {
    static fromJson(jsonString) {
        try {
            const data = JSON.parse(jsonString);
            return this.createEntity(data);
        } catch (error) {
            console.error('Failed to deserialize entity:', error);
            return null;
        }
    }

    static createEntity(data) {
        switch (data.type) {
            case 'Player':
                return new Player(data);
            case 'NPC':
            case 'npc.companion':
                return new Companion(data);
            case 'npc.vendor':
                return new Vendor(data);
            case 'Item':
            case 'item.weapon':
                return new Weapon(data);
            case 'item.consumable':
                return new Consumable(data);
            default:
                return new Entity(data);
        }
    }

    static validateEntity(entity) {
        const required = ['id', 'type', 'name', 'createdAt', 'updatedAt', 'version', 'isActive'];
        return required.every(prop => entity.hasOwnProperty(prop) && entity[prop] !== null);
    }
}
```

---

## PowerShell-JavaScript Communication

### 1. **Message Protocol**

```powershell
# PowerShell Message Structure
$GameMessage = @{
    MessageId = [System.Guid]::NewGuid().ToString()
    MessageType = 'EntityUpdate'  # EntityUpdate, EntityCreate, EntityDelete, etc.
    Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    Source = 'PowerShell'
    Target = 'JavaScript'
    Payload = @{
        EntityId = $entity.Id
        EntityType = $entity.Type
        Action = 'Update'
        Data = $entity
        ChangeSet = @{
            ModifiedProperties = @('Health', 'Location')
            PreviousValues = @{ Health = 80; Location = 'oldloc' }
            NewValues = @{ Health = 90; Location = 'newloc' }
        }
    }
    Metadata = @{
        RequestId = $null
        Priority = 'Normal'
        RequiresAck = $false
    }
}
```

### 2. **Entity Synchronization**

```powershell
function Sync-EntityToJavaScript {
    param(
        [hashtable]$Entity,
        [string]$Action = 'Update'
    )

    $syncMessage = @{
        MessageType = 'EntitySync'
        Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        Payload = @{
            Action = $Action
            Entity = $Entity
            SyncId = [System.Guid]::NewGuid().ToString()
        }
    }

    # Add to event queue for JavaScript consumption
    Send-GameEvent -EventType 'entity.sync' -Data $syncMessage
}

function Request-EntityFromJavaScript {
    param(
        [string]$EntityId,
        [string]$EntityType
    )

    $requestMessage = @{
        MessageType = 'EntityRequest'
        Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        Payload = @{
            EntityId = $EntityId
            EntityType = $EntityType
            RequestId = [System.Guid]::NewGuid().ToString()
        }
    }

    # Send request command to JavaScript
    Send-GameEvent -EventType 'entity.request' -Data $requestMessage
}
```

### 3. **Change Tracking**

```powershell
class EntityChangeTracker {
    [hashtable]$OriginalValues
    [hashtable]$CurrentValues
    [array]$ModifiedProperties
    [DateTime]$LastModified

    EntityChangeTracker([hashtable]$Entity) {
        $this.OriginalValues = $Entity.Clone()
        $this.CurrentValues = $Entity
        $this.ModifiedProperties = @()
        $this.LastModified = Get-Date
    }

    [void] TrackChange([string]$PropertyName, [object]$NewValue) {
        if ($this.CurrentValues[$PropertyName] -ne $NewValue) {
            if ($this.ModifiedProperties -notcontains $PropertyName) {
                $this.ModifiedProperties += $PropertyName
            }
            $this.CurrentValues[$PropertyName] = $NewValue
            $this.LastModified = Get-Date
        }
    }

    [hashtable] GetChangeSet() {
        $changeSet = @{
            ModifiedProperties = $this.ModifiedProperties
            PreviousValues = @{}
            NewValues = @{}
            LastModified = $this.LastModified.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        }

        foreach ($prop in $this.ModifiedProperties) {
            $changeSet.PreviousValues[$prop] = $this.OriginalValues[$prop]
            $changeSet.NewValues[$prop] = $this.CurrentValues[$prop]
        }

        return $changeSet
    }
}
```

---

## Data Validation

### 1. **PowerShell Validation**

```powershell
function Test-EntityValidity {
    param(
        [hashtable]$Entity,
        [string]$EntityType
    )

    $validationResults = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }

    # Required field validation
    $requiredFields = @('Id', 'Type', 'Name', 'CreatedAt', 'UpdatedAt', 'Version', 'IsActive')
    foreach ($field in $requiredFields) {
        if (-not $Entity.ContainsKey($field) -or [string]::IsNullOrEmpty($Entity[$field])) {
            $validationResults.Errors += "Required field '$field' is missing or empty"
            $validationResults.IsValid = $false
        }
    }

    # Type-specific validation
    switch ($EntityType) {
        'Player' {
            if ($Entity.Level -lt 1 -or $Entity.Level -gt 100) {
                $validationResults.Errors += "Player level must be between 1 and 100"
                $validationResults.IsValid = $false
            }
        }
        'Item' {
            if ($Entity.Value -lt 0) {
                $validationResults.Errors += "Item value cannot be negative"
                $validationResults.IsValid = $false
            }
        }
    }

    # GUID validation
    try {
        [System.Guid]::Parse($Entity.Id) | Out-Null
    }
    catch {
        $validationResults.Errors += "Invalid GUID format for Id"
        $validationResults.IsValid = $false
    }

    return $validationResults
}
```

### 2. **JavaScript Validation**

```javascript
class EntityValidator {
    static validate(entity) {
        const result = {
            isValid: true,
            errors: [],
            warnings: []
        };

        // Required fields
        const required = ['id', 'type', 'name', 'createdAt', 'updatedAt', 'version', 'isActive'];
        required.forEach(field => {
            if (!entity.hasOwnProperty(field) || entity[field] === null || entity[field] === undefined) {
                result.errors.push(`Required field '${field}' is missing`);
                result.isValid = false;
            }
        });

        // Type-specific validation
        if (entity.type === 'Player') {
            if (entity.level < 1 || entity.level > 100) {
                result.errors.push('Player level must be between 1 and 100');
                result.isValid = false;
            }
        }

        // GUID validation
        const guidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
        if (!guidRegex.test(entity.id)) {
            result.errors.push('Invalid GUID format for id');
            result.isValid = false;
        }

        return result;
    }
}
```

---

## Performance Considerations

### 1. **Lazy Loading**

```powershell
function Get-EntityWithLazyLoading {
    param(
        [string]$EntityId,
        [array]$IncludeProperties = @()
    )

    # Load base entity
    $entity = Get-BaseEntity -EntityId $EntityId

    # Load additional properties on demand
    foreach ($property in $IncludeProperties) {
        switch ($property) {
            'Inventory' {
                $entity.Inventory = Get-EntityInventory -EntityId $EntityId
            }
            'Achievements' {
                $entity.Achievements = Get-EntityAchievements -EntityId $EntityId
            }
            'Statistics' {
                $entity.Statistics = Get-EntityStatistics -EntityId $EntityId
            }
        }
    }

    return $entity
}
```

### 2. **Data Compression**

```powershell
function Compress-EntityData {
    param(
        [hashtable]$Entity
    )

    # Remove empty/default values
    $compressedEntity = @{}
    foreach ($key in $Entity.Keys) {
        $value = $Entity[$key]
        if ($null -ne $value -and $value -ne '' -and $value -ne 0 -and $value -ne @()) {
            $compressedEntity[$key] = $value
        }
    }

    return $compressedEntity
}
```

### 3. **Batch Operations**

```powershell
function Update-EntitiesBatch {
    param(
        [array]$EntityUpdates
    )

    $batchResults = @{
        Successful = @()
        Failed = @()
        ProcessedCount = 0
    }

    # Process in chunks to avoid memory issues
    $chunkSize = 100
    for ($i = 0; $i -lt $EntityUpdates.Count; $i += $chunkSize) {
        $chunk = $EntityUpdates[$i..([Math]::Min($i + $chunkSize - 1, $EntityUpdates.Count - 1))]

        foreach ($update in $chunk) {
            try {
                Update-Entity -Entity $update
                $batchResults.Successful += $update.Id
            }
            catch {
                $batchResults.Failed += @{
                    EntityId = $update.Id
                    Error = $_.Exception.Message
                }
            }
            $batchResults.ProcessedCount++
        }
    }

    return $batchResults
}
```

---

## Implementation Examples

### 1. **Creating a Player Entity**

```powershell
# PowerShell Implementation
function New-PlayerEntity {
    param(
        [string]$Username,
        [string]$Email,
        [string]$DisplayName
    )

    $player = ConvertTo-GameEntity -EntityData @{
        # Base Entity Properties
        Name = $DisplayName
        Description = "Player character for $Username"
        Tags = @{ PlayerType = 'Human'; NewPlayer = $true }

        # Player-specific Properties
        Username = $Username
        Email = $Email
        DisplayName = $DisplayName
        Level = 1
        Experience = 0
        ExperienceToNext = 1000

        Attributes = @{
            Strength = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Dexterity = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Intelligence = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Constitution = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Wisdom = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Charisma = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
        }

        Skills = @{
            Combat = @{ Level = 1; Experience = 0; Specializations = @() }
            Exploration = @{ Level = 1; Experience = 0; Specializations = @() }
            Social = @{ Level = 1; Experience = 0; Specializations = @() }
            Crafting = @{ Level = 1; Experience = 0; Specializations = @() }
        }

        Location = @{ Id = 'starting_area'; Name = 'Starting Area'; Coordinates = @(0, 0) }
        LastLocationId = 'starting_area'
        VisitedLocations = @('starting_area')
        Score = 0
        GameState = 'Active'

        Inventory = @()
        Equipment = @{
            Head = $null; Chest = $null; Legs = $null; Feet = $null
            MainHand = $null; OffHand = $null; Ring1 = $null; Ring2 = $null
        }
        InventoryCapacity = 30
        Currency = 100

        Achievements = @()
        QuestProgress = @{}
        Statistics = @{
            LocationsVisited = 1
            QuestsCompleted = 0
            ItemsCollected = 0
            EnemiesDefeated = 0
        }
        CompletedQuests = @()

        Friends = @()
        GuildId = $null
        Reputation = @{}

        Preferences = @{
            AutoSave = $true
            ShowTutorials = $true
            DifficultyLevel = 'Normal'
        }
        UISettings = @{
            Theme = 'Default'
            FontSize = 'Medium'
            ShowMinimap = $true
        }
        Theme = 'Default'

        LastLogin = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        PlayTime = [TimeSpan]::Zero
        SessionStart = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        IsOnline = $true

        BackupData = ''
        LastBackup = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    } -EntityType 'Player'

    # Validate the created player
    $validation = Test-EntityValidity -Entity $player -EntityType 'Player'
    if (-not $validation.IsValid) {
        throw "Failed to create valid player entity: $($validation.Errors -join ', ')"
    }

    return $player
}
```

### 2. **Creating an Item Entity**

```powershell
function New-WeaponEntity {
    param(
        [string]$Name,
        [string]$WeaponType,
        [hashtable]$DamageData,
        [string]$Rarity = 'Common'
    )

    $weapon = ConvertTo-GameEntity -EntityData @{
        # Base Entity Properties
        Name = $Name
        Description = "A $Rarity $WeaponType weapon"
        Tags = @{ Category = 'Weapon'; Rarity = $Rarity; Type = $WeaponType }

        # Item Properties
        ItemType = 'Weapon'
        Rarity = $Rarity
        StackSize = 1
        Weight = 2.5
        Value = 100
        IconPath = "weapons/$($WeaponType.ToLower()).png"

        IsConsumable = $false
        IsEquippable = $true
        IsTradeable = $true
        IsDroppable = $true
        Durability = 100
        MaxDurability = 100

        Requirements = @{
            Level = 1
            Strength = 8
        }
        LevelRequirement = 1
        ClassRestrictions = @()

        Effects = @()
        Bonuses = @{
            Damage = $DamageData.BaseDamage
            CriticalChance = 0.05
        }
        EnchantmentSlots = 2
        CurrentEnchantments = @()

        IsCraftable = $true
        CraftingRecipe = @(
            @{ ItemId = 'iron_ingot'; Quantity = 2 }
            @{ ItemId = 'leather_strip'; Quantity = 1 }
        )
        CraftingSkill = 'Blacksmithing'
        CraftingLevel = 5

        FlavorText = "A well-crafted $WeaponType, balanced and sharp."
        OriginStory = "Forged by a skilled blacksmith in the capital city."
        IsQuestItem = $false
        QuestId = $null

        # Equipment Properties
        EquipmentSlot = 'MainHand'
        StatModifiers = @{
            Strength = 2
            AttackPower = $DamageData.BaseDamage
        }
        SetBonuses = @()
        SetName = $null
        SocketedGems = @()
        UpgradeLevel = 0
        UpgradeCost = 50

        # Weapon Properties
        WeaponType = $WeaponType
        DamageData = $DamageData
        AttackSpeed = 1.2
        CriticalChance = 0.05
        CriticalMultiplier = 2.0
        WeaponSkills = @($WeaponType)
        SpecialAttacks = @()
        Range = 1
    } -EntityType 'Item'

    return $weapon
}
```

### 3. **JavaScript Entity Usage**

```javascript
// JavaScript Implementation
class GameEntityManager {
    constructor() {
        this.entities = new Map();
        this.changeTrackers = new Map();
    }

    createPlayer(playerData) {
        const player = new Player({
            ...playerData,
            type: 'Player',
            level: playerData.level || 1,
            experience: playerData.experience || 0,
            attributes: playerData.attributes || this.getDefaultAttributes(),
            inventory: playerData.inventory || [],
            achievements: playerData.achievements || []
        });

        const validation = EntityValidator.validate(player);
        if (!validation.isValid) {
            throw new Error(`Invalid player data: ${validation.errors.join(', ')}`);
        }

        this.entities.set(player.id, player);
        this.changeTrackers.set(player.id, new EntityChangeTracker(player));

        return player;
    }

    updateEntity(entityId, updates) {
        const entity = this.entities.get(entityId);
        if (!entity) {
            throw new Error(`Entity not found: ${entityId}`);
        }

        const changeTracker = this.changeTrackers.get(entityId);

        Object.keys(updates).forEach(key => {
            if (entity[key] !== updates[key]) {
                changeTracker.trackChange(key, updates[key]);
                entity[key] = updates[key];
            }
        });

        entity.updatedAt = new Date().toISOString();

        // Notify PowerShell of changes
        this.syncWithPowerShell(entity, changeTracker.getChangeSet());
    }

    syncWithPowerShell(entity, changeSet) {
        const syncMessage = {
            messageType: 'EntitySync',
            timestamp: new Date().toISOString(),
            payload: {
                action: 'Update',
                entity: entity,
                changeSet: changeSet
            }
        };

        // Send to PowerShell via command queue
        window.gameEventManager.sendCommandToPowerShell('entity.sync', syncMessage);
    }

    getDefaultAttributes() {
        return {
            strength: { base: 10, current: 10, modifiers: [], maximum: 20 },
            dexterity: { base: 10, current: 10, modifiers: [], maximum: 20 },
            intelligence: { base: 10, current: 10, modifiers: [], maximum: 20 },
            constitution: { base: 10, current: 10, modifiers: [], maximum: 20 },
            wisdom: { base: 10, current: 10, modifiers: [], maximum: 20 },
            charisma: { base: 10, current: 10, modifiers: [], maximum: 20 }
        };
    }
}

class EntityChangeTracker {
    constructor(entity) {
        this.originalValues = JSON.parse(JSON.stringify(entity));
        this.modifiedProperties = [];
        this.lastModified = new Date();
    }

    trackChange(propertyName, newValue) {
        if (!this.modifiedProperties.includes(propertyName)) {
            this.modifiedProperties.push(propertyName);
        }
        this.lastModified = new Date();
    }

    getChangeSet() {
        const changeSet = {
            modifiedProperties: this.modifiedProperties,
            previousValues: {},
            newValues: {},
            lastModified: this.lastModified.toISOString()
        };

        this.modifiedProperties.forEach(prop => {
            changeSet.previousValues[prop] = this.originalValues[prop];
            changeSet.newValues[prop] = this.currentEntity[prop];
        });

        return changeSet;
    }
}
```

---

## Conclusion

This comprehensive specification provides a robust foundation for the core data models in your PowerShell Leafmap RPG game. The design emphasizes:

- **Flexibility**: Extensible inheritance patterns and component systems
- **Reliability**: Strong validation and error handling
- **Performance**: Efficient serialization and lazy loading
- **Maintainability**: Clear structure and consistent patterns
- **Interoperability**: Seamless PowerShell-JavaScript communication

The implementation supports complex gameplay scenarios while maintaining data integrity and providing excellent developer experience across both PowerShell and JavaScript environments.
