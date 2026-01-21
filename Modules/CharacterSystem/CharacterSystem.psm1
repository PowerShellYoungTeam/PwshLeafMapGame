# CharacterSystem Module
# Provides character management functions for player/NPC entities
# Depends on: CoreGame (DataModels, StateManager, EventSystem)

# ============================================
# Module Variables
# ============================================
$script:CharacterSystemInitialized = $false
$script:CharacterConfig = @{
    BaseXPPerLevel          = 1000
    XPMultiplier            = 1.5
    MaxLevel                = 100
    SkillPointsPerLevel     = 3
    AttributePointsPerLevel = 2
    StartingCredits         = 100
    InventoryBaseCapacity   = 20
}

# Cyberpunk attribute definitions
$script:Attributes = @{
    Strength     = @{
        Name          = 'Strength'
        Description   = 'Physical power, melee damage, carrying capacity'
        AffectedStats = @('MeleeDamage', 'CarryCapacity')
    }
    Reflex       = @{
        Name          = 'Reflex'
        Description   = 'Speed, evasion, accuracy with ranged weapons'
        AffectedStats = @('Evasion', 'CritChance', 'RangedAccuracy')
    }
    Technical    = @{
        Name          = 'Technical'
        Description   = 'Hacking, crafting, tech weapon damage'
        AffectedStats = @('HackingSuccess', 'CraftQuality', 'TechDamage')
    }
    Intelligence = @{
        Name          = 'Intelligence'
        Description   = 'Quick hacking, netrunning, dialogue options'
        AffectedStats = @('QuickHackDamage', 'RAMCapacity')
    }
    Cool         = @{
        Name          = 'Cool'
        Description   = 'Stealth, cold blood, critical damage'
        AffectedStats = @('StealthBonus', 'CritDamage', 'Intimidation')
    }
    Body         = @{
        Name          = 'Body'
        Description   = 'Health, stamina, damage resistance'
        AffectedStats = @('MaxHealth', 'Stamina', 'DamageResist')
    }
}

# Skill categories (Cyberpunk-inspired)
$script:SkillCategories = @{
    Combat  = @('Handguns', 'Rifles', 'Blades', 'Athletics', 'Annihilation')
    Stealth = @('Stealth', 'ColdBlood', 'NinjutsuArts')
    Tech    = @('Crafting', 'Engineering', 'QuickHacking')
    Social  = @('Breach', 'Streetwise', 'Negotiation', 'Intimidation')
}

# ============================================
# Initialize Function
# ============================================
function Initialize-CharacterSystem {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{}
    )

    # Merge custom configuration
    foreach ($key in $Configuration.Keys) {
        if ($script:CharacterConfig.ContainsKey($key)) {
            $script:CharacterConfig[$key] = $Configuration[$key]
        }
    }

    $script:CharacterSystemInitialized = $true

    # Note: Event handlers should be registered by the game startup, not here.
    # The CharacterSystem fires events but doesn't need to register handlers.

    Write-Verbose "CharacterSystem initialized with config: $($script:CharacterConfig | ConvertTo-Json -Compress)"

    return @{
        Initialized   = $true
        ModuleName    = 'CharacterSystem'
        Configuration = $script:CharacterConfig
    }
}

# ============================================
# Character Creation Functions
# ============================================
function New-Character {
    <#
    .SYNOPSIS
        Creates a new player character with cyberpunk attributes
    .DESCRIPTION
        Creates a fully initialized player entity with starting attributes, skills, and inventory
    .PARAMETER Name
        Character's display name
    .PARAMETER Background
        Character background (affects starting bonuses): Solo, Netrunner, Techie, Corpo, Nomad, StreetKid
    .PARAMETER AttributePoints
        Hashtable of starting attribute allocations
    .EXAMPLE
        $player = New-Character -Name "V" -Background "StreetKid"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Solo', 'Netrunner', 'Techie', 'Corpo', 'Nomad', 'StreetKid')]
        [string]$Background = 'StreetKid',

        [Parameter()]
        [hashtable]$AttributePoints = @{}
    )

    # Create base player using DataModels function
    $playerData = @{
        Name        = $Name
        Description = "A $Background from the streets"
    }

    $player = New-PlayerEntity -Data $playerData

    # Initialize cyberpunk attributes
    $baseAttributes = @{
        Strength     = 3
        Reflex       = 3
        Technical    = 3
        Intelligence = 3
        Cool         = 3
        Body         = 3
    }

    # Apply background bonuses
    switch ($Background) {
        'Solo' {
            $baseAttributes.Reflex += 2
            $baseAttributes.Body += 1
        }
        'Netrunner' {
            $baseAttributes.Intelligence += 2
            $baseAttributes.Technical += 1
        }
        'Techie' {
            $baseAttributes.Technical += 2
            $baseAttributes.Intelligence += 1
        }
        'Corpo' {
            $baseAttributes.Cool += 2
            $baseAttributes.Intelligence += 1
        }
        'Nomad' {
            $baseAttributes.Technical += 1
            $baseAttributes.Reflex += 1
            $baseAttributes.Body += 1
        }
        'StreetKid' {
            $baseAttributes.Cool += 1
            $baseAttributes.Reflex += 1
            $baseAttributes.Strength += 1
        }
    }

    # Apply custom attribute points
    foreach ($attr in $AttributePoints.Keys) {
        if ($baseAttributes.ContainsKey($attr)) {
            $baseAttributes[$attr] += $AttributePoints[$attr]
        }
    }

    $player.SetProperty('Attributes', $baseAttributes, $false)
    $player.SetProperty('Background', $Background, $false)
    $player.SetProperty('UnspentAttributePoints', 0, $false)
    $player.SetProperty('UnspentSkillPoints', 0, $false)

    # Initialize derived stats
    Update-CharacterDerivedStats -Character $player

    # Initialize empty skills
    $player.SetProperty('Skills', @{}, $false)

    # Initialize equipment slots (cyberpunk style)
    $player.SetProperty('Equipment', @{
            Head        = $null
            Face        = $null
            OuterTorso  = $null
            InnerTorso  = $null
            Legs        = $null
            Feet        = $null
            WeaponSlot1 = $null
            WeaponSlot2 = $null
            WeaponSlot3 = $null
            Cyberware   = @()
        }, $false)

    # Set starting credits
    $player.SetProperty('Credits', $script:CharacterConfig.StartingCredits, $false)

    # Reset change tracking
    $player.AcceptChanges()

    Write-Verbose "Created character '$Name' with background '$Background'"
    return $player
}

# ============================================
# Character Attribute Functions
# ============================================
function Get-CharacterAttribute {
    <#
    .SYNOPSIS
        Gets a character's attribute value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Strength', 'Reflex', 'Technical', 'Intelligence', 'Cool', 'Body')]
        [string]$AttributeName
    )

    $attributes = $Character.GetProperty('Attributes', @{})
    return $attributes[$AttributeName] ?? 0
}

function Set-CharacterAttribute {
    <#
    .SYNOPSIS
        Sets a character's attribute value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Strength', 'Reflex', 'Technical', 'Intelligence', 'Cool', 'Body')]
        [string]$AttributeName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 20)]
        [int]$Value
    )

    $attributes = $Character.GetProperty('Attributes', @{})
    $attributes[$AttributeName] = $Value
    $Character.SetProperty('Attributes', $attributes)

    # Recalculate derived stats
    Update-CharacterDerivedStats -Character $Character
}

function Add-CharacterAttributePoint {
    <#
    .SYNOPSIS
        Spends an attribute point to increase an attribute
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Strength', 'Reflex', 'Technical', 'Intelligence', 'Cool', 'Body')]
        [string]$AttributeName
    )

    $unspent = $Character.GetProperty('UnspentAttributePoints', 0)
    if ($unspent -lt 1) {
        Write-Warning "No unspent attribute points available"
        return $false
    }

    $attributes = $Character.GetProperty('Attributes', @{})
    $currentValue = $attributes[$AttributeName] ?? 0

    if ($currentValue -ge 20) {
        Write-Warning "Attribute '$AttributeName' is already at maximum"
        return $false
    }

    $attributes[$AttributeName] = $currentValue + 1
    $Character.SetProperty('Attributes', $attributes)
    $Character.SetProperty('UnspentAttributePoints', $unspent - 1)

    Update-CharacterDerivedStats -Character $Character

    return $true
}

function Update-CharacterDerivedStats {
    <#
    .SYNOPSIS
        Updates derived stats based on attributes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    $attrs = $Character.GetProperty('Attributes', @{})

    # Calculate derived stats
    $maxHealth = 100 + (($attrs.Body ?? 3) * 10)
    $maxStamina = 100 + (($attrs.Body ?? 3) * 5) + (($attrs.Reflex ?? 3) * 5)
    $carryCapacity = 50 + (($attrs.Strength ?? 3) * 10)
    $critChance = 5 + (($attrs.Reflex ?? 3) * 2)
    $critDamage = 150 + (($attrs.Cool ?? 3) * 5)
    $evasion = ($attrs.Reflex ?? 3) * 2
    $armor = ($attrs.Body ?? 3)

    $Character.SetProperty('MaxHealth', $maxHealth, $false)
    $Character.SetProperty('MaxStamina', $maxStamina, $false)
    $Character.SetProperty('CarryCapacity', $carryCapacity, $false)
    $Character.SetProperty('CritChance', $critChance, $false)
    $Character.SetProperty('CritDamage', $critDamage, $false)
    $Character.SetProperty('Evasion', $evasion, $false)
    $Character.SetProperty('BaseArmor', $armor, $false)

    # Set current health/stamina to max if higher
    $currentHealth = $Character.GetProperty('Health', $maxHealth)
    if ($currentHealth -gt $maxHealth) {
        $Character.SetProperty('Health', $maxHealth, $false)
    }
}

# ============================================
# Character Leveling Functions
# ============================================
function Add-CharacterExperience {
    <#
    .SYNOPSIS
        Adds experience to a character and checks for level ups
    .PARAMETER Character
        The character entity to add experience to
    .PARAMETER Amount
        Amount of XP to add
    .PARAMETER Source
        Optional description of XP source
    .EXAMPLE
        Add-CharacterExperience -Character $player -Amount 500 -Source "Completed mission"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Amount,

        [Parameter()]
        [string]$Source = "Unknown"
    )

    $currentXP = $Character.GetProperty('Experience', 0)
    $newXP = $currentXP + $Amount
    $Character.SetProperty('Experience', $newXP)

    Write-Verbose "Added $Amount XP to $($Character.Name) from '$Source' (Total: $newXP)"

    # Check for level ups
    $leveledUp = $false
    while (Test-CharacterCanLevelUp -Character $Character) {
        Invoke-CharacterLevelUp -Character $Character
        $leveledUp = $true
    }

    return @{
        XPAdded      = $Amount
        TotalXP      = $newXP
        LeveledUp    = $leveledUp
        CurrentLevel = $Character.GetProperty('Level', 1)
    }
}

function Get-ExperienceForLevel {
    <#
    .SYNOPSIS
        Calculates XP required to reach a given level
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 100)]
        [int]$Level
    )

    if ($Level -eq 1) { return 0 }

    $baseXP = $script:CharacterConfig.BaseXPPerLevel
    $multiplier = $script:CharacterConfig.XPMultiplier

    # Exponential formula: BaseXP * (Level - 1)^Multiplier
    return [Math]::Floor($baseXP * [Math]::Pow($Level - 1, $multiplier))
}

function Test-CharacterCanLevelUp {
    <#
    .SYNOPSIS
        Checks if character has enough XP to level up
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    $currentLevel = $Character.GetProperty('Level', 1)
    $currentXP = $Character.GetProperty('Experience', 0)
    $maxLevel = $script:CharacterConfig.MaxLevel

    if ($currentLevel -ge $maxLevel) { return $false }

    $xpForNextLevel = Get-ExperienceForLevel -Level ($currentLevel + 1)
    return $currentXP -ge $xpForNextLevel
}

function Invoke-CharacterLevelUp {
    <#
    .SYNOPSIS
        Levels up a character, granting attribute and skill points
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    $currentLevel = $Character.GetProperty('Level', 1)
    $newLevel = $currentLevel + 1

    $Character.SetProperty('Level', $newLevel)

    # Grant attribute points
    $currentAttrPoints = $Character.GetProperty('UnspentAttributePoints', 0)
    $Character.SetProperty('UnspentAttributePoints', $currentAttrPoints + $script:CharacterConfig.AttributePointsPerLevel)

    # Grant skill points
    $currentSkillPoints = $Character.GetProperty('UnspentSkillPoints', 0)
    $Character.SetProperty('UnspentSkillPoints', $currentSkillPoints + $script:CharacterConfig.SkillPointsPerLevel)

    # Update derived stats
    Update-CharacterDerivedStats -Character $Character

    # Fire event if available
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'CharacterLevelUp' -Data @{
            CharacterId   = $Character.Id
            CharacterName = $Character.Name
            NewLevel      = $newLevel
            Timestamp     = Get-Date
        }
    }

    Write-Verbose "$($Character.Name) leveled up to level $newLevel!"

    return @{
        NewLevel              = $newLevel
        AttributePointsGained = $script:CharacterConfig.AttributePointsPerLevel
        SkillPointsGained     = $script:CharacterConfig.SkillPointsPerLevel
    }
}

# ============================================
# Character Combat Functions
# ============================================
function Add-CharacterDamage {
    <#
    .SYNOPSIS
        Applies damage to a character
    .PARAMETER Character
        The character to damage
    .PARAMETER Amount
        Amount of damage to deal
    .PARAMETER DamageType
        Type of damage: Physical, Fire, Electric, Chemical, EMP
    .PARAMETER IgnoreArmor
        If true, damage bypasses armor
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Amount,

        [Parameter()]
        [ValidateSet('Physical', 'Fire', 'Electric', 'Chemical', 'EMP')]
        [string]$DamageType = 'Physical',

        [Parameter()]
        [switch]$IgnoreArmor
    )

    $armor = $Character.GetProperty('BaseArmor', 0)
    $equipmentArmor = Get-CharacterTotalArmor -Character $Character
    $totalArmor = $armor + $equipmentArmor

    # Calculate actual damage
    $actualDamage = $Amount
    if (-not $IgnoreArmor) {
        $reduction = [Math]::Min($totalArmor * 2, $Amount * 0.75)  # Max 75% reduction
        $actualDamage = [Math]::Max(1, $Amount - $reduction)
    }

    $currentHealth = $Character.GetProperty('Health', 100)
    $newHealth = [Math]::Max(0, $currentHealth - $actualDamage)
    $Character.SetProperty('Health', $newHealth)

    $isAlive = $newHealth -gt 0
    $Character.SetProperty('IsAlive', $isAlive)

    # Fire event if available
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'CharacterDamaged' -Data @{
            CharacterId     = $Character.Id
            DamageDealt     = $actualDamage
            DamageType      = $DamageType
            RemainingHealth = $newHealth
            IsAlive         = $isAlive
        }
    }

    return @{
        DamageDealt     = $actualDamage
        DamageBlocked   = $Amount - $actualDamage
        RemainingHealth = $newHealth
        IsAlive         = $isAlive
    }
}

function Add-CharacterHealing {
    <#
    .SYNOPSIS
        Heals a character
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Amount
    )

    $currentHealth = $Character.GetProperty('Health', 100)
    $maxHealth = $Character.GetProperty('MaxHealth', 100)

    $newHealth = [Math]::Min($maxHealth, $currentHealth + $Amount)
    $actualHealing = $newHealth - $currentHealth
    $Character.SetProperty('Health', $newHealth)

    # Revive if was dead
    if ($currentHealth -eq 0 -and $newHealth -gt 0) {
        $Character.SetProperty('IsAlive', $true)
    }

    # Fire event if available
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'CharacterHealed' -Data @{
            CharacterId   = $Character.Id
            HealingAmount = $actualHealing
            CurrentHealth = $newHealth
        }
    }

    return @{
        HealingApplied = $actualHealing
        CurrentHealth  = $newHealth
        MaxHealth      = $maxHealth
    }
}

function Get-CharacterTotalArmor {
    <#
    .SYNOPSIS
        Calculates total armor from all equipped items
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    $equipment = $Character.GetProperty('Equipment', @{})
    $totalArmor = 0

    foreach ($slot in $equipment.Keys) {
        $item = $equipment[$slot]
        if ($null -ne $item -and $item -is [hashtable]) {
            $totalArmor += $item.Armor ?? 0
        }
    }

    return $totalArmor
}

# ============================================
# Character Skill Functions
# ============================================
function Get-CharacterSkill {
    <#
    .SYNOPSIS
        Gets a character's skill level
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [string]$SkillName
    )

    $skills = $Character.GetProperty('Skills', @{})
    return $skills[$SkillName] ?? 0
}

function Add-CharacterSkillPoint {
    <#
    .SYNOPSIS
        Spends a skill point to increase a skill
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [string]$SkillName
    )

    $unspent = $Character.GetProperty('UnspentSkillPoints', 0)
    if ($unspent -lt 1) {
        Write-Warning "No unspent skill points available"
        return $false
    }

    $skills = $Character.GetProperty('Skills', @{})
    $currentLevel = $skills[$SkillName] ?? 0

    # Max skill level is 20
    if ($currentLevel -ge 20) {
        Write-Warning "Skill '$SkillName' is already at maximum"
        return $false
    }

    $skills[$SkillName] = $currentLevel + 1
    $Character.SetProperty('Skills', $skills)
    $Character.SetProperty('UnspentSkillPoints', $unspent - 1)

    # Fire event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'SkillLevelUp' -Data @{
            CharacterId = $Character.Id
            SkillName   = $SkillName
            NewLevel    = $currentLevel + 1
        }
    }

    return $true
}

function Get-AllCharacterSkills {
    <#
    .SYNOPSIS
        Gets all skills and their levels for a character
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    return $Character.GetProperty('Skills', @{})
}

# ============================================
# Character Inventory Functions
# ============================================
function Add-CharacterItem {
    <#
    .SYNOPSIS
        Adds an item to a character's inventory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [hashtable]$Item,

        [Parameter()]
        [int]$Quantity = 1
    )

    $inventory = $Character.GetProperty('Inventory', @())
    $capacity = $Character.GetProperty('CarryCapacity', 50)
    $currentWeight = Get-CharacterInventoryWeight -Character $Character
    $itemWeight = ($Item.Weight ?? 0) * $Quantity

    if (($currentWeight + $itemWeight) -gt $capacity) {
        Write-Warning "Cannot add item: would exceed carry capacity"
        return $false
    }

    # Check if item already exists (stackable)
    $existingItem = $inventory | Where-Object { $_.Id -eq $Item.Id }

    if ($existingItem -and ($Item.Stackable -ne $false)) {
        $existingItem.Quantity = ($existingItem.Quantity ?? 1) + $Quantity
    }
    else {
        $newItem = $Item.Clone()
        $newItem.Quantity = $Quantity
        $inventory += $newItem
    }

    $Character.SetProperty('Inventory', $inventory)
    return $true
}

function Remove-CharacterItem {
    <#
    .SYNOPSIS
        Removes an item from a character's inventory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [string]$ItemId,

        [Parameter()]
        [int]$Quantity = 1
    )

    $inventory = @($Character.GetProperty('Inventory', @()))
    $itemIndex = -1

    for ($i = 0; $i -lt $inventory.Count; $i++) {
        if ($inventory[$i].Id -eq $ItemId) {
            $itemIndex = $i
            break
        }
    }

    if ($itemIndex -eq -1) {
        Write-Warning "Item not found in inventory"
        return $false
    }

    $item = $inventory[$itemIndex]
    $currentQty = $item.Quantity ?? 1

    if ($currentQty -le $Quantity) {
        # Remove entire item
        $inventory = $inventory | Where-Object { $_.Id -ne $ItemId }
    }
    else {
        $inventory[$itemIndex].Quantity = $currentQty - $Quantity
    }

    $Character.SetProperty('Inventory', @($inventory))
    return $true
}

function Get-CharacterInventory {
    <#
    .SYNOPSIS
        Gets a character's inventory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    return @($Character.GetProperty('Inventory', @()))
}

function Get-CharacterInventoryWeight {
    <#
    .SYNOPSIS
        Calculates total weight of inventory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    $inventory = $Character.GetProperty('Inventory', @())
    $totalWeight = 0

    foreach ($item in $inventory) {
        $weight = $item.Weight ?? 0
        $quantity = $item.Quantity ?? 1
        $totalWeight += $weight * $quantity
    }

    return $totalWeight
}

# ============================================
# Character Equipment Functions
# ============================================
function Set-CharacterEquipment {
    <#
    .SYNOPSIS
        Equips an item to a character
    .PARAMETER Character
        Character to equip item on
    .PARAMETER Item
        Item hashtable to equip
    .PARAMETER Slot
        Equipment slot to use
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [hashtable]$Item,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Head', 'Face', 'OuterTorso', 'InnerTorso', 'Legs', 'Feet', 'WeaponSlot1', 'WeaponSlot2', 'WeaponSlot3')]
        [string]$Slot
    )

    $equipment = $Character.GetProperty('Equipment', @{})

    # If slot is occupied, unequip current item first
    if ($null -ne $equipment[$Slot]) {
        $oldItem = $equipment[$Slot]
        Add-CharacterItem -Character $Character -Item $oldItem

        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            $null = Send-GameEvent -EventType 'ItemUnequipped' -Data @{
                CharacterId = $Character.Id
                ItemId      = $oldItem.Id
                Slot        = $Slot
            }
        }
    }

    # Remove item from inventory if present
    $inventory = @($Character.GetProperty('Inventory', @()))
    $inventory = $inventory | Where-Object { $_.Id -ne $Item.Id }
    $Character.SetProperty('Inventory', @($inventory))

    # Equip new item
    $equipment[$Slot] = $Item
    $Character.SetProperty('Equipment', $equipment)

    # Update derived stats
    Update-CharacterDerivedStats -Character $Character

    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'ItemEquipped' -Data @{
            CharacterId = $Character.Id
            ItemId      = $Item.Id
            Slot        = $Slot
        }
    }

    return $true
}

function Remove-CharacterEquipment {
    <#
    .SYNOPSIS
        Unequips an item from a character
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Head', 'Face', 'OuterTorso', 'InnerTorso', 'Legs', 'Feet', 'WeaponSlot1', 'WeaponSlot2', 'WeaponSlot3')]
        [string]$Slot
    )

    $equipment = $Character.GetProperty('Equipment', @{})
    $item = $equipment[$Slot]

    if ($null -eq $item) {
        Write-Warning "No item equipped in slot '$Slot'"
        return $false
    }

    # Add item back to inventory
    Add-CharacterItem -Character $Character -Item $item

    # Clear slot
    $equipment[$Slot] = $null
    $Character.SetProperty('Equipment', $equipment)

    # Update derived stats
    Update-CharacterDerivedStats -Character $Character

    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'ItemUnequipped' -Data @{
            CharacterId = $Character.Id
            ItemId      = $item.Id
            Slot        = $Slot
        }
    }

    return $true
}

function Get-CharacterEquipment {
    <#
    .SYNOPSIS
        Gets all equipped items
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    return $Character.GetProperty('Equipment', @{})
}

# ============================================
# Character Currency Functions
# ============================================
function Add-CharacterCredits {
    <#
    .SYNOPSIS
        Adds credits (currency) to a character
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Amount
    )

    $current = $Character.GetProperty('Credits', 0)
    $Character.SetProperty('Credits', $current + $Amount)
    return $current + $Amount
}

function Remove-CharacterCredits {
    <#
    .SYNOPSIS
        Removes credits from a character
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Amount
    )

    $current = $Character.GetProperty('Credits', 0)

    if ($current -lt $Amount) {
        Write-Warning "Insufficient credits. Have: $current, Need: $Amount"
        return $false
    }

    $Character.SetProperty('Credits', $current - $Amount)
    return $true
}

function Get-CharacterCredits {
    <#
    .SYNOPSIS
        Gets a character's credit balance
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    return $Character.GetProperty('Credits', 0)
}

# ============================================
# Character Summary Functions
# ============================================
function Get-CharacterSummary {
    <#
    .SYNOPSIS
        Gets a summary of character stats
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Character
    )

    $attrs = $Character.GetProperty('Attributes', @{})
    $skills = $Character.GetProperty('Skills', @{})
    $equipment = $Character.GetProperty('Equipment', @{})

    return @{
        Name                   = $Character.Name
        Level                  = $Character.GetProperty('Level', 1)
        Experience             = $Character.GetProperty('Experience', 0)
        Background             = $Character.GetProperty('Background', 'Unknown')
        Health                 = $Character.GetProperty('Health', 100)
        MaxHealth              = $Character.GetProperty('MaxHealth', 100)
        IsAlive                = $Character.GetProperty('IsAlive', $true)
        Credits                = $Character.GetProperty('Credits', 0)
        Attributes             = $attrs
        Skills                 = $skills
        EquippedItems          = ($equipment.Values | Where-Object { $null -ne $_ }).Count
        InventoryItems         = ($Character.GetProperty('Inventory', @())).Count
        CarryWeight            = Get-CharacterInventoryWeight -Character $Character
        CarryCapacity          = $Character.GetProperty('CarryCapacity', 50)
        UnspentAttributePoints = $Character.GetProperty('UnspentAttributePoints', 0)
        UnspentSkillPoints     = $Character.GetProperty('UnspentSkillPoints', 0)
    }
}

# ============================================
# Export Functions
# ============================================
Export-ModuleMember -Function @(
    # Initialization
    'Initialize-CharacterSystem'

    # Character Creation
    'New-Character'

    # Attributes
    'Get-CharacterAttribute'
    'Set-CharacterAttribute'
    'Add-CharacterAttributePoint'
    'Update-CharacterDerivedStats'

    # Leveling
    'Add-CharacterExperience'
    'Get-ExperienceForLevel'
    'Test-CharacterCanLevelUp'
    'Invoke-CharacterLevelUp'

    # Combat
    'Add-CharacterDamage'
    'Add-CharacterHealing'
    'Get-CharacterTotalArmor'

    # Skills
    'Get-CharacterSkill'
    'Add-CharacterSkillPoint'
    'Get-AllCharacterSkills'

    # Inventory
    'Add-CharacterItem'
    'Remove-CharacterItem'
    'Get-CharacterInventory'
    'Get-CharacterInventoryWeight'

    # Equipment
    'Set-CharacterEquipment'
    'Remove-CharacterEquipment'
    'Get-CharacterEquipment'

    # Currency
    'Add-CharacterCredits'
    'Remove-CharacterCredits'
    'Get-CharacterCredits'

    # Summary
    'Get-CharacterSummary'
)

