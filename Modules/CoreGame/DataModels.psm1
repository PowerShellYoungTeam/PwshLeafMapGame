# Entity Data Models Module
# Implements the core data models for PowerShell Leafmap RPG

# Base Entity Class
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
    [hashtable]$CustomProperties

    GameEntity() {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Type = 'Entity'
        $this.Name = ''
        $this.Description = ''
        $this.Tags = @{}
        $this.Metadata = @{}
        $this.CreatedAt = Get-Date
        $this.UpdatedAt = Get-Date
        $this.Version = '1.0.0'
        $this.IsActive = $true
        $this.CustomProperties = @{}
    }

    GameEntity([hashtable]$Data) {
        $this.Id = if ($Data.Id) { $Data.Id } else { [System.Guid]::NewGuid().ToString() }
        $this.Type = if ($Data.Type) { $Data.Type } else { 'Entity' }
        $this.Name = if ($Data.Name) { $Data.Name } else { '' }
        $this.Description = if ($Data.Description) { $Data.Description } else { '' }
        $this.Tags = if ($Data.Tags) { $Data.Tags } else { @{} }
        $this.Metadata = if ($Data.Metadata) { $Data.Metadata } else { @{} }
        $this.CreatedAt = if ($Data.CreatedAt) { [DateTime]$Data.CreatedAt } else { Get-Date }
        $this.UpdatedAt = if ($Data.UpdatedAt) { [DateTime]$Data.UpdatedAt } else { Get-Date }
        $this.Version = if ($Data.Version) { $Data.Version } else { '1.0.0' }
        $this.IsActive = if ($null -ne $Data.IsActive) { $Data.IsActive } else { $true }
        $this.CustomProperties = if ($Data.CustomProperties) { $Data.CustomProperties } else { @{} }
    }

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
            CustomProperties = $this.CustomProperties
        }
    }

    [string] ToJson() {
        return $this.ToHashtable() | ConvertTo-Json -Depth 10
    }

    [void] UpdateTimestamp() {
        $this.UpdatedAt = Get-Date
    }
}

# Player Entity Class
class Player : GameEntity {
    # Identity Properties
    [string]$Username
    [string]$Email
    [string]$DisplayName

    # Character Properties
    [int]$Level
    [long]$Experience
    [long]$ExperienceToNext
    [hashtable]$Attributes
    [hashtable]$Skills

    # Game State
    [hashtable]$Location
    [string]$LastLocationId
    [array]$VisitedLocations
    [long]$Score
    [string]$GameState

    # Inventory & Equipment
    [array]$Inventory
    [hashtable]$Equipment
    [int]$InventoryCapacity
    [decimal]$Currency

    # Progress & Achievements
    [array]$Achievements
    [hashtable]$QuestProgress
    [hashtable]$Statistics
    [array]$CompletedQuests

    # Social & Multiplayer
    [array]$Friends
    [string]$GuildId
    [hashtable]$Reputation

    # Preferences & Settings
    [hashtable]$Preferences
    [hashtable]$UISettings
    [string]$Theme

    # Session Data
    [DateTime]$LastLogin
    [TimeSpan]$PlayTime
    [DateTime]$SessionStart
    [bool]$IsOnline

    # Backup & Recovery
    [string]$BackupData
    [DateTime]$LastBackup

    Player() : base() {
        $this.Type = 'Player'
        $this.InitializeDefaults()
    }

    Player([hashtable]$Data) : base($Data) {
        $this.Type = 'Player'
        $this.Username = if ($Data.Username) { $Data.Username } else { '' }
        $this.Email = if ($Data.Email) { $Data.Email } else { '' }
        $this.DisplayName = if ($Data.DisplayName) { $Data.DisplayName } else { '' }
        $this.Level = if ($Data.Level) { $Data.Level } else { 1 }
        $this.Experience = if ($Data.Experience) { $Data.Experience } else { 0 }
        $this.ExperienceToNext = if ($Data.ExperienceToNext) { $Data.ExperienceToNext } else { 1000 }
        $this.Attributes = if ($Data.Attributes) { $Data.Attributes } else { $this.GetDefaultAttributes() }
        $this.Skills = if ($Data.Skills) { $Data.Skills } else { $this.GetDefaultSkills() }
        $this.Location = if ($Data.Location) { $Data.Location } else { @{} }
        $this.LastLocationId = if ($Data.LastLocationId) { $Data.LastLocationId } else { '' }
        $this.VisitedLocations = if ($Data.VisitedLocations) { @($Data.VisitedLocations) } else { @() }
        $this.Score = if ($Data.Score) { $Data.Score } else { 0 }
        $this.GameState = if ($Data.GameState) { $Data.GameState } else { 'Active' }
        $this.Inventory = if ($Data.Inventory) { @($Data.Inventory) } else { @() }
        $this.Equipment = if ($Data.Equipment) { $Data.Equipment } else { $this.GetDefaultEquipment() }
        $this.InventoryCapacity = if ($Data.InventoryCapacity) { $Data.InventoryCapacity } else { 30 }
        $this.Currency = if ($Data.Currency) { $Data.Currency } else { 100 }
        $this.Achievements = if ($Data.Achievements) { @($Data.Achievements) } else { @() }
        $this.QuestProgress = if ($Data.QuestProgress) { $Data.QuestProgress } else { @{} }
        $this.Statistics = if ($Data.Statistics) { $Data.Statistics } else { $this.GetDefaultStatistics() }
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
    # Identity
    [string]$NPCType
    [string]$Race
    [string]$Gender
    [string]$Age

    # Appearance
    [hashtable]$Appearance
    [string]$Portrait
    [array]$Animations

    # Behavior
    [hashtable]$AIBehavior
    [string]$PersonalityType
    [array]$DialogueOptions
    [hashtable]$Reactions

    # Location & Movement
    [hashtable]$SpawnLocation
    [array]$PatrolRoute
    [decimal]$MovementSpeed
    [bool]$IsStationary

    # Interaction
    [array]$AvailableServices
    [hashtable]$Inventory
    [array]$QuestsOffered
    [hashtable]$RelationshipData

    # Combat (if applicable)
    [hashtable]$CombatStats
    [array]$Abilities
    [string]$Faction
    [string]$HostilityLevel

    # Schedule & Availability
    [hashtable]$Schedule
    [array]$AvailableHours
    [bool]$IsCurrentlyAvailable

    NPC() : base() {
        $this.Type = 'NPC'
        $this.InitializeDefaults()
    }

    NPC([hashtable]$Data) : base($Data) {
        $this.Type = 'NPC'
        $this.NPCType = if ($Data.NPCType) { $Data.NPCType } else { 'Generic' }
        $this.Race = if ($Data.Race) { $Data.Race } else { 'Human' }
        $this.Gender = if ($Data.Gender) { $Data.Gender } else { 'Unknown' }
        $this.Age = if ($Data.Age) { $Data.Age } else { 'Adult' }
        $this.Appearance = if ($Data.Appearance) { $Data.Appearance } else { @{} }
        $this.Portrait = if ($Data.Portrait) { $Data.Portrait } else { '' }
        $this.Animations = if ($Data.Animations) { @($Data.Animations) } else { @() }
        $this.AIBehavior = if ($Data.AIBehavior) { $Data.AIBehavior } else { @{} }
        $this.PersonalityType = if ($Data.PersonalityType) { $Data.PersonalityType } else { 'Neutral' }
        $this.DialogueOptions = if ($Data.DialogueOptions) { @($Data.DialogueOptions) } else { @() }
        $this.Reactions = if ($Data.Reactions) { $Data.Reactions } else { @{} }
        $this.SpawnLocation = if ($Data.SpawnLocation) { $Data.SpawnLocation } else { @{} }
        $this.PatrolRoute = if ($Data.PatrolRoute) { @($Data.PatrolRoute) } else { @() }
        $this.MovementSpeed = if ($Data.MovementSpeed) { $Data.MovementSpeed } else { 1.0 }
        $this.IsStationary = if ($null -ne $Data.IsStationary) { $Data.IsStationary } else { $true }
        $this.AvailableServices = if ($Data.AvailableServices) { @($Data.AvailableServices) } else { @() }
        $this.Inventory = if ($Data.Inventory) { $Data.Inventory } else { @{} }
        $this.QuestsOffered = if ($Data.QuestsOffered) { @($Data.QuestsOffered) } else { @() }
        $this.RelationshipData = if ($Data.RelationshipData) { $Data.RelationshipData } else { @{} }
        $this.CombatStats = if ($Data.CombatStats) { $Data.CombatStats } else { @{} }
        $this.Abilities = if ($Data.Abilities) { @($Data.Abilities) } else { @() }
        $this.Faction = if ($Data.Faction) { $Data.Faction } else { 'Neutral' }
        $this.HostilityLevel = if ($Data.HostilityLevel) { $Data.HostilityLevel } else { 'Neutral' }
        $this.Schedule = if ($Data.Schedule) { $Data.Schedule } else { @{} }
        $this.AvailableHours = if ($Data.AvailableHours) { @($Data.AvailableHours) } else { @() }
        $this.IsCurrentlyAvailable = if ($null -ne $Data.IsCurrentlyAvailable) { $Data.IsCurrentlyAvailable } else { $true }
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

# Entity Factory Functions
function New-PlayerEntity {
    param(
        [string]$Username,
        [string]$Email,
        [string]$DisplayName,
        [hashtable]$AdditionalData = @{}
    )

    $playerData = @{
        Username = $Username
        Email = $Email
        DisplayName = $DisplayName
        Name = $DisplayName
        Description = "Player character for $Username"
    } + $AdditionalData

    return [Player]::new($playerData)
}

function New-NPCEntity {
    param(
        [string]$Name,
        [string]$NPCType,
        [string]$Description = '',
        [hashtable]$AdditionalData = @{}
    )

    $npcData = @{
        Name = $Name
        NPCType = $NPCType
        Description = $Description
    } + $AdditionalData

    return [NPC]::new($npcData)
}

function New-ItemEntity {
    param(
        [string]$Name,
        [string]$ItemType,
        [string]$Description = '',
        [hashtable]$AdditionalData = @{}
    )

    $itemData = @{
        Name = $Name
        ItemType = $ItemType
        Description = $Description
    } + $AdditionalData

    return [Item]::new($itemData)
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

# Export functions and classes for external use
Export-ModuleMember -Function @(
    'New-PlayerEntity',
    'New-NPCEntity',
    'New-ItemEntity',
    'Test-EntityValidity',
    'ConvertTo-JsonSafe',
    'ConvertFrom-JsonSafe',
    'Convert-PSCustomObjectToHashtable'
)
