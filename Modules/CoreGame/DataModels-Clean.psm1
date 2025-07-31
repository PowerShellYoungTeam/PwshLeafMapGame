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

# Export the entity type constants as variables
Export-ModuleMember -Variable @(
    'EntityTypes',
    'ItemCategories',
    'NPCBehaviorTypes',
    'QuestTypes',
    'QuestStatus'
)
