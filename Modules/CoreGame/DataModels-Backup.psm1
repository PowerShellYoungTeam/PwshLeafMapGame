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

    [hashtable] GetChanges() {
        return $this.PropertyChanges.Clone()
    }

    [bool] HasChanges() {
        return $this.PropertyChanges.Count -gt 0
    }

    [void] AcceptChanges() {
        $this.OriginalValues = @{}
        $this.PropertyChanges = @{}
        
        # Reset baseline to current state
        foreach ($key in $this.Properties.Keys) {
            $this.OriginalValues[$key] = $this.Properties[$key]
        }
    }

    [void] RejectChanges() {
        if ($this.OriginalValues.Count -gt 0) {
            # Restore original values
            foreach ($key in $this.OriginalValues.Keys) {
                $this.Properties[$key] = $this.OriginalValues[$key]
            }
            
            # Clear change tracking
            $this.PropertyChanges = @{}
        }
    }

    # Virtual event method for property changes
    [void] OnPropertyChanged([string]$PropertyName, [object]$OldValue, [object]$NewValue) {
        # Override in derived classes or send events via EventSystem
        # For now, we'll add basic logging capability
        $this.LogPropertyChange($PropertyName, $OldValue, $NewValue)
    }

    [void] LogPropertyChange([string]$PropertyName, [object]$OldValue, [object]$NewValue) {
        # Log property changes - can be extended to use EventSystem
        if ($Global:DebugEntityChanges) {
            Write-Verbose "Entity $($this.Id) [$($this.Type)]: Property '$PropertyName' changed from '$OldValue' to '$NewValue'"
        }
    }

    # Tag management
    [void] AddTag([string]$Tag, [object]$Value = $true) {
        $this.Tags[$Tag] = $Value
        $this.UpdatedAt = Get-Date
    }

    [void] RemoveTag([string]$Tag) {
        if ($this.Tags.ContainsKey($Tag)) {
            $this.Tags.Remove($Tag)
            $this.UpdatedAt = Get-Date
        }
    }

    [bool] HasTag([string]$Tag) {
        return $this.Tags.ContainsKey($Tag)
    }

    [object] GetTag([string]$Tag) {
        return $this.Tags[$Tag]
    }

    # Metadata management
    [void] SetMetadata([string]$Key, [object]$Value) {
        $this.Metadata[$Key] = $Value
        $this.UpdatedAt = Get-Date
    }

    [object] GetMetadata([string]$Key) {
        return $this.Metadata[$Key]
    }

    [object] GetMetadata([string]$Key, [object]$DefaultValue) {
        if ($this.Metadata.ContainsKey($Key)) {
            return $this.Metadata[$Key]
        }
        return $DefaultValue
    }

    # Serialization methods
    [hashtable] ToHashtable() {
        return @{
            Id = $this.Id
            Type = $this.Type
            Name = $this.Name
            Description = $this.Description
            Tags = $this.Tags
            Metadata = $this.Metadata
            CreatedAt = $this.CreatedAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            UpdatedAt = $this.UpdatedAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            Version = $this.Version
            IsActive = $this.IsActive
            Properties = $this.Properties
        }
    }

    [string] ToJson() {
        return $this.ToHashtable() | ConvertTo-Json -Depth 10
    }

    [void] FromHashtable([hashtable]$Data) {
        if ($Data.Id) { $this.Id = $Data.Id }
        if ($Data.Type) { $this.Type = $Data.Type }
        if ($Data.Name) { $this.Name = $Data.Name }
        if ($Data.Description) { $this.Description = $Data.Description }
        if ($Data.Tags) { $this.Tags = $Data.Tags }
        if ($Data.Metadata) { $this.Metadata = $Data.Metadata }
        if ($Data.CreatedAt) { $this.CreatedAt = [DateTime]$Data.CreatedAt }
        if ($Data.UpdatedAt) { $this.UpdatedAt = [DateTime]$Data.UpdatedAt }
        if ($Data.Version) { $this.Version = $Data.Version }
        if ($null -ne $Data.IsActive) { $this.IsActive = $Data.IsActive }
        if ($Data.Properties) { $this.Properties = $Data.Properties }
        
        $this.StartChangeTracking()
    }

    [void] UpdateTimestamp() {
        $this.UpdatedAt = Get-Date
    }

    # Validation method
    [bool] IsValid() {
        return (-not [string]::IsNullOrEmpty($this.Id)) -and (-not [string]::IsNullOrEmpty($this.Type))
    }

    # Clone method
    [GameEntity] Clone() {
        $clonedData = $this.ToHashtable()
        $clonedData.Id = [System.Guid]::NewGuid().ToString()  # New ID for clone
        return [GameEntity]::new($clonedData)
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
        
        # Load player-specific data
        if ($Data.ContainsKey('Username')) { $this.SetProperty('Username', $Data.Username, $false) }
        if ($Data.ContainsKey('Email')) { $this.SetProperty('Email', $Data.Email, $false) }
        if ($Data.ContainsKey('DisplayName')) { $this.SetProperty('DisplayName', $Data.DisplayName, $false) }
        if ($Data.ContainsKey('Level')) { $this.SetProperty('Level', $Data.Level, $false) }
        if ($Data.ContainsKey('Experience')) { $this.SetProperty('Experience', $Data.Experience, $false) }
        if ($Data.ContainsKey('Health')) { $this.SetProperty('Health', $Data.Health, $false) }
        if ($Data.ContainsKey('Energy')) { $this.SetProperty('Energy', $Data.Energy, $false) }
        if ($Data.ContainsKey('CurrentLocationId')) { $this.SetProperty('CurrentLocationId', $Data.CurrentLocationId, $false) }
        if ($Data.ContainsKey('Currency')) { $this.SetProperty('Currency', $Data.Currency, $false) }
        if ($Data.ContainsKey('Inventory')) { $this.SetProperty('Inventory', $Data.Inventory, $false) }
        if ($Data.ContainsKey('QuestLog')) { $this.SetProperty('QuestLog', $Data.QuestLog, $false) }
        if ($Data.ContainsKey('FactionRelationships')) { $this.SetProperty('FactionRelationships', $Data.FactionRelationships, $false) }
        if ($Data.ContainsKey('Skills')) { $this.SetProperty('Skills', $Data.Skills, $false) }
        if ($Data.ContainsKey('Attributes')) { $this.SetProperty('Attributes', $Data.Attributes, $false) }
        if ($Data.ContainsKey('Equipment')) { $this.SetProperty('Equipment', $Data.Equipment, $false) }
        if ($Data.ContainsKey('Statistics')) { $this.SetProperty('Statistics', $Data.Statistics, $false) }
        if ($Data.ContainsKey('Achievements')) { $this.SetProperty('Achievements', $Data.Achievements, $false) }
        if ($Data.ContainsKey('VisitedLocations')) { $this.SetProperty('VisitedLocations', $Data.VisitedLocations, $false) }
        if ($Data.ContainsKey('PlayTime')) { $this.SetProperty('PlayTime', $Data.PlayTime, $false) }
        if ($Data.ContainsKey('LastLogin')) { $this.SetProperty('LastLogin', $Data.LastLogin, $false) }
        if ($Data.ContainsKey('Preferences')) { $this.SetProperty('Preferences', $Data.Preferences, $false) }
        
        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Basic player information
        $this.SetProperty('Username', '', $false)
        $this.SetProperty('Email', '', $false)
        $this.SetProperty('DisplayName', '', $false)
        
        # Character stats
        $this.SetProperty('Level', 1, $false)
        $this.SetProperty('Experience', 0, $false)
        $this.SetProperty('ExperienceToNext', 1000, $false)
        $this.SetProperty('Health', 100, $false)
        $this.SetProperty('MaxHealth', 100, $false)
        $this.SetProperty('Energy', 100, $false)
        $this.SetProperty('MaxEnergy', 100, $false)
        
        # Location and world state
        $this.SetProperty('CurrentLocationId', '', $false)
        $this.SetProperty('VisitedLocations', @(), $false)
        
        # Inventory and economy
        $this.SetProperty('Currency', 100, $false)
        $this.SetProperty('Inventory', @(), $false)
        $this.SetProperty('InventoryCapacity', 30, $false)
        
        # Quests and progression
        $this.SetProperty('QuestLog', @(), $false)
        $this.SetProperty('CompletedQuests', @(), $false)
        $this.SetProperty('Achievements', @(), $false)
        
        # Social systems
        $this.SetProperty('FactionRelationships', @{}, $false)
        $this.SetProperty('Friends', @(), $false)
        $this.SetProperty('GuildId', '', $false)
        
        # Character attributes
        $this.SetProperty('Attributes', $this.GetDefaultAttributes(), $false)
        $this.SetProperty('Skills', $this.GetDefaultSkills(), $false)
        $this.SetProperty('Equipment', $this.GetDefaultEquipment(), $false)
        
        # Game statistics
        $this.SetProperty('Statistics', $this.GetDefaultStatistics(), $false)
        
        # Session information
        $this.SetProperty('LastLogin', (Get-Date), $false)
        $this.SetProperty('PlayTime', [TimeSpan]::Zero, $false)
        $this.SetProperty('IsOnline', $false, $false)
        
        # Player preferences
        $this.SetProperty('Preferences', $this.GetDefaultPreferences(), $false)
        $this.SetProperty('UISettings', $this.GetDefaultUISettings(), $false)
    }

    # Convenient property accessors
    [string] GetUsername() { return $this.GetProperty('Username', '') }
    [void] SetUsername([string]$Value) { $this.SetProperty('Username', $Value) }
    
    [int] GetLevel() { return $this.GetProperty('Level', 1) }
    [void] SetLevel([int]$Value) { $this.SetProperty('Level', $Value) }
    
    [long] GetExperience() { return $this.GetProperty('Experience', 0) }
    [void] SetExperience([long]$Value) { $this.SetProperty('Experience', $Value) }
    
    [int] GetHealth() { return $this.GetProperty('Health', 100) }
    [void] SetHealth([int]$Value) { $this.SetProperty('Health', $Value) }
    
    [int] GetEnergy() { return $this.GetProperty('Energy', 100) }
    [void] SetEnergy([int]$Value) { $this.SetProperty('Energy', $Value) }
    
    [string] GetCurrentLocationId() { return $this.GetProperty('CurrentLocationId', '') }
    [void] SetCurrentLocationId([string]$Value) { $this.SetProperty('CurrentLocationId', $Value) }
    
    [decimal] GetCurrency() { return $this.GetProperty('Currency', 100) }
    [void] SetCurrency([decimal]$Value) { $this.SetProperty('Currency', $Value) }
    
    [array] GetInventory() { return $this.GetProperty('Inventory', @()) }
    [void] SetInventory([array]$Value) { $this.SetProperty('Inventory', $Value) }
    
    [array] GetQuestLog() { return $this.GetProperty('QuestLog', @()) }
    [void] SetQuestLog([array]$Value) { $this.SetProperty('QuestLog', $Value) }

    # Helper methods for player functionality
    [void] AddItemToInventory([hashtable]$Item) {
        $inventory = $this.GetInventory()
        $inventory += $Item
        $this.SetInventory($inventory)
    }

    [bool] RemoveItemFromInventory([string]$ItemId) {
        $inventory = $this.GetInventory()
        $newInventory = @()
        $removed = $false
        
        foreach ($item in $inventory) {
            if ($item.Id -ne $ItemId) {
                $newInventory += $item
            } else {
                $removed = $true
            }
        }
        
        if ($removed) {
            $this.SetInventory($newInventory)
        }
        
        return $removed
    }

    [void] AddExperience([long]$Amount) {
        $currentExp = $this.GetExperience()
        $this.SetExperience($currentExp + $Amount)
        $this.CheckLevelUp()
    }

    [void] CheckLevelUp() {
        $currentExp = $this.GetExperience()
        $currentLevel = $this.GetLevel()
        $expToNext = $this.GetProperty('ExperienceToNext', 1000)
        
        if ($currentExp -ge $expToNext) {
            $newLevel = $currentLevel + 1
            $this.SetLevel($newLevel)
            $this.SetProperty('ExperienceToNext', $expToNext * 1.5)
            
            # Trigger level up event
            $this.OnLevelUp($currentLevel, $newLevel)
        }
    }

    [void] OnLevelUp([int]$OldLevel, [int]$NewLevel) {
        # Override for level up logic
        Write-Verbose "Player $($this.Name) leveled up from $OldLevel to $NewLevel"
    }

    [hashtable] GetDefaultAttributes() {
        return @{
            Strength = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Dexterity = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Intelligence = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Constitution = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Wisdom = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Charisma = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
        }
    }

    [hashtable] GetDefaultSkills() {
        return @{
            Combat = @{ Level = 1; Experience = 0; Specializations = @() }
            Exploration = @{ Level = 1; Experience = 0; Specializations = @() }
            Social = @{ Level = 1; Experience = 0; Specializations = @() }
            Crafting = @{ Level = 1; Experience = 0; Specializations = @() }
            Stealth = @{ Level = 1; Experience = 0; Specializations = @() }
            Magic = @{ Level = 1; Experience = 0; Specializations = @() }
        }
    }

    [hashtable] GetDefaultEquipment() {
        return @{
            Head = $null
            Chest = $null
            Legs = $null
            Feet = $null
            MainHand = $null
            OffHand = $null
            Ring1 = $null
            Ring2 = $null
            Necklace = $null
            Belt = $null
        }
    }

    [hashtable] GetDefaultStatistics() {
        return @{
            LocationsVisited = 0
            QuestsCompleted = 0
            ItemsCollected = 0
            EnemiesDefeated = 0
            DistanceTraveled = 0.0
            TimePlayedMinutes = 0
            DeathCount = 0
            TotalDamageDealt = 0
            TotalDamageTaken = 0
            QuestObjectivesCompleted = 0
        }
    }

    [hashtable] GetDefaultPreferences() {
        return @{
            AutoSave = $true
            ShowTutorials = $true
            DifficultyLevel = 'Normal'
            SoundEnabled = $true
            MusicEnabled = $true
            NotificationsEnabled = $true
            AutoLoot = $false
            PvPEnabled = $false
        }
    }

    [hashtable] GetDefaultUISettings() {
        return @{
            Theme = 'Default'
            FontSize = 'Medium'
            ShowMinimap = $true
            ShowHealthBar = $true
            ShowExperienceBar = $true
            ShowQuestTracker = $true
            ChatOpacity = 0.8
            UIScale = 1.0
        }
    }

    # Override serialization to include all player data
    [hashtable] ToHashtable() {
        $base = ([GameEntity]$this).ToHashtable()
        
        # Player data is now stored in Properties, so it's automatically included
        return $base
    }
}
        $this.CompletedQuests = if ($Data.CompletedQuests) { @($Data.CompletedQuests) } else { @() }
        $this.Friends = if ($Data.Friends) { @($Data.Friends) } else { @() }
        $this.GuildId = if ($Data.GuildId) { $Data.GuildId } else { $null }
        $this.Reputation = if ($Data.Reputation) { $Data.Reputation } else { @{} }
        $this.Preferences = if ($Data.Preferences) { $Data.Preferences } else { $this.GetDefaultPreferences() }
        $this.UISettings = if ($Data.UISettings) { $Data.UISettings } else { $this.GetDefaultUISettings() }
        $this.Theme = if ($Data.Theme) { $Data.Theme } else { 'Default' }
        $this.LastLogin = if ($Data.LastLogin) { [DateTime]$Data.LastLogin } else { Get-Date }
        $this.PlayTime = if ($Data.PlayTime) { [TimeSpan]$Data.PlayTime } else { [TimeSpan]::Zero }
        $this.SessionStart = if ($Data.SessionStart) { [DateTime]$Data.SessionStart } else { Get-Date }
        $this.IsOnline = if ($null -ne $Data.IsOnline) { $Data.IsOnline } else { $true }
        $this.BackupData = if ($Data.BackupData) { $Data.BackupData } else { '' }
        $this.LastBackup = if ($Data.LastBackup) { [DateTime]$Data.LastBackup } else { Get-Date }
    }

    [void] InitializeDefaults() {
        $this.Level = 1
        $this.Experience = 0
        $this.ExperienceToNext = 1000
        $this.Attributes = $this.GetDefaultAttributes()
        $this.Skills = $this.GetDefaultSkills()
        $this.VisitedLocations = @()
        $this.Score = 0
        $this.GameState = 'Active'
        $this.Inventory = @()
        $this.Equipment = $this.GetDefaultEquipment()
        $this.InventoryCapacity = 30
        $this.Currency = 100
        $this.Achievements = @()
        $this.QuestProgress = @{}
        $this.Statistics = $this.GetDefaultStatistics()
        $this.CompletedQuests = @()
        $this.Friends = @()
        $this.Reputation = @{}
        $this.Preferences = $this.GetDefaultPreferences()
        $this.UISettings = $this.GetDefaultUISettings()
        $this.Theme = 'Default'
        $this.LastLogin = Get-Date
        $this.PlayTime = [TimeSpan]::Zero
        $this.SessionStart = Get-Date
        $this.IsOnline = $true
        $this.BackupData = ''
        $this.LastBackup = Get-Date
    }

    [hashtable] GetDefaultAttributes() {
        return @{
            Strength = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Dexterity = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Intelligence = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Constitution = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Wisdom = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
            Charisma = @{ Base = 10; Current = 10; Modifiers = @(); Maximum = 20 }
        }
    }

    [hashtable] GetDefaultSkills() {
        return @{
            Combat = @{ Level = 1; Experience = 0; Specializations = @() }
            Exploration = @{ Level = 1; Experience = 0; Specializations = @() }
            Social = @{ Level = 1; Experience = 0; Specializations = @() }
            Crafting = @{ Level = 1; Experience = 0; Specializations = @() }
        }
    }

    [hashtable] GetDefaultEquipment() {
        return @{
            Head = $null; Chest = $null; Legs = $null; Feet = $null
            MainHand = $null; OffHand = $null; Ring1 = $null; Ring2 = $null
        }
    }

    [hashtable] GetDefaultStatistics() {
        return @{
            LocationsVisited = 0
            QuestsCompleted = 0
            ItemsCollected = 0
            EnemiesDefeated = 0
            DistanceTraveled = 0
            TimePlayedHours = 0
        }
    }

    [hashtable] GetDefaultPreferences() {
        return @{
            AutoSave = $true
            ShowTutorials = $true
            DifficultyLevel = 'Normal'
            SoundEnabled = $true
            MusicEnabled = $true
        }
    }

    [hashtable] GetDefaultUISettings() {
        return @{
            Theme = 'Default'
            FontSize = 'Medium'
            ShowMinimap = $true
            ShowHealthBar = $true
            ShowExperienceBar = $true
        }
    }

    [hashtable] ToHashtable() {
        $baseData = ([GameEntity]$this).ToHashtable()
        $playerData = @{
            Username = $this.Username
            Email = $this.Email
            DisplayName = $this.DisplayName
            Level = $this.Level
            Experience = $this.Experience
            ExperienceToNext = $this.ExperienceToNext
            Attributes = $this.Attributes
            Skills = $this.Skills
            Location = $this.Location
            LastLocationId = $this.LastLocationId
            VisitedLocations = $this.VisitedLocations
            Score = $this.Score
            GameState = $this.GameState
            Inventory = $this.Inventory
            Equipment = $this.Equipment
            InventoryCapacity = $this.InventoryCapacity
            Currency = $this.Currency
            Achievements = $this.Achievements
            QuestProgress = $this.QuestProgress
            Statistics = $this.Statistics
            CompletedQuests = $this.CompletedQuests
            Friends = $this.Friends
            GuildId = $this.GuildId
            Reputation = $this.Reputation
            Preferences = $this.Preferences
            UISettings = $this.UISettings
            Theme = $this.Theme
            LastLogin = $this.LastLogin.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            PlayTime = $this.PlayTime.ToString()
            SessionStart = $this.SessionStart.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            IsOnline = $this.IsOnline
            BackupData = $this.BackupData
            LastBackup = $this.LastBackup.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        }

        return $baseData + $playerData
    }

    [void] AddExperience([long]$Amount) {
        $this.Experience += $Amount
        $this.UpdateTimestamp()

        # Check for level up
        while ($this.Experience -ge $this.ExperienceToNext) {
            $this.LevelUp()
        }
    }

    [void] LevelUp() {
        $this.Level++
        $this.Experience -= $this.ExperienceToNext
        $this.ExperienceToNext = [math]::Floor($this.ExperienceToNext * 1.2)
        $this.UpdateTimestamp()
    }

    [void] VisitLocation([string]$LocationId) {
        if ($this.VisitedLocations -notcontains $LocationId) {
            $this.VisitedLocations = @($this.VisitedLocations) + $LocationId
        }
        $this.LastLocationId = $LocationId
        $this.Statistics.LocationsVisited = $this.VisitedLocations.Count
        $this.UpdateTimestamp()
    }

    [void] AddAchievement([hashtable]$Achievement) {
        $this.Achievements = @($this.Achievements) + $Achievement
        $this.UpdateTimestamp()
    }

    [bool] HasAchievement([string]$AchievementId) {
        return $this.Achievements | Where-Object { $_.Id -eq $AchievementId } | Measure-Object | ForEach-Object Count
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
        if ($Data.ContainsKey('MaxHealth')) { $this.SetProperty('MaxHealth', $Data.MaxHealth, $false) }
        if ($Data.ContainsKey('CurrentLocationId')) { $this.SetProperty('CurrentLocationId', $Data.CurrentLocationId, $false) }
        if ($Data.ContainsKey('FactionId')) { $this.SetProperty('FactionId', $Data.FactionId, $false) }
        if ($Data.ContainsKey('DialogOptions')) { $this.SetProperty('DialogOptions', $Data.DialogOptions, $false) }
        if ($Data.ContainsKey('Inventory')) { $this.SetProperty('Inventory', $Data.Inventory, $false) }
        if ($Data.ContainsKey('QuestsOffered')) { $this.SetProperty('QuestsOffered', $Data.QuestsOffered, $false) }
        if ($Data.ContainsKey('Schedule')) { $this.SetProperty('Schedule', $Data.Schedule, $false) }
        if ($Data.ContainsKey('Appearance')) { $this.SetProperty('Appearance', $Data.Appearance, $false) }
        if ($Data.ContainsKey('AISettings')) { $this.SetProperty('AISettings', $Data.AISettings, $false) }
        
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
        $this.SetProperty('PatrolRoute', @(), $false)
        $this.SetProperty('MovementSpeed', 1.0, $false)
        $this.SetProperty('IsStationary', $true, $false)
        
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
        $this.SetProperty('CompletedQuestGiving', @(), $false)
        
        # Scheduling
        $this.SetProperty('Schedule', $this.GetDefaultSchedule(), $false)
        $this.SetProperty('IsCurrentlyAvailable', $true, $false)
        
        # Appearance and presentation
        $this.SetProperty('Appearance', $this.GetDefaultAppearance(), $false)
        $this.SetProperty('Portrait', '', $false)
        
        # AI and behavior
        $this.SetProperty('AISettings', $this.GetDefaultAISettings(), $false)
        $this.SetProperty('PersonalityTraits', @(), $false)
    }

    # Convenient property accessors
    [string] GetBehaviorType() { return $this.GetProperty('BehaviorType', $script:NPCBehaviorTypes.Neutral) }
    [void] SetBehaviorType([string]$Value) { $this.SetProperty('BehaviorType', $Value) }
    
    [int] GetHealth() { return $this.GetProperty('Health', 100) }
    [void] SetHealth([int]$Value) { $this.SetProperty('Health', $Value) }
    
    [string] GetCurrentLocationId() { return $this.GetProperty('CurrentLocationId', '') }
    [void] SetCurrentLocationId([string]$Value) { $this.SetProperty('CurrentLocationId', $Value) }
    
    [string] GetFactionId() { return $this.GetProperty('FactionId', '') }
    [void] SetFactionId([string]$Value) { $this.SetProperty('FactionId', $Value) }
    
    [bool] GetIsVendor() { return $this.GetProperty('IsVendor', $false) }
    [void] SetIsVendor([bool]$Value) { $this.SetProperty('IsVendor', $Value) }

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

    [void] ModifyRelationship([int]$Change) {
        $current = $this.GetProperty('RelationshipToPlayer', 0)
        $new = [Math]::Max(-100, [Math]::Min(100, $current + $Change))
        $this.SetProperty('RelationshipToPlayer', $new)
    }

    [hashtable] GetDefaultSchedule() {
        return @{
            Monday = @{ '00:00' = 'Sleep'; '08:00' = 'Work'; '18:00' = 'Relax'; '22:00' = 'Sleep' }
            Tuesday = @{ '00:00' = 'Sleep'; '08:00' = 'Work'; '18:00' = 'Relax'; '22:00' = 'Sleep' }
            Wednesday = @{ '00:00' = 'Sleep'; '08:00' = 'Work'; '18:00' = 'Relax'; '22:00' = 'Sleep' }
            Thursday = @{ '00:00' = 'Sleep'; '08:00' = 'Work'; '18:00' = 'Relax'; '22:00' = 'Sleep' }
            Friday = @{ '00:00' = 'Sleep'; '08:00' = 'Work'; '18:00' = 'Relax'; '22:00' = 'Sleep' }
            Saturday = @{ '00:00' = 'Sleep'; '10:00' = 'Relax'; '22:00' = 'Sleep' }
            Sunday = @{ '00:00' = 'Sleep'; '10:00' = 'Relax'; '22:00' = 'Sleep' }
        }
    }

    [hashtable] GetDefaultAppearance() {
        return @{
            Hair = 'Brown'
            Eyes = 'Brown'
            Skin = 'Medium'
            Height = 'Average'
            Build = 'Average'
            ClothingStyle = 'Casual'
        }
    }

    [hashtable] GetDefaultAISettings() {
        return @{
            AggressionLevel = 0.0  # 0.0 to 1.0
            CuriosityLevel = 0.5   # 0.0 to 1.0
            FearLevel = 0.3        # 0.0 to 1.0
            SocialLevel = 0.7      # 0.0 to 1.0
            PatrolRadius = 50.0    # meters
            AlertRadius = 20.0     # meters
            CombatRadius = 10.0    # meters
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
        if ($Data.ContainsKey('MaxStackSize')) { $this.SetProperty('MaxStackSize', $Data.MaxStackSize, $false) }
        if ($Data.ContainsKey('Durability')) { $this.SetProperty('Durability', $Data.Durability, $false) }
        if ($Data.ContainsKey('MaxDurability')) { $this.SetProperty('MaxDurability', $Data.MaxDurability, $false) }
        if ($Data.ContainsKey('Effects')) { $this.SetProperty('Effects', $Data.Effects, $false) }
        if ($Data.ContainsKey('Requirements')) { $this.SetProperty('Requirements', $Data.Requirements, $false) }
        if ($Data.ContainsKey('Icon')) { $this.SetProperty('Icon', $Data.Icon, $false) }
        if ($Data.ContainsKey('Model')) { $this.SetProperty('Model', $Data.Model, $false) }
        
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
        $this.SetProperty('Cooldown', 0, $false)  # seconds
        
        # Requirements
        $this.SetProperty('Requirements', @{}, $false)
        $this.SetProperty('LevelRequired', 1, $false)
        
        # Visual representation
        $this.SetProperty('Icon', '', $false)
        $this.SetProperty('Model', '', $false)
        $this.SetProperty('Color', 'White', $false)
        
        # Trading and economy
        $this.SetProperty('Tradeable', $true, $false)
        $this.SetProperty('Sellable', $true, $false)
        $this.SetProperty('VendorPrice', 0, $false)
        
        # Item state
        $this.SetProperty('IsEquipped', $false, $false)
        $this.SetProperty('EquipSlot', '', $false)
        $this.SetProperty('Enchantments', @(), $false)
    }

    # Convenient property accessors
    [string] GetCategory() { return $this.GetProperty('Category', $script:ItemCategories.Material) }
    [void] SetCategory([string]$Value) { $this.SetProperty('Category', $Value) }
    
    [decimal] GetValue() { return $this.GetProperty('Value', 1) }
    [void] SetValue([decimal]$Value) { $this.SetProperty('Value', $Value) }
    
    [double] GetWeight() { return $this.GetProperty('Weight', 1.0) }
    [void] SetWeight([double]$Value) { $this.SetProperty('Weight', $Value) }
    
    [string] GetRarity() { return $this.GetProperty('Rarity', 'Common') }
    [void] SetRarity([string]$Value) { $this.SetProperty('Rarity', $Value) }
    
    [bool] GetStackable() { return $this.GetProperty('Stackable', $true) }
    [void] SetStackable([bool]$Value) { $this.SetProperty('Stackable', $Value) }

    # Item-specific methods
    [bool] CanUse([hashtable]$User) {
        $requirements = $this.GetProperty('Requirements', @{})
        
        # Check level requirement
        $levelReq = $this.GetProperty('LevelRequired', 1)
        if ($User.Level -lt $levelReq) {
            return $false
        }
        
        # Check other requirements
        foreach ($req in $requirements.Keys) {
            if (-not $this.CheckRequirement($req, $requirements[$req], $User)) {
                return $false
            }
        }
        
        return $true
    }

    [bool] CheckRequirement([string]$Type, [object]$Value, [hashtable]$User) {
        switch ($Type) {
            'Attribute' {
                $attrName = $Value.Name
                $attrValue = $Value.Value
                return $User.Attributes[$attrName].Current -ge $attrValue
            }
            'Skill' {
                $skillName = $Value.Name
                $skillLevel = $Value.Level
                return $User.Skills[$skillName].Level -ge $skillLevel
            }
            default {
                return $true
            }
        }
    }

    [void] ApplyDamage([int]$Damage) {
        $current = $this.GetProperty('Durability', 100)
        $new = [Math]::Max(0, $current - $Damage)
        $this.SetProperty('Durability', $new)
        
        if ($new -eq 0) {
            $this.OnItemBroken()
        }
    }

    [void] Repair([int]$Amount) {
        $current = $this.GetProperty('Durability', 100)
        $max = $this.GetProperty('MaxDurability', 100)
        $new = [Math]::Min($max, $current + $Amount)
        $this.SetProperty('Durability', $new)
    }

    [void] OnItemBroken() {
        # Override for item breaking logic
        Write-Verbose "Item $($this.Name) has broken"
    }
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
        if ($Data.ContainsKey('Interactions')) { $this.SetProperty('Interactions', $Data.Interactions, $false) }
        if ($Data.ContainsKey('Resources')) { $this.SetProperty('Resources', $Data.Resources, $false) }
        if ($Data.ContainsKey('Environment')) { $this.SetProperty('Environment', $Data.Environment, $false) }
        if ($Data.ContainsKey('DiscoveryStatus')) { $this.SetProperty('DiscoveryStatus', $Data.DiscoveryStatus, $false) }
        
        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Geographic properties
        $this.SetProperty('Coordinates', @{ Latitude = 0.0; Longitude = 0.0; Altitude = 0.0 }, $false)
        $this.SetProperty('LocationType', 'Generic', $false)
        $this.SetProperty('Region', '', $false)
        $this.SetProperty('Zone', '', $false)
        
        # Connections and travel
        $this.SetProperty('ConnectedLocations', @(), $false)
        $this.SetProperty('TravelCost', 1, $false)
        $this.SetProperty('TravelTime', 60, $false)  # seconds
        $this.SetProperty('AccessRequirements', @{}, $false)
        
        # Inhabitants and content
        $this.SetProperty('ResidentNPCs', @(), $false)
        $this.SetProperty('TemporaryNPCs', @(), $false)
        $this.SetProperty('AvailableQuests', @(), $false)
        $this.SetProperty('CompletedQuests', @(), $false)
        
        # Interactions and services
        $this.SetProperty('Interactions', @(), $false)
        $this.SetProperty('Services', @(), $false)  # shops, inns, etc.
        $this.SetProperty('Landmarks', @(), $false)
        
        # Resources and loot
        $this.SetProperty('Resources', @(), $false)
        $this.SetProperty('RespawnableItems', @(), $false)
        $this.SetProperty('HiddenItems', @(), $false)
        
        # Environment and atmosphere
        $this.SetProperty('Environment', $this.GetDefaultEnvironment(), $false)
        $this.SetProperty('Weather', 'Clear', $false)
        $this.SetProperty('TimeOfDay', 'Day', $false)
        $this.SetProperty('Lighting', 'Normal', $false)
        
        # Discovery and exploration
        $this.SetProperty('DiscoveryStatus', @{}, $false)  # Per-player discovery
        $this.SetProperty('ExplorationReward', 0, $false)
        $this.SetProperty('FirstDiscoveryBonus', 0, $false)
        
        # Safety and danger
        $this.SetProperty('DangerLevel', 0, $false)  # 0-10 scale
        $this.SetProperty('HostileCreatures', @(), $false)
        $this.SetProperty('SafeZone', $true, $false)
    }

    # Convenient property accessors
    [hashtable] GetCoordinates() { return $this.GetProperty('Coordinates', @{}) }
    [void] SetCoordinates([hashtable]$Value) { $this.SetProperty('Coordinates', $Value) }
    
    [string] GetLocationType() { return $this.GetProperty('LocationType', 'Generic') }
    [void] SetLocationType([string]$Value) { $this.SetProperty('LocationType', $Value) }
    
    [array] GetConnectedLocations() { return $this.GetProperty('ConnectedLocations', @()) }
    [void] SetConnectedLocations([array]$Value) { $this.SetProperty('ConnectedLocations', $Value) }

    # Location-specific methods
    [void] AddConnectedLocation([string]$LocationId, [hashtable]$ConnectionData = @{}) {
        $connections = $this.GetConnectedLocations()
        $connection = @{
            LocationId = $LocationId
            TravelCost = $ConnectionData.TravelCost ?? 1
            TravelTime = $ConnectionData.TravelTime ?? 60
            Requirements = $ConnectionData.Requirements ?? @{}
            Bidirectional = $ConnectionData.Bidirectional ?? $true
        }
        
        $connections += $connection
        $this.SetConnectedLocations($connections)
    }

    [void] AddResidentNPC([string]$NPCId) {
        $npcs = $this.GetProperty('ResidentNPCs', @())
        if ($npcs -notcontains $NPCId) {
            $npcs += $NPCId
            $this.SetProperty('ResidentNPCs', $npcs)
        }
    }

    [void] RemoveResidentNPC([string]$NPCId) {
        $npcs = $this.GetProperty('ResidentNPCs', @())
        $newNpcs = $npcs | Where-Object { $_ -ne $NPCId }
        $this.SetProperty('ResidentNPCs', $newNpcs)
    }

    [bool] IsDiscoveredBy([string]$PlayerId) {
        $discovery = $this.GetProperty('DiscoveryStatus', @{})
        return $discovery.ContainsKey($PlayerId) -and $discovery[$PlayerId].Discovered
    }

    [void] DiscoverBy([string]$PlayerId) {
        $discovery = $this.GetProperty('DiscoveryStatus', @{})
        $discovery[$PlayerId] = @{
            Discovered = $true
            DiscoveredAt = Get-Date
            ExplorationPercentage = 0
        }
        $this.SetProperty('DiscoveryStatus', $discovery)
    }

    [hashtable] GetDefaultEnvironment() {
        return @{
            Climate = 'Temperate'
            Terrain = 'Plains'
            Vegetation = 'Moderate'
            WaterSources = @()
            Minerals = @()
            Wildlife = @()
            Ambience = 'Peaceful'
        }
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
        if ($Data.ContainsKey('TimeLimit')) { $this.SetProperty('TimeLimit', $Data.TimeLimit, $false) }
        if ($Data.ContainsKey('Progress')) { $this.SetProperty('Progress', $Data.Progress, $false) }
        
        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Basic quest properties
        $this.SetProperty('QuestType', $script:QuestTypes.Side, $false)
        $this.SetProperty('Status', $script:QuestStatus.NotStarted, $false)
        $this.SetProperty('Priority', 'Medium', $false)
        $this.SetProperty('Category', 'General', $false)
        
        # Quest giver and location
        $this.SetProperty('GiverNPCId', '', $false)
        $this.SetProperty('GiverLocationId', '', $false)
        $this.SetProperty('ReturnNPCId', '', $false)
        $this.SetProperty('ReturnLocationId', '', $false)
        
        # Objectives and progress
        $this.SetProperty('Objectives', @(), $false)
        $this.SetProperty('Progress', @{}, $false)
        $this.SetProperty('CompletionPercentage', 0.0, $false)
        
        # Requirements and restrictions
        $this.SetProperty('Prerequisites', @{}, $false)
        $this.SetProperty('LevelRequired', 1, $false)
        $this.SetProperty('TimeLimit', 0, $false)  # 0 = no time limit, otherwise seconds
        $this.SetProperty('Repeatable', $false, $false)
        $this.SetProperty('Daily', $false, $false)
        
        # Rewards
        $this.SetProperty('Rewards', $this.GetDefaultRewards(), $false)
        $this.SetProperty('FailurePenalty', @{}, $false)
        
        # Timing
        $this.SetProperty('StartedAt', $null, $false)
        $this.SetProperty('CompletedAt', $null, $false)
        $this.SetProperty('FailedAt', $null, $false)
        $this.SetProperty('LastResetAt', $null, $false)
        
        # Story and presentation
        $this.SetProperty('ShortDescription', '', $false)
        $this.SetProperty('LongDescription', '', $false)
        $this.SetProperty('CompletionText', '', $false)
        $this.SetProperty('FailureText', '', $false)
        
        # Quest chain information
        $this.SetProperty('ChainId', '', $false)
        $this.SetProperty('ChainPosition', 0, $false)
        $this.SetProperty('NextQuestId', '', $false)
        $this.SetProperty('PreviousQuestId', '', $false)
    }

    # Convenient property accessors
    [string] GetQuestType() { return $this.GetProperty('QuestType', $script:QuestTypes.Side) }
    [void] SetQuestType([string]$Value) { $this.SetProperty('QuestType', $Value) }
    
    [string] GetStatus() { return $this.GetProperty('Status', $script:QuestStatus.NotStarted) }
    [void] SetStatus([string]$Value) { $this.SetProperty('Status', $Value) }
    
    [string] GetGiverNPCId() { return $this.GetProperty('GiverNPCId', '') }
    [void] SetGiverNPCId([string]$Value) { $this.SetProperty('GiverNPCId', $Value) }

    # Quest-specific methods
    [bool] CanStart([hashtable]$Player) {
        $status = $this.GetStatus()
        if ($status -ne $script:QuestStatus.NotStarted -and $status -ne $script:QuestStatus.Available) {
            return $false
        }
        
        # Check level requirement
        $levelReq = $this.GetProperty('LevelRequired', 1)
        if ($Player.Level -lt $levelReq) {
            return $false
        }
        
        # Check prerequisites
        $prereqs = $this.GetProperty('Prerequisites', @{})
        return $this.CheckPrerequisites($prereqs, $Player)
    }

    [bool] CheckPrerequisites([hashtable]$Prerequisites, [hashtable]$Player) {
        foreach ($type in $Prerequisites.Keys) {
            switch ($type) {
                'CompletedQuests' {
                    foreach ($questId in $Prerequisites[$type]) {
                        if ($Player.CompletedQuests -notcontains $questId) {
                            return $false
                        }
                    }
                }
                'Items' {
                    foreach ($itemReq in $Prerequisites[$type]) {
                        $hasItem = $false
                        foreach ($item in $Player.Inventory) {
                            if ($item.Id -eq $itemReq.Id -and $item.Quantity -ge $itemReq.Quantity) {
                                $hasItem = $true
                                break
                            }
                        }
                        if (-not $hasItem) {
                            return $false
                        }
                    }
                }
                'Attributes' {
                    foreach ($attrReq in $Prerequisites[$type]) {
                        if ($Player.Attributes[$attrReq.Name].Current -lt $attrReq.Value) {
                            return $false
                        }
                    }
                }
            }
        }
        return $true
    }

    [void] Start() {
        $this.SetStatus($script:QuestStatus.InProgress)
        $this.SetProperty('StartedAt', (Get-Date))
        
        # Initialize objective progress
        $objectives = $this.GetProperty('Objectives', @())
        $progress = @{}
        for ($i = 0; $i -lt $objectives.Count; $i++) {
            $progress["objective_$i"] = @{
                Completed = $false
                Progress = 0
                Target = $objectives[$i].Target ?? 1
            }
        }
        $this.SetProperty('Progress', $progress)
    }

    [void] Complete() {
        $this.SetStatus($script:QuestStatus.Completed)
        $this.SetProperty('CompletedAt', (Get-Date))
        $this.SetProperty('CompletionPercentage', 100.0)
    }

    [void] Fail() {
        $this.SetStatus($script:QuestStatus.Failed)
        $this.SetProperty('FailedAt', (Get-Date))
    }

    [void] UpdateObjectiveProgress([int]$ObjectiveIndex, [int]$Progress) {
        $progressData = $this.GetProperty('Progress', @{})
        $objKey = "objective_$ObjectiveIndex"
        
        if ($progressData.ContainsKey($objKey)) {
            $progressData[$objKey].Progress = $Progress
            $progressData[$objKey].Completed = $Progress -ge $progressData[$objKey].Target
            $this.SetProperty('Progress', $progressData)
            
            $this.UpdateCompletionPercentage()
        }
    }

    [void] UpdateCompletionPercentage() {
        $progress = $this.GetProperty('Progress', @{})
        $objectives = $this.GetProperty('Objectives', @())
        
        if ($objectives.Count -eq 0) {
            $this.SetProperty('CompletionPercentage', 0.0)
            return
        }
        
        $completedCount = 0
        foreach ($key in $progress.Keys) {
            if ($progress[$key].Completed) {
                $completedCount++
            }
        }
        
        $percentage = ($completedCount / $objectives.Count) * 100.0
        $this.SetProperty('CompletionPercentage', $percentage)
        
        # Auto-complete if all objectives are done
        if ($percentage -eq 100.0) {
            $this.Complete()
        }
    }

    [hashtable] GetDefaultRewards() {
        return @{
            Experience = 100
            Currency = 50
            Items = @()
            Reputation = @{}
        }
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
        if ($Data.ContainsKey('Relationships')) { $this.SetProperty('Relationships', $Data.Relationships, $false) }
        if ($Data.ContainsKey('Reputation')) { $this.SetProperty('Reputation', $Data.Reputation, $false) }
        if ($Data.ContainsKey('Goals')) { $this.SetProperty('Goals', $Data.Goals, $false) }
        
        # Reset change tracking after loading
        $this.AcceptChanges()
    }

    [void] InitializeDefaults() {
        # Basic faction properties
        $this.SetProperty('FactionType', 'Organization', $false)
        $this.SetProperty('Alignment', 'Neutral', $false)
        $this.SetProperty('Power', 50, $false)  # 0-100 scale
        $this.SetProperty('Influence', 50, $false)  # 0-100 scale
        $this.SetProperty('Wealth', 50, $false)  # 0-100 scale
        
        # Leadership and hierarchy
        $this.SetProperty('LeaderNPCId', '', $false)
        $this.SetProperty('Officers', @(), $false)
        $this.SetProperty('Members', @(), $false)
        $this.SetProperty('AlliedNPCs', @(), $false)
        
        # Territory and assets
        $this.SetProperty('Territories', @(), $false)
        $this.SetProperty('Strongholds', @(), $false)
        $this.SetProperty('Assets', @(), $false)
        
        # Diplomatic relations
        $this.SetProperty('Relationships', @{}, $false)  # Other faction relationships
        $this.SetProperty('Reputation', @{}, $false)     # Player reputation with faction
        $this.SetProperty('DefaultPlayerReputation', 0, $false)  # -100 to 100
        
        # Goals and activities
        $this.SetProperty('Goals', @(), $false)
        $this.SetProperty('CurrentObjectives', @(), $false)
        $this.SetProperty('RecentActions', @(), $false)
        
        # Economy and resources
        $this.SetProperty('Currency', 1000, $false)
        $this.SetProperty('Resources', @{}, $false)
        $this.SetProperty('TradeRoutes', @(), $false)
        
        # Faction characteristics
        $this.SetProperty('Culture', @{}, $false)
        $this.SetProperty('Beliefs', @(), $false)
        $this.SetProperty('Traditions', @(), $false)
        $this.SetProperty('Symbols', @{}, $false)
        
        # Status and history
        $this.SetProperty('Founded', (Get-Date), $false)
        $this.SetProperty('Status', 'Active', $false)
        $this.SetProperty('HistoricalEvents', @(), $false)
    }

    # Convenient property accessors
    [string] GetFactionType() { return $this.GetProperty('FactionType', 'Organization') }
    [void] SetFactionType([string]$Value) { $this.SetProperty('FactionType', $Value) }
    
    [string] GetAlignment() { return $this.GetProperty('Alignment', 'Neutral') }
    [void] SetAlignment([string]$Value) { $this.SetProperty('Alignment', $Value) }
    
    [string] GetLeaderNPCId() { return $this.GetProperty('LeaderNPCId', '') }
    [void] SetLeaderNPCId([string]$Value) { $this.SetProperty('LeaderNPCId', $Value) }

    # Faction-specific methods
    [void] AddMember([string]$NPCId, [string]$Rank = 'Member') {
        $members = $this.GetProperty('Members', @())
        $memberEntry = @{
            NPCId = $NPCId
            Rank = $Rank
            JoinedAt = Get-Date
            Loyalty = 50  # 0-100 scale
        }
        
        # Check if already a member
        $existing = $members | Where-Object { $_.NPCId -eq $NPCId }
        if (-not $existing) {
            $members += $memberEntry
            $this.SetProperty('Members', $members)
        }
    }

    [void] RemoveMember([string]$NPCId) {
        $members = $this.GetProperty('Members', @())
        $newMembers = $members | Where-Object { $_.NPCId -ne $NPCId }
        $this.SetProperty('Members', $newMembers)
    }

    [void] SetPlayerReputation([string]$PlayerId, [int]$Reputation) {
        $rep = $this.GetProperty('Reputation', @{})
        $rep[$PlayerId] = [Math]::Max(-100, [Math]::Min(100, $Reputation))
        $this.SetProperty('Reputation', $rep)
    }

    [int] GetPlayerReputation([string]$PlayerId) {
        $rep = $this.GetProperty('Reputation', @{})
        if ($rep.ContainsKey($PlayerId)) {
            return $rep[$PlayerId]
        }
        return $this.GetProperty('DefaultPlayerReputation', 0)
    }

    [void] ModifyPlayerReputation([string]$PlayerId, [int]$Change) {
        $current = $this.GetPlayerReputation($PlayerId)
        $new = [Math]::Max(-100, [Math]::Min(100, $current + $Change))
        $this.SetPlayerReputation($PlayerId, $new)
    }

    [void] SetRelationshipWithFaction([string]$OtherFactionId, [int]$Relationship) {
        $relationships = $this.GetProperty('Relationships', @{})
        $relationships[$OtherFactionId] = [Math]::Max(-100, [Math]::Min(100, $Relationship))
        $this.SetProperty('Relationships', $relationships)
    }

    [int] GetRelationshipWithFaction([string]$OtherFactionId) {
        $relationships = $this.GetProperty('Relationships', @{})
        if ($relationships.ContainsKey($OtherFactionId)) {
            return $relationships[$OtherFactionId]
        }
        return 0  # Neutral by default
    }

    [void] AddTerritory([string]$LocationId) {
        $territories = $this.GetProperty('Territories', @())
        if ($territories -notcontains $LocationId) {
            $territories += $LocationId
            $this.SetProperty('Territories', $territories)
        }
    }

    [void] RemoveTerritory([string]$LocationId) {
        $territories = $this.GetProperty('Territories', @())
        $newTerritories = $territories | Where-Object { $_ -ne $LocationId }
        $this.SetProperty('Territories', $newTerritories)
    }

    [void] AddGoal([hashtable]$Goal) {
        $goals = $this.GetProperty('Goals', @())
        $Goal.Id = [System.Guid]::NewGuid().ToString()
        $Goal.CreatedAt = Get-Date
        $Goal.Status = 'Active'
        $goals += $Goal
        $this.SetProperty('Goals', $goals)
    }

    [void] CompleteGoal([string]$GoalId) {
        $goals = $this.GetProperty('Goals', @())
        foreach ($goal in $goals) {
            if ($goal.Id -eq $GoalId) {
                $goal.Status = 'Completed'
                $goal.CompletedAt = Get-Date
                break
            }
        }
        $this.SetProperty('Goals', $goals)
    }
}

    [void] InitializeDefaults() {
        $this.NPCType = 'Generic'
        $this.Race = 'Human'
        $this.Gender = 'Unknown'
        $this.Age = 'Adult'
        $this.Appearance = @{}
        $this.Portrait = ''
        $this.Animations = @()
        $this.AIBehavior = @{}
        $this.PersonalityType = 'Neutral'
        $this.DialogueOptions = @()
        $this.Reactions = @{}
        $this.SpawnLocation = @{}
        $this.PatrolRoute = @()
        $this.MovementSpeed = 1.0
        $this.IsStationary = $true
        $this.AvailableServices = @()
        $this.Inventory = @{}
        $this.QuestsOffered = @()
        $this.RelationshipData = @{}
        $this.CombatStats = @{}
        $this.Abilities = @()
        $this.Faction = 'Neutral'
        $this.HostilityLevel = 'Neutral'
        $this.Schedule = @{}
        $this.AvailableHours = @()
        $this.IsCurrentlyAvailable = $true
    }

    [hashtable] ToHashtable() {
        $baseData = ([GameEntity]$this).ToHashtable()
        $npcData = @{
            NPCType = $this.NPCType
            Race = $this.Race
            Gender = $this.Gender
            Age = $this.Age
            Appearance = $this.Appearance
            Portrait = $this.Portrait
            Animations = $this.Animations
            AIBehavior = $this.AIBehavior
            PersonalityType = $this.PersonalityType
            DialogueOptions = $this.DialogueOptions
            Reactions = $this.Reactions
            SpawnLocation = $this.SpawnLocation
            PatrolRoute = $this.PatrolRoute
            MovementSpeed = $this.MovementSpeed
            IsStationary = $this.IsStationary
            AvailableServices = $this.AvailableServices
            Inventory = $this.Inventory
            QuestsOffered = $this.QuestsOffered
            RelationshipData = $this.RelationshipData
            CombatStats = $this.CombatStats
            Abilities = $this.Abilities
            Faction = $this.Faction
            HostilityLevel = $this.HostilityLevel
            Schedule = $this.Schedule
            AvailableHours = $this.AvailableHours
            IsCurrentlyAvailable = $this.IsCurrentlyAvailable
        }

        return $baseData + $npcData
    }
}

# Item Entity Class
class Item : GameEntity {
    # Core Properties
    [string]$ItemType
    [string]$Rarity
    [int]$StackSize
    [decimal]$Weight
    [decimal]$Value
    [string]$IconPath

    # Usage Properties
    [bool]$IsConsumable
    [bool]$IsEquippable
    [bool]$IsTradeable
    [bool]$IsDroppable
    [int]$Durability
    [int]$MaxDurability

    # Requirements
    [hashtable]$Requirements
    [int]$LevelRequirement
    [array]$ClassRestrictions

    # Effects
    [array]$Effects
    [hashtable]$Bonuses
    [array]$EnchantmentSlots
    [array]$CurrentEnchantments

    # Crafting
    [bool]$IsCraftable
    [array]$CraftingRecipe
    [string]$CraftingSkill
    [int]$CraftingLevel

    # Lore & Story
    [string]$FlavorText
    [string]$OriginStory
    [bool]$IsQuestItem
    [string]$QuestId

    Item() : base() {
        $this.Type = 'Item'
        $this.InitializeDefaults()
    }

    Item([hashtable]$Data) : base($Data) {
        $this.Type = 'Item'
        $this.ItemType = if ($Data.ItemType) { $Data.ItemType } else { 'Generic' }
        $this.Rarity = if ($Data.Rarity) { $Data.Rarity } else { 'Common' }
        $this.StackSize = if ($Data.StackSize) { $Data.StackSize } else { 1 }
        $this.Weight = if ($Data.Weight) { $Data.Weight } else { 0.1 }
        $this.Value = if ($Data.Value) { $Data.Value } else { 1 }
        $this.IconPath = if ($Data.IconPath) { $Data.IconPath } else { '' }
        $this.IsConsumable = if ($null -ne $Data.IsConsumable) { $Data.IsConsumable } else { $false }
        $this.IsEquippable = if ($null -ne $Data.IsEquippable) { $Data.IsEquippable } else { $false }
        $this.IsTradeable = if ($null -ne $Data.IsTradeable) { $Data.IsTradeable } else { $true }
        $this.IsDroppable = if ($null -ne $Data.IsDroppable) { $Data.IsDroppable } else { $true }
        $this.Durability = if ($Data.Durability) { $Data.Durability } else { 100 }
        $this.MaxDurability = if ($Data.MaxDurability) { $Data.MaxDurability } else { 100 }
        $this.Requirements = if ($Data.Requirements) { $Data.Requirements } else { @{} }
        $this.LevelRequirement = if ($Data.LevelRequirement) { $Data.LevelRequirement } else { 1 }
        $this.ClassRestrictions = if ($Data.ClassRestrictions) { @($Data.ClassRestrictions) } else { @() }
        $this.Effects = if ($Data.Effects) { @($Data.Effects) } else { @() }
        $this.Bonuses = if ($Data.Bonuses) { $Data.Bonuses } else { @{} }
        $this.EnchantmentSlots = if ($Data.EnchantmentSlots) { @($Data.EnchantmentSlots) } else { @() }
        $this.CurrentEnchantments = if ($Data.CurrentEnchantments) { @($Data.CurrentEnchantments) } else { @() }
        $this.IsCraftable = if ($null -ne $Data.IsCraftable) { $Data.IsCraftable } else { $false }
        $this.CraftingRecipe = if ($Data.CraftingRecipe) { @($Data.CraftingRecipe) } else { @() }
        $this.CraftingSkill = if ($Data.CraftingSkill) { $Data.CraftingSkill } else { '' }
        $this.CraftingLevel = if ($Data.CraftingLevel) { $Data.CraftingLevel } else { 1 }
        $this.FlavorText = if ($Data.FlavorText) { $Data.FlavorText } else { '' }
        $this.OriginStory = if ($Data.OriginStory) { $Data.OriginStory } else { '' }
        $this.IsQuestItem = if ($null -ne $Data.IsQuestItem) { $Data.IsQuestItem } else { $false }
        $this.QuestId = if ($Data.QuestId) { $Data.QuestId } else { $null }
    }

    [void] InitializeDefaults() {
        $this.ItemType = 'Generic'
        $this.Rarity = 'Common'
        $this.StackSize = 1
        $this.Weight = 0.1
        $this.Value = 1
        $this.IconPath = ''
        $this.IsConsumable = $false
        $this.IsEquippable = $false
        $this.IsTradeable = $true
        $this.IsDroppable = $true
        $this.Durability = 100
        $this.MaxDurability = 100
        $this.Requirements = @{}
        $this.LevelRequirement = 1
        $this.ClassRestrictions = @()
        $this.Effects = @()
        $this.Bonuses = @{}
        $this.EnchantmentSlots = @()
        $this.CurrentEnchantments = @()
        $this.IsCraftable = $false
        $this.CraftingRecipe = @()
        $this.CraftingSkill = ''
        $this.CraftingLevel = 1
        $this.FlavorText = ''
        $this.OriginStory = ''
        $this.IsQuestItem = $false
        $this.QuestId = $null
    }

    [hashtable] ToHashtable() {
        $baseData = ([GameEntity]$this).ToHashtable()
        $itemData = @{
            ItemType = $this.ItemType
            Rarity = $this.Rarity
            StackSize = $this.StackSize
            Weight = $this.Weight
            Value = $this.Value
            IconPath = $this.IconPath
            IsConsumable = $this.IsConsumable
            IsEquippable = $this.IsEquippable
            IsTradeable = $this.IsTradeable
            IsDroppable = $this.IsDroppable
            Durability = $this.Durability
            MaxDurability = $this.MaxDurability
            Requirements = $this.Requirements
            LevelRequirement = $this.LevelRequirement
            ClassRestrictions = $this.ClassRestrictions
            Effects = $this.Effects
            Bonuses = $this.Bonuses
            EnchantmentSlots = $this.EnchantmentSlots
            CurrentEnchantments = $this.CurrentEnchantments
            IsCraftable = $this.IsCraftable
            CraftingRecipe = $this.CraftingRecipe
            CraftingSkill = $this.CraftingSkill
            CraftingLevel = $this.CraftingLevel
            FlavorText = $this.FlavorText
            OriginStory = $this.OriginStory
            IsQuestItem = $this.IsQuestItem
            QuestId = $this.QuestId
        }

        return $baseData + $itemData
    }

    [void] RepairItem([int]$Amount = -1) {
        if ($Amount -eq -1) {
            $this.Durability = $this.MaxDurability
        } else {
            $this.Durability = [math]::Min($this.Durability + $Amount, $this.MaxDurability)
        }
        $this.UpdateTimestamp()
    }

    [void] DamageItem([int]$Amount) {
        $this.Durability = [math]::Max($this.Durability - $Amount, 0)
        $this.UpdateTimestamp()
    }

    [bool] IsFullyRepaired() {
        return $this.Durability -eq $this.MaxDurability
    }

    [bool] IsBroken() {
        return $this.Durability -eq 0
    }
}

# Helper functions for creating entities
function New-GameEntity {
    param(
        [hashtable]$Data = @{}
    )
    return [GameEntity]::new($Data)
}

# Entity Validation Functions
function Test-EntityValidity {
    param(
        [object]$Entity,
        [string]$EntityType = $null
    )

    $validationResults = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }

    # Check if entity exists
    if (-not $Entity) {
        $validationResults.Errors += "Entity is null or empty"
        $validationResults.IsValid = $false
        return $validationResults
    }

    # Get entity data
    $entityData = if ($Entity -is [hashtable]) { $Entity } else { $Entity.ToHashtable() }

    # Required field validation
    $requiredFields = @('Id', 'Type', 'Name', 'CreatedAt', 'UpdatedAt', 'Version', 'IsActive')
    foreach ($field in $requiredFields) {
        if (-not $entityData.ContainsKey($field) -or [string]::IsNullOrEmpty($entityData[$field])) {
            $validationResults.Errors += "Required field '$field' is missing or empty"
            $validationResults.IsValid = $false
        }
    }

    # GUID validation
    try {
        [System.Guid]::Parse($entityData.Id) | Out-Null
    }
    catch {
        $validationResults.Errors += "Invalid GUID format for Id: $($entityData.Id)"
        $validationResults.IsValid = $false
    }

    # Type-specific validation
    $typeToValidate = if ($EntityType) { $EntityType } else { $entityData.Type }
    switch ($typeToValidate) {
        'Player' {
            if ($entityData.Level -lt 1 -or $entityData.Level -gt 100) {
                $validationResults.Errors += "Player level must be between 1 and 100"
                $validationResults.IsValid = $false
            }
            if ($entityData.Experience -lt 0) {
                $validationResults.Errors += "Player experience cannot be negative"
                $validationResults.IsValid = $false
            }
        }
        'Item' {
            if ($entityData.Value -lt 0) {
                $validationResults.Errors += "Item value cannot be negative"
                $validationResults.IsValid = $false
            }
            if ($entityData.Weight -lt 0) {
                $validationResults.Errors += "Item weight cannot be negative"
                $validationResults.IsValid = $false
            }
        }
        'NPC' {
            if ([string]::IsNullOrEmpty($entityData.NPCType)) {
                $validationResults.Warnings += "NPC should have a specific type defined"
            }
        }
    }

    return $validationResults
}

# Serialization Functions
function ConvertTo-JsonSafe {
    param(
        [object]$InputObject,
        [int]$Depth = 10
    )

    try {
        if ($InputObject -is [GameEntity]) {
            $data = $InputObject.ToHashtable()
        } elseif ($InputObject -is [hashtable]) {
            $data = $InputObject
        } else {
            $data = $InputObject
        }

        $jsonData = $data | ConvertTo-Json -Depth $Depth -Compress
        return $jsonData
    }
    catch {
        Write-Error "Failed to serialize object: $($_.Exception.Message)"
        return $null
    }
}

function ConvertFrom-JsonSafe {
    param(
        [string]$JsonString,
        [string]$EntityType = $null
    )

    try {
        $data = $JsonString | ConvertFrom-Json
        $hashtableData = Convert-PSCustomObjectToHashtable -InputObject $data

        if ($EntityType) {
            switch ($EntityType) {
                'Player' { return [Player]::new($hashtableData) }
                'NPC' { return [NPC]::new($hashtableData) }
                'Item' { return [Item]::new($hashtableData) }
                default { return [GameEntity]::new($hashtableData) }
            }
        } else {
            # Try to determine type from data
            $type = $hashtableData.Type
            switch ($type) {
                'Player' { return [Player]::new($hashtableData) }
                'NPC' { return [NPC]::new($hashtableData) }
                'Item' { return [Item]::new($hashtableData) }
                default { return [GameEntity]::new($hashtableData) }
            }
        }
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

# Helper functions for creating entities
function New-GameEntity {
    param(
        [hashtable]$Data = @{}
    )
    return [GameEntity]::new($Data)
}

function New-PlayerEntity {
    param(
        [hashtable]$Data = @{}
    )
    return [Player]::new($Data)
}

function New-NPCEntity {
    param(
        [hashtable]$Data = @{}
    )
    return [NPC]::new($Data)
}

function New-ItemEntity {
    param(
        [hashtable]$Data = @{}
    )
    return [Item]::new($Data)
}

function New-LocationEntity {
    param(
        [hashtable]$Data = @{}
    )
    return [Location]::new($Data)
}

function New-QuestEntity {
    param(
        [hashtable]$Data = @{}
    )
    return [Quest]::new($Data)
}

function New-FactionEntity {
    param(
        [hashtable]$Data = @{}
    )
    return [Faction]::new($Data)
}

# Get entity type constants
function Get-EntityTypes {
    return $script:EntityTypes
}

function Get-ItemCategories {
    return $script:ItemCategories
}

function Get-NPCBehaviorTypes {
    return $script:NPCBehaviorTypes
}

function Get-QuestTypes {
    return $script:QuestTypes
}

function Get-QuestStatus {
    return $script:QuestStatus
}

# Export functions and classes for external use
Export-ModuleMember -Function @(
    'New-GameEntity',
    'New-PlayerEntity',
    'New-NPCEntity',
    'New-ItemEntity',
    'New-LocationEntity',
    'New-QuestEntity',
    'New-FactionEntity',
    'Get-EntityTypes',
    'Get-ItemCategories',
    'Get-NPCBehaviorTypes',
    'Get-QuestTypes',
    'Get-QuestStatus',
    'Test-EntityValidity',
    'ConvertTo-JsonSafe',
    'ConvertFrom-JsonSafe',
    'Convert-PSCustomObjectToHashtable'
)

# Export the entity type constants as variables
Export-ModuleMember -Variable @(
    'EntityTypes',
    'ItemCategories',
    'NPCBehaviorTypes',
    'QuestTypes',
    'QuestStatus'
)
