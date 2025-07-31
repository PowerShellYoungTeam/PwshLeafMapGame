# Entity Data Models Module
# Implements the core data models for PowerShell Leafmap RPG
# Enhanced with property change tracking and full entity management

# String constants for entity types (no enums)
$script:EntityTypes = @{
    Base = 'Entity'
    Player = 'Player'
    NPC = 'NPC'
    Item = 'Item'
    Location = 'Location'
    Quest = 'Quest'
    Faction = 'Faction'
}

$script:ItemCategories = @{
    Weapon = 'Weapon'
    Armor = 'Armor'
    Consumable = 'Consumable'
    KeyItem = 'KeyItem'
    Material = 'Material'
    Tool = 'Tool'
    Accessory = 'Accessory'
}

$script:NPCBehaviorTypes = @{
    Friendly = 'Friendly'
    Neutral = 'Neutral'
    Hostile = 'Hostile'
    Vendor = 'Vendor'
    QuestGiver = 'QuestGiver'
}

$script:QuestTypes = @{
    Main = 'Main'
    Side = 'Side'
    Repeatable = 'Repeatable'
    Daily = 'Daily'
    Event = 'Event'
}

$script:QuestStatus = @{
    NotStarted = 'NotStarted'
    Available = 'Available'
    InProgress = 'InProgress'
    Completed = 'Completed'
    Failed = 'Failed'
    Abandoned = 'Abandoned'
}

# Base Entity Class with property change tracking
class GameEntity {
    [string]$Id
    [string]$Type
    [string]$Name
    [string]$Description
    [hashtable]$Tags
    [hashtable]$Metadata
    [DateTime]$CreatedAt
    [DateTime]$UpdatedAt
    [string]$Version
    [bool]$IsActive
    [hashtable]$Properties

    # Change tracking properties
    [hashtable]$OriginalValues
    [hashtable]$PropertyChanges
    [bool]$IsTrackingChanges

    GameEntity() {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Type = $script:EntityTypes.Base
        $this.Name = ''
        $this.Description = ''
        $this.Tags = @{}
        $this.Metadata = @{}
        $this.CreatedAt = Get-Date
        $this.UpdatedAt = Get-Date
        $this.Version = '1.0.0'
        $this.IsActive = $true
        $this.Properties = @{}

        # Initialize change tracking
        $this.OriginalValues = @{}
        $this.PropertyChanges = @{}
        $this.IsTrackingChanges = $true

        $this.InitializeDefaults()
        $this.StartChangeTracking()
    }

    GameEntity([hashtable]$Data) {
        $this.Id = if ($Data.Id) { $Data.Id } else { [System.Guid]::NewGuid().ToString() }
        $this.Type = if ($Data.Type) { $Data.Type } else { $script:EntityTypes.Base }
        $this.Name = if ($Data.Name) { $Data.Name } else { '' }
        $this.Description = if ($Data.Description) { $Data.Description } else { '' }
        $this.Tags = if ($Data.Tags) { $Data.Tags } else { @{} }
        $this.Metadata = if ($Data.Metadata) { $Data.Metadata } else { @{} }
        $this.CreatedAt = if ($Data.CreatedAt) { [DateTime]$Data.CreatedAt } else { Get-Date }
        $this.UpdatedAt = if ($Data.UpdatedAt) { [DateTime]$Data.UpdatedAt } else { Get-Date }
        $this.Version = if ($Data.Version) { $Data.Version } else { '1.0.0' }
        $this.IsActive = if ($null -ne $Data.IsActive) { $Data.IsActive } else { $true }
        $this.Properties = if ($Data.Properties) { $Data.Properties } else { @{} }

        # Initialize change tracking
        $this.OriginalValues = @{}
        $this.PropertyChanges = @{}
        $this.IsTrackingChanges = $true

        $this.InitializeDefaults()
        $this.StartChangeTracking()
    }

    # Virtual method for derived classes to override
    [void] InitializeDefaults() {
        # Override in derived classes
    }

    # Property management methods
    [void] SetProperty([string]$Name, [object]$Value) {
        $this.SetProperty($Name, $Value, $true)
    }

    [void] SetProperty([string]$Name, [object]$Value, [bool]$TriggerEvent) {
        $oldValue = $this.Properties[$Name]
        $this.Properties[$Name] = $Value
        $this.UpdatedAt = Get-Date

        # Track changes if enabled
        if ($this.IsTrackingChanges) {
            if (-not $this.OriginalValues.ContainsKey($Name)) {
                $this.OriginalValues[$Name] = $oldValue
            }

            $this.PropertyChanges[$Name] = @{
                OldValue = $oldValue
                NewValue = $Value
                Timestamp = Get-Date
            }
        }

        # Trigger property changed event if requested
        if ($TriggerEvent) {
            $this.OnPropertyChanged($Name, $oldValue, $Value)
        }
    }

    [object] GetProperty([string]$Name) {
        return $this.Properties[$Name]
    }

    [object] GetProperty([string]$Name, [object]$DefaultValue) {
        if ($this.Properties.ContainsKey($Name)) {
            return $this.Properties[$Name]
        }
        return $DefaultValue
    }

    [bool] HasProperty([string]$Name) {
        return $this.Properties.ContainsKey($Name)
    }

    [void] RemoveProperty([string]$Name) {
        if ($this.Properties.ContainsKey($Name)) {
            $oldValue = $this.Properties[$Name]
            $this.Properties.Remove($Name)
            $this.UpdatedAt = Get-Date

            if ($this.IsTrackingChanges) {
                if (-not $this.OriginalValues.ContainsKey($Name)) {
                    $this.OriginalValues[$Name] = $oldValue
                }

                $this.PropertyChanges[$Name] = @{
                    OldValue = $oldValue
                    NewValue = $null
                    Timestamp = Get-Date
                    Action = 'Removed'
                }
            }

            $this.OnPropertyChanged($Name, $oldValue, $null)
        }
    }

    # Change tracking methods
    [void] StartChangeTracking() {
        $this.IsTrackingChanges = $true
        $this.OriginalValues = @{}
        $this.PropertyChanges = @{}

        # Capture current state as baseline
        foreach ($key in $this.Properties.Keys) {
            $this.OriginalValues[$key] = $this.Properties[$key]
        }
    }

    [void] StopChangeTracking() {
        $this.IsTrackingChanges = $false
    }

    [void] AcceptChanges() {
        $this.OriginalValues = @{}
        $this.PropertyChanges = @{}

        # Capture current state as new baseline
        foreach ($key in $this.Properties.Keys) {
            $this.OriginalValues[$key] = $this.Properties[$key]
        }
    }

    [void] RejectChanges() {
        if ($this.IsTrackingChanges) {
            # Restore original values
            foreach ($key in $this.OriginalValues.Keys) {
                $this.Properties[$key] = $this.OriginalValues[$key]
            }

            # Clear change tracking
            $this.PropertyChanges = @{}
            $this.UpdatedAt = Get-Date
        }
    }

    [hashtable] GetChanges() {
        return $this.PropertyChanges.Clone()
    }

    [bool] HasChanges() {
        return $this.PropertyChanges.Count -gt 0
    }

    [array] GetChangedProperties() {
        return @($this.PropertyChanges.Keys)
    }

    # Event handling (virtual method)
    [void] OnPropertyChanged([string]$PropertyName, [object]$OldValue, [object]$NewValue) {
        # Override in derived classes for custom event handling
        Write-Verbose "Property '$PropertyName' changed from '$OldValue' to '$NewValue' on entity '$($this.Id)'"
    }

    # Serialization methods
    [hashtable] ToHashtable() {
        return $this.ToHashtable(5)
    }

    [hashtable] ToHashtable([int]$Depth) {
        $result = @{
            Id = $this.Id
            Type = $this.Type
            Name = $this.Name
            Description = $this.Description
            Tags = $this.Tags
            Metadata = $this.Metadata
            CreatedAt = $this.CreatedAt
            UpdatedAt = $this.UpdatedAt
            Version = $this.Version
            IsActive = $this.IsActive
            Properties = $this.Properties
        }

        if ($Depth -gt 0) {
            $result.OriginalValues = $this.OriginalValues
            $result.PropertyChanges = $this.PropertyChanges
            $result.IsTrackingChanges = $this.IsTrackingChanges
        }

        return $result
    }

    [string] ToJson() {
        return $this.ToJson(5)
    }

    [string] ToJson([int]$Depth) {
        $data = $this.ToHashtable($Depth)
        return $data | ConvertTo-Json -Depth $Depth -Compress
    }

    [string] ToString() {
        return "$($this.Type): $($this.Name) ($($this.Id))"
    }
}

# Player Entity Class
class Player : GameEntity {
    Player() : base() {
        $this.Type = $script:EntityTypes.Player
        $this.InitializeDefaults()
    }

    Player([hashtable]$Data) : base($Data) {
        $this.Type = $script:EntityTypes.Player
        $this.InitializeDefaults()

        # Load Player-specific data without triggering events
        if ($Data.ContainsKey('Username')) { $this.SetProperty('Username', $Data.Username, $false) }
        if ($Data.ContainsKey('Email')) { $this.SetProperty('Email', $Data.Email, $false) }
        if ($Data.ContainsKey('Level')) { $this.SetProperty('Level', $Data.Level, $false) }
        if ($Data.ContainsKey('Experience')) { $this.SetProperty('Experience', $Data.Experience, $false) }
        if ($Data.ContainsKey('Health')) { $this.SetProperty('Health', $Data.Health, $false) }
        if ($Data.ContainsKey('MaxHealth')) { $this.SetProperty('MaxHealth', $Data.MaxHealth, $false) }
        if ($Data.ContainsKey('Mana')) { $this.SetProperty('Mana', $Data.Mana, $false) }
        if ($Data.ContainsKey('MaxMana')) { $this.SetProperty('MaxMana', $Data.MaxMana, $false) }
        if ($Data.ContainsKey('Attributes')) { $this.SetProperty('Attributes', $Data.Attributes, $false) }
        if ($Data.ContainsKey('Skills')) { $this.SetProperty('Skills', $Data.Skills, $false) }
        if ($Data.ContainsKey('Inventory')) { $this.SetProperty('Inventory', $Data.Inventory, $false) }
        if ($Data.ContainsKey('Equipment')) { $this.SetProperty('Equipment', $Data.Equipment, $false) }
        if ($Data.ContainsKey('CurrentLocationId')) { $this.SetProperty('CurrentLocationId', $Data.CurrentLocationId, $false) }
        if ($Data.ContainsKey('Quests')) { $this.SetProperty('Quests', $Data.Quests, $false) }
        if ($Data.ContainsKey('CompletedQuests')) { $this.SetProperty('CompletedQuests', $Data.CompletedQuests, $false) }
        if ($Data.ContainsKey('Currency')) { $this.SetProperty('Currency', $Data.Currency, $false) }
        if ($Data.ContainsKey('FactionStandings')) { $this.SetProperty('FactionStandings', $Data.FactionStandings, $false) }

        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Player account info
        $this.SetProperty('Username', '', $false)
        $this.SetProperty('Email', '', $false)
        $this.SetProperty('LastLogin', (Get-Date), $false)

        # Character progression
        $this.SetProperty('Level', 1, $false)
        $this.SetProperty('Experience', 0, $false)
        $this.SetProperty('ExperienceToNextLevel', 1000, $false)

        # Health and combat
        $this.SetProperty('Health', 100, $false)
        $this.SetProperty('MaxHealth', 100, $false)
        $this.SetProperty('Mana', 50, $false)
        $this.SetProperty('MaxMana', 50, $false)
        $this.SetProperty('IsAlive', $true, $false)

        # Attributes
        $this.SetProperty('Attributes', @{
            Strength = 10; Dexterity = 10; Intelligence = 10
            Constitution = 10; Wisdom = 10; Charisma = 10
        }, $false)

        # Skills
        $this.SetProperty('Skills', @{}, $false)

        # Inventory and equipment
        $this.SetProperty('Inventory', @(), $false)
        $this.SetProperty('Equipment', @{
            Weapon = $null; Armor = $null; Helmet = $null
            Gloves = $null; Boots = $null; Ring1 = $null; Ring2 = $null
        }, $false)
        $this.SetProperty('InventoryCapacity', 50, $false)

        # Location and movement
        $this.SetProperty('CurrentLocationId', '', $false)
        $this.SetProperty('SpawnLocationId', '', $false)
        $this.SetProperty('Position', @{ X = 0; Y = 0; Z = 0 }, $false)

        # Quests and progression
        $this.SetProperty('Quests', @(), $false)
        $this.SetProperty('CompletedQuests', @(), $false)
        $this.SetProperty('Achievements', @(), $false)

        # Economy
        $this.SetProperty('Currency', 100, $false)
        $this.SetProperty('BankAccount', 0, $false)

        # Faction relationships
        $this.SetProperty('FactionStandings', @{}, $false)

        # Player settings
        $this.SetProperty('Settings', @{
            AutoSave = $true
            ShowNotifications = $true
            SoundEnabled = $true
        }, $false)
    }

    # Convenient property accessors
    [int] GetLevel() { return $this.GetProperty('Level', 1) }
    [void] SetLevel([int]$Value) { $this.SetProperty('Level', $Value) }

    [int] GetHealth() { return $this.GetProperty('Health', 100) }
    [void] SetHealth([int]$Value) { $this.SetProperty('Health', $Value) }

    [int] GetExperience() { return $this.GetProperty('Experience', 0) }
    [void] SetExperience([int]$Value) { $this.SetProperty('Experience', $Value) }

    [string] GetCurrentLocationId() { return $this.GetProperty('CurrentLocationId', '') }
    [void] SetCurrentLocationId([string]$Value) { $this.SetProperty('CurrentLocationId', $Value) }

    # Player-specific methods
    [void] AddExperience([int]$Amount) {
        $currentExp = $this.GetExperience()
        $newExp = $currentExp + $Amount
        $this.SetExperience($newExp)
        $this.CheckLevelUp()
    }

    [void] CheckLevelUp() {
        $currentLevel = $this.GetLevel()
        $currentExp = $this.GetExperience()
        $expNeeded = $this.GetProperty('ExperienceToNextLevel', 1000)

        if ($currentExp -ge $expNeeded) {
            $this.SetLevel($currentLevel + 1)
            $this.SetExperience($currentExp - $expNeeded)
            $this.SetProperty('ExperienceToNextLevel', ($currentLevel + 1) * 1000)
            $this.OnLevelUp($currentLevel + 1)
        }
    }

    [void] OnLevelUp([int]$NewLevel) {
        # Increase health and mana on level up
        $currentMaxHealth = $this.GetProperty('MaxHealth', 100)
        $currentMaxMana = $this.GetProperty('MaxMana', 50)

        $this.SetProperty('MaxHealth', $currentMaxHealth + 10)
        $this.SetProperty('MaxMana', $currentMaxMana + 5)
        $this.SetProperty('Health', $currentMaxHealth + 10)  # Full heal on level up
        $this.SetProperty('Mana', $currentMaxMana + 5)

        Write-Verbose "Player $($this.Name) leveled up to $NewLevel!"
    }

    [void] AddItemToInventory([hashtable]$Item) {
        $inventory = $this.GetProperty('Inventory', @())
        $inventory += $Item
        $this.SetProperty('Inventory', $inventory)
    }

    [bool] RemoveItemFromInventory([string]$ItemId, [int]$Quantity = 1) {
        $inventory = $this.GetProperty('Inventory', @())
        $found = $false

        for ($i = 0; $i -lt $inventory.Count; $i++) {
            if ($inventory[$i].Id -eq $ItemId) {
                if ($inventory[$i].Quantity -gt $Quantity) {
                    $inventory[$i].Quantity -= $Quantity
                } else {
                    $inventory = $inventory | Where-Object { $_.Id -ne $ItemId }
                }
                $found = $true
                break
            }
        }

        if ($found) {
            $this.SetProperty('Inventory', $inventory)
        }
        return $found
    }

    [void] AddQuest([string]$QuestId) {
        $quests = $this.GetProperty('Quests', @())
        if ($quests -notcontains $QuestId) {
            $quests += $QuestId
            $this.SetProperty('Quests', $quests)
        }
    }

    [void] CompleteQuest([string]$QuestId) {
        $quests = $this.GetProperty('Quests', @())
        $completedQuests = $this.GetProperty('CompletedQuests', @())

        $quests = $quests | Where-Object { $_ -ne $QuestId }
        $completedQuests += $QuestId

        $this.SetProperty('Quests', $quests)
        $this.SetProperty('CompletedQuests', $completedQuests)
    }
}

# NPC Entity Class
class NPC : GameEntity {
    NPC() : base() {
        $this.Type = $script:EntityTypes.NPC
        $this.InitializeDefaults()
    }

    NPC([hashtable]$Data) : base($Data) {
        $this.Type = $script:EntityTypes.NPC
        $this.InitializeDefaults()

        # Load NPC-specific data
        if ($Data.ContainsKey('NPCType')) { $this.SetProperty('NPCType', $Data.NPCType, $false) }
        if ($Data.ContainsKey('BehaviorType')) { $this.SetProperty('BehaviorType', $Data.BehaviorType, $false) }
        if ($Data.ContainsKey('Health')) { $this.SetProperty('Health', $Data.Health, $false) }
        if ($Data.ContainsKey('CurrentLocationId')) { $this.SetProperty('CurrentLocationId', $Data.CurrentLocationId, $false) }
        if ($Data.ContainsKey('FactionId')) { $this.SetProperty('FactionId', $Data.FactionId, $false) }
        if ($Data.ContainsKey('DialogOptions')) { $this.SetProperty('DialogOptions', $Data.DialogOptions, $false) }
        if ($Data.ContainsKey('Inventory')) { $this.SetProperty('Inventory', $Data.Inventory, $false) }
        if ($Data.ContainsKey('QuestsOffered')) { $this.SetProperty('QuestsOffered', $Data.QuestsOffered, $false) }
        if ($Data.ContainsKey('Schedule')) { $this.SetProperty('Schedule', $Data.Schedule, $false) }

        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Basic NPC information
        $this.SetProperty('NPCType', 'Generic', $false)
        $this.SetProperty('BehaviorType', $script:NPCBehaviorTypes.Neutral, $false)

        # Health and combat
        $this.SetProperty('Health', 100, $false)
        $this.SetProperty('MaxHealth', 100, $false)
        $this.SetProperty('IsAlive', $true, $false)

        # Location and movement
        $this.SetProperty('CurrentLocationId', '', $false)
        $this.SetProperty('SpawnLocationId', '', $false)
        $this.SetProperty('Position', @{ X = 0; Y = 0; Z = 0 }, $false)

        # Social and interaction
        $this.SetProperty('FactionId', '', $false)
        $this.SetProperty('DialogOptions', @(), $false)
        $this.SetProperty('RelationshipToPlayer', 0, $false)  # -100 to 100

        # Inventory and services
        $this.SetProperty('Inventory', @(), $false)
        $this.SetProperty('IsVendor', $false, $false)
        $this.SetProperty('VendorCategory', '', $false)
        $this.SetProperty('Currency', 0, $false)

        # Quests
        $this.SetProperty('QuestsOffered', @(), $false)

        # Scheduling
        $this.SetProperty('Schedule', @{}, $false)
        $this.SetProperty('IsCurrentlyAvailable', $true, $false)

        # AI and behavior
        $this.SetProperty('PersonalityTraits', @(), $false)
    }

    # Convenient property accessors
    [string] GetBehaviorType() { return $this.GetProperty('BehaviorType', $script:NPCBehaviorTypes.Neutral) }
    [void] SetBehaviorType([string]$Value) { $this.SetProperty('BehaviorType', $Value) }

    [int] GetHealth() { return $this.GetProperty('Health', 100) }
    [void] SetHealth([int]$Value) { $this.SetProperty('Health', $Value) }

    [string] GetCurrentLocationId() { return $this.GetProperty('CurrentLocationId', '') }
    [void] SetCurrentLocationId([string]$Value) { $this.SetProperty('CurrentLocationId', $Value) }

    # NPC-specific methods
    [void] AddDialogOption([hashtable]$DialogOption) {
        $options = $this.GetProperty('DialogOptions', @())
        $options += $DialogOption
        $this.SetProperty('DialogOptions', $options)
    }

    [void] AddQuestOffered([string]$QuestId) {
        $quests = $this.GetProperty('QuestsOffered', @())
        if ($quests -notcontains $QuestId) {
            $quests += $QuestId
            $this.SetProperty('QuestsOffered', $quests)
        }
    }
}

# Item Entity Class
class Item : GameEntity {
    Item() : base() {
        $this.Type = $script:EntityTypes.Item
        $this.InitializeDefaults()
    }

    Item([hashtable]$Data) : base($Data) {
        $this.Type = $script:EntityTypes.Item
        $this.InitializeDefaults()

        # Load Item-specific data
        if ($Data.ContainsKey('Category')) { $this.SetProperty('Category', $Data.Category, $false) }
        if ($Data.ContainsKey('Value')) { $this.SetProperty('Value', $Data.Value, $false) }
        if ($Data.ContainsKey('Weight')) { $this.SetProperty('Weight', $Data.Weight, $false) }
        if ($Data.ContainsKey('Rarity')) { $this.SetProperty('Rarity', $Data.Rarity, $false) }
        if ($Data.ContainsKey('Stackable')) { $this.SetProperty('Stackable', $Data.Stackable, $false) }
        if ($Data.ContainsKey('Durability')) { $this.SetProperty('Durability', $Data.Durability, $false) }
        if ($Data.ContainsKey('Effects')) { $this.SetProperty('Effects', $Data.Effects, $false) }

        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Basic item properties
        $this.SetProperty('Category', $script:ItemCategories.Material, $false)
        $this.SetProperty('Value', 1, $false)
        $this.SetProperty('Weight', 1.0, $false)
        $this.SetProperty('Rarity', 'Common', $false)

        # Stack and durability
        $this.SetProperty('Stackable', $true, $false)
        $this.SetProperty('MaxStackSize', 99, $false)
        $this.SetProperty('Durability', 100, $false)
        $this.SetProperty('MaxDurability', 100, $false)

        # Usage and effects
        $this.SetProperty('Consumable', $false, $false)
        $this.SetProperty('Effects', @(), $false)

        # Trading and economy
        $this.SetProperty('Tradeable', $true, $false)
        $this.SetProperty('Sellable', $true, $false)

        # Item state
        $this.SetProperty('IsEquipped', $false, $false)
        $this.SetProperty('EquipSlot', '', $false)
    }

    # Convenient property accessors
    [string] GetCategory() { return $this.GetProperty('Category', $script:ItemCategories.Material) }
    [void] SetCategory([string]$Value) { $this.SetProperty('Category', $Value) }

    [decimal] GetValue() { return $this.GetProperty('Value', 1) }
    [void] SetValue([decimal]$Value) { $this.SetProperty('Value', $Value) }

    [double] GetWeight() { return $this.GetProperty('Weight', 1.0) }
    [void] SetWeight([double]$Value) { $this.SetProperty('Weight', $Value) }
}

# Location Entity Class
class Location : GameEntity {
    Location() : base() {
        $this.Type = $script:EntityTypes.Location
        $this.InitializeDefaults()
    }

    Location([hashtable]$Data) : base($Data) {
        $this.Type = $script:EntityTypes.Location
        $this.InitializeDefaults()

        # Load Location-specific data
        if ($Data.ContainsKey('Coordinates')) { $this.SetProperty('Coordinates', $Data.Coordinates, $false) }
        if ($Data.ContainsKey('LocationType')) { $this.SetProperty('LocationType', $Data.LocationType, $false) }
        if ($Data.ContainsKey('ConnectedLocations')) { $this.SetProperty('ConnectedLocations', $Data.ConnectedLocations, $false) }
        if ($Data.ContainsKey('ResidentNPCs')) { $this.SetProperty('ResidentNPCs', $Data.ResidentNPCs, $false) }
        if ($Data.ContainsKey('AvailableQuests')) { $this.SetProperty('AvailableQuests', $Data.AvailableQuests, $false) }
        if ($Data.ContainsKey('Resources')) { $this.SetProperty('Resources', $Data.Resources, $false) }

        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Geographic properties
        $this.SetProperty('Coordinates', @{ Latitude = 0.0; Longitude = 0.0; Altitude = 0.0 }, $false)
        $this.SetProperty('LocationType', 'Generic', $false)
        $this.SetProperty('Region', '', $false)

        # Connections and travel
        $this.SetProperty('ConnectedLocations', @(), $false)
        $this.SetProperty('TravelCost', 1, $false)
        $this.SetProperty('TravelTime', 60, $false)  # seconds

        # Inhabitants and content
        $this.SetProperty('ResidentNPCs', @(), $false)
        $this.SetProperty('AvailableQuests', @(), $false)

        # Resources and services
        $this.SetProperty('Resources', @(), $false)
        $this.SetProperty('Services', @(), $false)  # shops, inns, etc.

        # Safety and discovery
        $this.SetProperty('DangerLevel', 0, $false)  # 0-10 scale
        $this.SetProperty('DiscoveryStatus', @{}, $false)  # Per-player discovery
        $this.SetProperty('SafeZone', $true, $false)
    }

    # Convenient property accessors
    [hashtable] GetCoordinates() { return $this.GetProperty('Coordinates', @{}) }
    [void] SetCoordinates([hashtable]$Value) { $this.SetProperty('Coordinates', $Value) }

    [string] GetLocationType() { return $this.GetProperty('LocationType', 'Generic') }
    [void] SetLocationType([string]$Value) { $this.SetProperty('LocationType', $Value) }

    # Location-specific methods
    [void] AddResidentNPC([string]$NPCId) {
        $npcs = $this.GetProperty('ResidentNPCs', @())
        if ($npcs -notcontains $NPCId) {
            $npcs += $NPCId
            $this.SetProperty('ResidentNPCs', $npcs)
        }
    }

    [bool] IsDiscoveredBy([string]$PlayerId) {
        $discovery = $this.GetProperty('DiscoveryStatus', @{})
        return $discovery.ContainsKey($PlayerId) -and $discovery[$PlayerId].Discovered
    }
}

# Quest Entity Class
class Quest : GameEntity {
    Quest() : base() {
        $this.Type = $script:EntityTypes.Quest
        $this.InitializeDefaults()
    }

    Quest([hashtable]$Data) : base($Data) {
        $this.Type = $script:EntityTypes.Quest
        $this.InitializeDefaults()

        # Load Quest-specific data
        if ($Data.ContainsKey('QuestType')) { $this.SetProperty('QuestType', $Data.QuestType, $false) }
        if ($Data.ContainsKey('Status')) { $this.SetProperty('Status', $Data.Status, $false) }
        if ($Data.ContainsKey('GiverNPCId')) { $this.SetProperty('GiverNPCId', $Data.GiverNPCId, $false) }
        if ($Data.ContainsKey('Objectives')) { $this.SetProperty('Objectives', $Data.Objectives, $false) }
        if ($Data.ContainsKey('Rewards')) { $this.SetProperty('Rewards', $Data.Rewards, $false) }
        if ($Data.ContainsKey('Prerequisites')) { $this.SetProperty('Prerequisites', $Data.Prerequisites, $false) }
        if ($Data.ContainsKey('Progress')) { $this.SetProperty('Progress', $Data.Progress, $false) }

        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Basic quest properties
        $this.SetProperty('QuestType', $script:QuestTypes.Side, $false)
        $this.SetProperty('Status', $script:QuestStatus.NotStarted, $false)
        $this.SetProperty('Priority', 'Medium', $false)

        # Quest giver and location
        $this.SetProperty('GiverNPCId', '', $false)
        $this.SetProperty('GiverLocationId', '', $false)

        # Objectives and progress
        $this.SetProperty('Objectives', @(), $false)
        $this.SetProperty('Progress', @{}, $false)
        $this.SetProperty('CompletionPercentage', 0.0, $false)

        # Requirements and restrictions
        $this.SetProperty('Prerequisites', @{}, $false)
        $this.SetProperty('LevelRequired', 1, $false)
        $this.SetProperty('Repeatable', $false, $false)

        # Rewards
        $this.SetProperty('Rewards', @{
            Experience = 100
            Currency = 50
            Items = @()
        }, $false)

        # Timing
        $this.SetProperty('StartedAt', $null, $false)
        $this.SetProperty('CompletedAt', $null, $false)

        # Story
        $this.SetProperty('ShortDescription', '', $false)
        $this.SetProperty('LongDescription', '', $false)
    }

    # Convenient property accessors
    [string] GetQuestType() { return $this.GetProperty('QuestType', $script:QuestTypes.Side) }
    [void] SetQuestType([string]$Value) { $this.SetProperty('QuestType', $Value) }

    [string] GetStatus() { return $this.GetProperty('Status', $script:QuestStatus.NotStarted) }
    [void] SetStatus([string]$Value) { $this.SetProperty('Status', $Value) }

    # Quest-specific methods
    [void] Start() {
        $this.SetStatus($script:QuestStatus.InProgress)
        $this.SetProperty('StartedAt', (Get-Date))
    }

    [void] Complete() {
        $this.SetStatus($script:QuestStatus.Completed)
        $this.SetProperty('CompletedAt', (Get-Date))
        $this.SetProperty('CompletionPercentage', 100.0)
    }
}

# Faction Entity Class
class Faction : GameEntity {
    Faction() : base() {
        $this.Type = $script:EntityTypes.Faction
        $this.InitializeDefaults()
    }

    Faction([hashtable]$Data) : base($Data) {
        $this.Type = $script:EntityTypes.Faction
        $this.InitializeDefaults()

        # Load Faction-specific data
        if ($Data.ContainsKey('FactionType')) { $this.SetProperty('FactionType', $Data.FactionType, $false) }
        if ($Data.ContainsKey('Alignment')) { $this.SetProperty('Alignment', $Data.Alignment, $false) }
        if ($Data.ContainsKey('LeaderNPCId')) { $this.SetProperty('LeaderNPCId', $Data.LeaderNPCId, $false) }
        if ($Data.ContainsKey('Members')) { $this.SetProperty('Members', $Data.Members, $false) }
        if ($Data.ContainsKey('Territories')) { $this.SetProperty('Territories', $Data.Territories, $false) }
        if ($Data.ContainsKey('Reputation')) { $this.SetProperty('Reputation', $Data.Reputation, $false) }

        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Basic faction properties
        $this.SetProperty('FactionType', 'Organization', $false)
        $this.SetProperty('Alignment', 'Neutral', $false)
        $this.SetProperty('Power', 50, $false)  # 0-100 scale
        $this.SetProperty('Influence', 50, $false)  # 0-100 scale

        # Leadership and hierarchy
        $this.SetProperty('LeaderNPCId', '', $false)
        $this.SetProperty('Members', @(), $false)

        # Territory and assets
        $this.SetProperty('Territories', @(), $false)

        # Diplomatic relations
        $this.SetProperty('Reputation', @{}, $false)     # Player reputation with faction
        $this.SetProperty('DefaultPlayerReputation', 0, $false)  # -100 to 100

        # Economy
        $this.SetProperty('Currency', 1000, $false)

        # Status
        $this.SetProperty('Status', 'Active', $false)
    }

    # Convenient property accessors
    [string] GetFactionType() { return $this.GetProperty('FactionType', 'Organization') }
    [void] SetFactionType([string]$Value) { $this.SetProperty('FactionType', $Value) }

    [string] GetAlignment() { return $this.GetProperty('Alignment', 'Neutral') }
    [void] SetAlignment([string]$Value) { $this.SetProperty('Alignment', $Value) }

    # Faction-specific methods
    [void] AddMember([string]$NPCId) {
        $members = $this.GetProperty('Members', @())
        if ($members -notcontains $NPCId) {
            $members += $NPCId
            $this.SetProperty('Members', $members)
        }
    }

    [int] GetPlayerReputation([string]$PlayerId) {
        $rep = $this.GetProperty('Reputation', @{})
        if ($rep.ContainsKey($PlayerId)) {
            return $rep[$PlayerId]
        }
        return $this.GetProperty('DefaultPlayerReputation', 0)
    }
}

# Helper functions for creating entities
function New-GameEntity {
    param([hashtable]$Data = @{})
    return [GameEntity]::new($Data)
}

function New-PlayerEntity {
    param([hashtable]$Data = @{})
    return [Player]::new($Data)
}

function New-NPCEntity {
    param([hashtable]$Data = @{})
    return [NPC]::new($Data)
}

function New-ItemEntity {
    param([hashtable]$Data = @{})
    return [Item]::new($Data)
}

function New-LocationEntity {
    param([hashtable]$Data = @{})
    return [Location]::new($Data)
}

function New-QuestEntity {
    param([hashtable]$Data = @{})
    return [Quest]::new($Data)
}

function New-FactionEntity {
    param([hashtable]$Data = @{})
    return [Faction]::new($Data)
}

# Export functions and classes for external use
Export-ModuleMember -Function @(
    'New-GameEntity',
    'New-PlayerEntity',
    'New-NPCEntity',
    'New-ItemEntity',
    'New-LocationEntity',
    'New-QuestEntity',
    'New-FactionEntity'
)

# Export the entity classes
Export-ModuleMember -Cmdlet @()
Export-ModuleMember -Alias @()

# Export the entity type constants as variables
Export-ModuleMember -Variable @(
    'EntityTypes',
    'ItemCategories',
    'NPCBehaviorTypes',
    'QuestTypes',
    'QuestStatus'
)
