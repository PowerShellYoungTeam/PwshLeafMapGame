# DroneSystem Module
# Handles drones, tactical support, reconnaissance, combat drones, and automated units

#region Module State
$script:DroneSystemState = @{
    Initialized = $false
    Drones = @{}
    PlayerDrones = @{}
    EnemyDrones = @{}
    DroneInventory = @{}
    ActiveMissions = @{}
    MissionHistory = @()
    Configuration = @{}
}

# Drone Types with stats
$script:DroneTypes = @{
    'Scout' = @{
        Description = 'Long-range reconnaissance drone'
        Category = 'Recon'
        BaseHP = 30
        BaseArmor = 0
        BaseSpeed = 80
        BaseScanRadius = 200
        BaseEnergy = 100
        EnergyRegenRate = 5
        BaseAttack = 0
        AttackRange = 0
        Abilities = @('Scan', 'MarkTarget', 'Stealth')
        Cost = 500
        Size = 'Small'
        Noise = 'Low'
        DetectionDifficulty = 70
    }
    'Combat' = @{
        Description = 'Armed attack drone'
        Category = 'Combat'
        BaseHP = 60
        BaseArmor = 10
        BaseSpeed = 50
        BaseScanRadius = 100
        BaseEnergy = 80
        EnergyRegenRate = 3
        BaseAttack = 25
        AttackRange = 150
        Abilities = @('Attack', 'Suppression', 'Strafe')
        Cost = 1500
        Size = 'Medium'
        Noise = 'High'
        DetectionDifficulty = 30
    }
    'Support' = @{
        Description = 'Medical/buff support drone'
        Category = 'Support'
        BaseHP = 50
        BaseArmor = 5
        BaseSpeed = 40
        BaseScanRadius = 80
        BaseEnergy = 120
        EnergyRegenRate = 8
        BaseAttack = 0
        AttackRange = 0
        Abilities = @('Heal', 'Shield', 'Boost')
        HealAmount = 15
        ShieldAmount = 20
        Cost = 1200
        Size = 'Medium'
        Noise = 'Low'
        DetectionDifficulty = 50
    }
    'EMP' = @{
        Description = 'Electronic warfare drone'
        Category = 'Utility'
        BaseHP = 40
        BaseArmor = 0
        BaseSpeed = 60
        BaseScanRadius = 120
        BaseEnergy = 90
        EnergyRegenRate = 4
        BaseAttack = 0
        AttackRange = 0
        Abilities = @('EMPBlast', 'Jamming', 'Hack')
        EMPRadius = 100
        EMPDamage = 50
        Cost = 2000
        Size = 'Small'
        Noise = 'Medium'
        DetectionDifficulty = 40
    }
    'Heavy' = @{
        Description = 'Heavy assault drone'
        Category = 'Combat'
        BaseHP = 120
        BaseArmor = 30
        BaseSpeed = 25
        BaseScanRadius = 80
        BaseEnergy = 60
        EnergyRegenRate = 2
        BaseAttack = 50
        AttackRange = 120
        Abilities = @('HeavyAttack', 'MissileSalvo', 'Overcharge')
        Cost = 3000
        Size = 'Large'
        Noise = 'VeryHigh'
        DetectionDifficulty = 10
    }
    'Stealth' = @{
        Description = 'Covert infiltration drone'
        Category = 'Recon'
        BaseHP = 25
        BaseArmor = 0
        BaseSpeed = 70
        BaseScanRadius = 150
        BaseEnergy = 80
        EnergyRegenRate = 6
        BaseAttack = 10
        AttackRange = 50
        Abilities = @('Cloak', 'SilentScan', 'Sabotage')
        Cost = 2500
        Size = 'Tiny'
        Noise = 'Silent'
        DetectionDifficulty = 90
    }
    'Carrier' = @{
        Description = 'Transport and deployment drone'
        Category = 'Support'
        BaseHP = 80
        BaseArmor = 15
        BaseSpeed = 35
        BaseScanRadius = 60
        BaseEnergy = 150
        EnergyRegenRate = 4
        BaseAttack = 0
        AttackRange = 0
        Abilities = @('Deploy', 'Resupply', 'Evac')
        CarryCapacity = 4
        Cost = 2200
        Size = 'Large'
        Noise = 'High'
        DetectionDifficulty = 20
    }
    'Turret' = @{
        Description = 'Stationary defense turret'
        Category = 'Defense'
        BaseHP = 100
        BaseArmor = 40
        BaseSpeed = 0
        BaseScanRadius = 180
        BaseEnergy = 200
        EnergyRegenRate = 10
        BaseAttack = 35
        AttackRange = 200
        Abilities = @('AutoTarget', 'OverwatchMode', 'SelfDestruct')
        Cost = 1800
        Size = 'Medium'
        Noise = 'Medium'
        DetectionDifficulty = 5
        Stationary = $true
    }
}

# Drone upgrade tiers
$script:DroneUpgrades = @{
    'ArmorPlating' = @{
        Description = 'Reinforced armor'
        Effect = @{ Armor = 10 }
        Cost = 300
        MaxLevel = 3
    }
    'ExtendedBattery' = @{
        Description = 'Increased energy capacity'
        Effect = @{ Energy = 30; EnergyRegen = 2 }
        Cost = 250
        MaxLevel = 3
    }
    'SpeedBoost' = @{
        Description = 'Improved propulsion'
        Effect = @{ Speed = 15 }
        Cost = 350
        MaxLevel = 3
    }
    'EnhancedSensors' = @{
        Description = 'Extended scan range'
        Effect = @{ ScanRadius = 50 }
        Cost = 400
        MaxLevel = 3
    }
    'WeaponUpgrade' = @{
        Description = 'Improved weapons'
        Effect = @{ Attack = 10; AttackRange = 20 }
        Cost = 500
        MaxLevel = 3
    }
    'StealthCoating' = @{
        Description = 'Reduces detection'
        Effect = @{ DetectionDifficulty = 15 }
        Cost = 600
        MaxLevel = 2
    }
    'SelfRepair' = @{
        Description = 'Automated repair system'
        Effect = @{ HPRegen = 3 }
        Cost = 800
        MaxLevel = 2
    }
}

# Drone statuses
$script:DroneStatuses = @{
    'Idle' = @{ Description = 'Awaiting orders'; EnergyDrain = 1 }
    'Deployed' = @{ Description = 'Active in field'; EnergyDrain = 3 }
    'OnMission' = @{ Description = 'Executing mission'; EnergyDrain = 5 }
    'Combat' = @{ Description = 'In combat'; EnergyDrain = 8 }
    'Scanning' = @{ Description = 'Scanning area'; EnergyDrain = 6 }
    'Returning' = @{ Description = 'Returning to base'; EnergyDrain = 4 }
    'Damaged' = @{ Description = 'Damaged, reduced capability'; EnergyDrain = 2 }
    'Disabled' = @{ Description = 'Non-functional'; EnergyDrain = 0 }
    'Charging' = @{ Description = 'Recharging energy'; EnergyDrain = 0 }
    'Cloaked' = @{ Description = 'Stealth mode active'; EnergyDrain = 10 }
}

# Mission types
$script:MissionTypes = @{
    'Patrol' = @{
        Description = 'Automated area patrol'
        RequiredAbility = $null
        EnergyCost = 20
        Duration = 300
        XPReward = 25
    }
    'Reconnaissance' = @{
        Description = 'Gather intel on area'
        RequiredAbility = 'Scan'
        EnergyCost = 30
        Duration = 180
        XPReward = 40
    }
    'Escort' = @{
        Description = 'Protect a target'
        RequiredAbility = $null
        EnergyCost = 25
        Duration = 240
        XPReward = 35
    }
    'Search' = @{
        Description = 'Search for targets'
        RequiredAbility = 'Scan'
        EnergyCost = 35
        Duration = 200
        XPReward = 30
    }
    'Strike' = @{
        Description = 'Attack designated target'
        RequiredAbility = 'Attack'
        EnergyCost = 50
        Duration = 120
        XPReward = 60
    }
    'Suppression' = @{
        Description = 'Provide covering fire'
        RequiredAbility = 'Suppression'
        EnergyCost = 40
        Duration = 150
        XPReward = 45
    }
    'Overwatch' = @{
        Description = 'Guard position'
        RequiredAbility = 'AutoTarget'
        EnergyCost = 15
        Duration = 0  # Indefinite
        XPReward = 20
    }
    'Sabotage' = @{
        Description = 'Disable enemy systems'
        RequiredAbility = 'Sabotage'
        EnergyCost = 45
        Duration = 180
        XPReward = 70
    }
    'MedEvac' = @{
        Description = 'Medical evacuation'
        RequiredAbility = 'Evac'
        EnergyCost = 35
        Duration = 120
        XPReward = 50
    }
}
#endregion

#region Initialization
function Initialize-DroneSystem {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{}
    )
    
    Write-Host "Initializing DroneSystem module..."
    
    $defaultConfig = @{
        MaxActiveDrones = 5
        MaxDroneInventory = 20
        BaseDetectionRange = 150
        EnergyRegenInterval = 60  # seconds
        DroneXPPerMission = 25
        DroneMaxLevel = 10
        OverrideBaseDifficulty = 50
        OverrideIntelBonus = 3
        FriendlyFireEnabled = $false
    }
    
    foreach ($key in $Configuration.Keys) {
        $defaultConfig[$key] = $Configuration[$key]
    }
    
    $script:DroneSystemState = @{
        Initialized = $true
        Drones = @{}
        PlayerDrones = @{}
        EnemyDrones = @{}
        DroneInventory = [System.Collections.ArrayList]::new()
        ActiveMissions = @{}
        MissionHistory = [System.Collections.ArrayList]::new()
        DroneCounter = 0
        TotalMissionsCompleted = 0
        TotalDronesDestroyed = 0
        TotalDronesOverridden = 0
        Configuration = $defaultConfig
    }
    
    return @{
        Initialized = $true
        ModuleName = 'DroneSystem'
        DroneTypes = $script:DroneTypes.Keys
        MissionTypes = $script:MissionTypes.Keys
        UpgradeTypes = $script:DroneUpgrades.Keys
        Configuration = $defaultConfig
    }
}
#endregion

#region Drone Creation & Management
function New-Drone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [string]$Name = '',
        
        [Parameter(Mandatory)]
        [ValidateSet('Scout', 'Combat', 'Support', 'EMP', 'Heavy', 'Stealth', 'Carrier', 'Turret')]
        [string]$Type,
        
        [string]$OwnerId = 'player',
        
        [hashtable]$Position = @{ X = 0; Y = 0; Z = 0 },
        
        [int]$Level = 1,
        
        [string[]]$Upgrades = @(),
        
        [bool]$IsEnemy = $false
    )
    
    if (-not $script:DroneSystemState.Initialized) {
        throw "DroneSystem not initialized."
    }
    
    if ($script:DroneSystemState.Drones.ContainsKey($DroneId)) {
        throw "Drone '$DroneId' already exists."
    }
    
    $typeInfo = $script:DroneTypes[$Type]
    $actualName = if ($Name) { $Name } else { "$Type-$($script:DroneSystemState.DroneCounter + 1)" }
    
    # Calculate stats with level bonuses
    $levelBonus = ($Level - 1) * 0.1  # 10% per level
    
    $drone = @{
        DroneId = $DroneId
        Name = $actualName
        Type = $Type
        TypeInfo = $typeInfo
        OwnerId = $OwnerId
        IsEnemy = $IsEnemy
        
        # Current stats
        HP = [int]($typeInfo.BaseHP * (1 + $levelBonus))
        MaxHP = [int]($typeInfo.BaseHP * (1 + $levelBonus))
        Armor = $typeInfo.BaseArmor
        Speed = $typeInfo.BaseSpeed
        ScanRadius = $typeInfo.BaseScanRadius
        Energy = $typeInfo.BaseEnergy
        MaxEnergy = $typeInfo.BaseEnergy
        EnergyRegenRate = $typeInfo.EnergyRegenRate
        Attack = $typeInfo.BaseAttack
        AttackRange = $typeInfo.AttackRange
        DetectionDifficulty = $typeInfo.DetectionDifficulty
        HPRegen = 0
        
        # State
        Position = $Position
        Status = 'Idle'
        CurrentMission = $null
        Level = $Level
        XP = 0
        XPToNextLevel = 100 * $Level
        Upgrades = @{}
        Abilities = @($typeInfo.Abilities)
        
        # Combat state
        Target = $null
        LastAttackTime = $null
        DamageDealt = 0
        DamageTaken = 0
        KillCount = 0
        
        # Metadata
        DeployedAt = $null
        TotalFlightTime = 0
        MissionsCompleted = 0
        CreatedAt = Get-Date
    }
    
    # Apply upgrades
    foreach ($upgrade in $Upgrades) {
        if ($script:DroneUpgrades.ContainsKey($upgrade)) {
            $upgradeInfo = $script:DroneUpgrades[$upgrade]
            foreach ($effect in $upgradeInfo.Effect.Keys) {
                switch ($effect) {
                    'Armor' { $drone.Armor += $upgradeInfo.Effect[$effect] }
                    'Energy' { 
                        $drone.Energy += $upgradeInfo.Effect[$effect]
                        $drone.MaxEnergy += $upgradeInfo.Effect[$effect]
                    }
                    'EnergyRegen' { $drone.EnergyRegenRate += $upgradeInfo.Effect[$effect] }
                    'Speed' { $drone.Speed += $upgradeInfo.Effect[$effect] }
                    'ScanRadius' { $drone.ScanRadius += $upgradeInfo.Effect[$effect] }
                    'Attack' { $drone.Attack += $upgradeInfo.Effect[$effect] }
                    'AttackRange' { $drone.AttackRange += $upgradeInfo.Effect[$effect] }
                    'DetectionDifficulty' { $drone.DetectionDifficulty += $upgradeInfo.Effect[$effect] }
                    'HPRegen' { $drone.HPRegen += $upgradeInfo.Effect[$effect] }
                }
            }
            $drone.Upgrades[$upgrade] = 1
        }
    }
    
    $script:DroneSystemState.Drones[$DroneId] = $drone
    $script:DroneSystemState.DroneCounter++
    
    if ($IsEnemy) {
        $script:DroneSystemState.EnemyDrones[$DroneId] = $drone
    }
    else {
        $script:DroneSystemState.PlayerDrones[$DroneId] = $drone
    }
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'DroneCreated' -Data @{
            DroneId = $DroneId
            Type = $Type
            OwnerId = $OwnerId
            IsEnemy = $IsEnemy
        }
    }
    
    return $drone
}

function Get-Drone {
    [CmdletBinding()]
    param(
        [string]$DroneId,
        [string]$Type,
        [string]$OwnerId,
        [string]$Status,
        [switch]$PlayerOnly,
        [switch]$EnemyOnly,
        [switch]$ActiveOnly,
        [switch]$DeployedOnly
    )
    
    if (-not $script:DroneSystemState.Initialized) {
        throw "DroneSystem not initialized."
    }
    
    if ($DroneId) {
        return $script:DroneSystemState.Drones[$DroneId]
    }
    
    $drones = if ($PlayerOnly) {
        $script:DroneSystemState.PlayerDrones.Values
    }
    elseif ($EnemyOnly) {
        $script:DroneSystemState.EnemyDrones.Values
    }
    else {
        $script:DroneSystemState.Drones.Values
    }
    
    if ($Type) {
        $drones = $drones | Where-Object { $_.Type -eq $Type }
    }
    
    if ($OwnerId) {
        $drones = $drones | Where-Object { $_.OwnerId -eq $OwnerId }
    }
    
    if ($Status) {
        $drones = $drones | Where-Object { $_.Status -eq $Status }
    }
    
    if ($ActiveOnly) {
        $drones = $drones | Where-Object { $_.Status -notin @('Disabled', 'Charging') }
    }
    
    if ($DeployedOnly) {
        $drones = $drones | Where-Object { $_.Status -in @('Deployed', 'OnMission', 'Combat', 'Scanning', 'Cloaked') }
    }
    
    return ,@($drones)
}

function Remove-Drone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [switch]$Destroyed
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        return $false
    }
    
    $script:DroneSystemState.Drones.Remove($DroneId)
    $script:DroneSystemState.PlayerDrones.Remove($DroneId)
    $script:DroneSystemState.EnemyDrones.Remove($DroneId)
    
    if ($Destroyed) {
        $script:DroneSystemState.TotalDronesDestroyed++
        
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'DroneDestroyed' -Data @{
                DroneId = $DroneId
                Type = $drone.Type
                OwnerId = $drone.OwnerId
            }
        }
    }
    
    return $true
}

function Set-DroneStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [Parameter(Mandatory)]
        [ValidateSet('Idle', 'Deployed', 'OnMission', 'Combat', 'Scanning', 'Returning', 
                     'Damaged', 'Disabled', 'Charging', 'Cloaked')]
        [string]$Status
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        return $false
    }
    
    $oldStatus = $drone.Status
    $drone.Status = $Status
    
    if ($Status -eq 'Deployed' -and -not $drone.DeployedAt) {
        $drone.DeployedAt = Get-Date
    }
    
    if ($Status -in @('Idle', 'Disabled', 'Charging') -and $drone.DeployedAt) {
        $flightTime = ((Get-Date) - $drone.DeployedAt).TotalMinutes
        $drone.TotalFlightTime += $flightTime
        $drone.DeployedAt = $null
    }
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'DroneStatusChanged' -Data @{
            DroneId = $DroneId
            OldStatus = $oldStatus
            NewStatus = $Status
        }
    }
    
    return $true
}
#endregion

#region Drone Inventory
function Add-DroneToInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Scout', 'Combat', 'Support', 'EMP', 'Heavy', 'Stealth', 'Carrier', 'Turret')]
        [string]$Type,
        
        [int]$Quantity = 1
    )
    
    if (-not $script:DroneSystemState.Initialized) {
        throw "DroneSystem not initialized."
    }
    
    $config = $script:DroneSystemState.Configuration
    $currentCount = $script:DroneSystemState.DroneInventory.Count
    
    if ($currentCount + $Quantity -gt $config.MaxDroneInventory) {
        return @{
            Success = $false
            Reason = "Inventory full. Max: $($config.MaxDroneInventory), Current: $currentCount"
        }
    }
    
    $typeInfo = $script:DroneTypes[$Type]
    $added = [System.Collections.ArrayList]::new()
    
    for ($i = 0; $i -lt $Quantity; $i++) {
        $invItem = @{
            InventoryId = [guid]::NewGuid().ToString()
            Type = $Type
            Level = 1
            Upgrades = @()
            AcquiredAt = Get-Date
        }
        [void]$script:DroneSystemState.DroneInventory.Add($invItem)
        [void]$added.Add($invItem.InventoryId)
    }
    
    return @{
        Success = $true
        Type = $Type
        Quantity = $Quantity
        InventoryIds = @($added)
        TotalInInventory = $script:DroneSystemState.DroneInventory.Count
    }
}

function Get-DroneInventory {
    [CmdletBinding()]
    param(
        [string]$Type
    )
    
    $inventory = $script:DroneSystemState.DroneInventory
    
    if ($Type) {
        $inventory = @($inventory | Where-Object { $_.Type -eq $Type })
    }
    
    return ,@($inventory)
}

function Remove-DroneFromInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$InventoryId
    )
    
    $item = $script:DroneSystemState.DroneInventory | Where-Object { $_.InventoryId -eq $InventoryId }
    if (-not $item) {
        return $false
    }
    
    [void]$script:DroneSystemState.DroneInventory.Remove($item)
    return $true
}
#endregion

#region Drone Deployment
function Deploy-Drone {
    [CmdletBinding()]
    param(
        [string]$InventoryId,
        
        [string]$Type,
        
        [hashtable]$Position = @{ X = 0; Y = 0; Z = 50 },
        
        [string]$Name = ''
    )
    
    if (-not $script:DroneSystemState.Initialized) {
        throw "DroneSystem not initialized."
    }
    
    $config = $script:DroneSystemState.Configuration
    $activeDrones = @(Get-Drone -PlayerOnly -ActiveOnly)
    
    if ($activeDrones.Count -ge $config.MaxActiveDrones) {
        return @{
            Success = $false
            Reason = "Maximum active drones reached ($($config.MaxActiveDrones))"
        }
    }
    
    # Get from inventory
    $invItem = $null
    if ($InventoryId) {
        $invItem = $script:DroneSystemState.DroneInventory | Where-Object { $_.InventoryId -eq $InventoryId }
    }
    elseif ($Type) {
        $invItem = $script:DroneSystemState.DroneInventory | Where-Object { $_.Type -eq $Type } | Select-Object -First 1
    }
    
    if (-not $invItem) {
        return @{
            Success = $false
            Reason = "No drone available in inventory"
        }
    }
    
    # Remove from inventory
    Remove-DroneFromInventory -InventoryId $invItem.InventoryId | Out-Null
    
    # Create active drone
    $droneId = "drone_" + [guid]::NewGuid().ToString().Substring(0, 8)
    $drone = New-Drone -DroneId $droneId -Name $Name -Type $invItem.Type `
        -Position $Position -Level $invItem.Level -Upgrades $invItem.Upgrades
    
    # Set as deployed
    Set-DroneStatus -DroneId $droneId -Status 'Deployed' | Out-Null
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'DroneDeployed' -Data @{
            DroneId = $droneId
            Type = $invItem.Type
            Position = $Position
        }
    }
    
    return @{
        Success = $true
        DroneId = $droneId
        Drone = $drone
    }
}

function Recall-Drone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        return @{
            Success = $false
            Reason = "Drone not found"
        }
    }
    
    if ($drone.IsEnemy) {
        return @{
            Success = $false
            Reason = "Cannot recall enemy drone"
        }
    }
    
    # Cancel any active mission
    if ($drone.CurrentMission) {
        Cancel-DroneMission -DroneId $DroneId | Out-Null
    }
    
    # Return to inventory
    $invItem = @{
        InventoryId = [guid]::NewGuid().ToString()
        Type = $drone.Type
        Level = $drone.Level
        Upgrades = @($drone.Upgrades.Keys)
        AcquiredAt = Get-Date
    }
    [void]$script:DroneSystemState.DroneInventory.Add($invItem)
    
    # Record flight time
    $flightTime = 0
    if ($drone.DeployedAt) {
        $flightTime = ((Get-Date) - $drone.DeployedAt).TotalMinutes
    }
    
    # Remove active drone
    Remove-Drone -DroneId $DroneId | Out-Null
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'DroneRecalled' -Data @{
            DroneId = $DroneId
            Type = $drone.Type
            FlightTime = $flightTime
            RemainingEnergy = $drone.Energy
        }
    }
    
    return @{
        Success = $true
        DroneId = $DroneId
        FlightTime = $flightTime
        RemainingEnergy = $drone.Energy
        HP = $drone.HP
        MissionsCompleted = $drone.MissionsCompleted
    }
}
#endregion

#region Drone Actions
function Invoke-DroneAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [Parameter(Mandatory)]
        [ValidateSet('Scan', 'Attack', 'Heal', 'Shield', 'EMPBlast', 'Cloak', 'Decloak',
                     'MarkTarget', 'Suppression', 'MissileSalvo', 'Deploy', 'Evac')]
        [string]$Action,
        
        [string]$TargetId = '',
        
        [hashtable]$TargetPosition = $null,
        
        [hashtable]$Parameters = @{}
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        throw "Drone '$DroneId' not found."
    }
    
    if ($drone.Status -eq 'Disabled') {
        return @{
            Success = $false
            Reason = 'Drone is disabled'
            Action = $Action
        }
    }
    
    if ($drone.Abilities -notcontains $Action -and $Action -notin @('Decloak')) {
        return @{
            Success = $false
            Reason = "Drone does not have ability: $Action"
            Action = $Action
        }
    }
    
    $result = @{
        Success = $false
        Action = $Action
        DroneId = $DroneId
        Time = Get-Date
    }
    
    switch ($Action) {
        'Scan' {
            $energyCost = 15
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy. Need $energyCost, have $($drone.Energy)"
                return $result
            }
            
            $drone.Energy -= $energyCost
            $drone.Status = 'Scanning'
            
            $result.Success = $true
            $result.ScanRadius = $drone.ScanRadius
            $result.Position = $drone.Position
            $result.EnergyRemaining = $drone.Energy
            $result.Message = "Scan complete. Radius: $($drone.ScanRadius)"
        }
        
        'Attack' {
            $energyCost = 10
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            if ($drone.Attack -le 0) {
                $result.Reason = "Drone has no attack capability"
                return $result
            }
            
            $drone.Energy -= $energyCost
            $drone.Status = 'Combat'
            $drone.LastAttackTime = Get-Date
            
            # Calculate damage
            $baseDamage = $drone.Attack
            $critChance = 15
            $isCrit = (Get-Random -Minimum 1 -Maximum 101) -le $critChance
            $damage = if ($isCrit) { [int]($baseDamage * 1.5) } else { $baseDamage }
            
            $drone.DamageDealt += $damage
            
            $result.Success = $true
            $result.Damage = $damage
            $result.IsCritical = $isCrit
            $result.TargetId = $TargetId
            $result.EnergyRemaining = $drone.Energy
        }
        
        'Heal' {
            $energyCost = 20
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $healAmount = $drone.TypeInfo.HealAmount ?? 15
            $drone.Energy -= $energyCost
            
            $result.Success = $true
            $result.HealAmount = $healAmount
            $result.TargetId = $TargetId
            $result.EnergyRemaining = $drone.Energy
        }
        
        'Shield' {
            $energyCost = 25
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $shieldAmount = $drone.TypeInfo.ShieldAmount ?? 20
            $drone.Energy -= $energyCost
            
            $result.Success = $true
            $result.ShieldAmount = $shieldAmount
            $result.TargetId = $TargetId
            $result.Duration = 30  # seconds
            $result.EnergyRemaining = $drone.Energy
        }
        
        'EMPBlast' {
            $energyCost = 40
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $empRadius = $drone.TypeInfo.EMPRadius ?? 100
            $empDamage = $drone.TypeInfo.EMPDamage ?? 50
            $drone.Energy -= $energyCost
            
            $result.Success = $true
            $result.EMPRadius = $empRadius
            $result.EMPDamage = $empDamage
            $result.Position = $drone.Position
            $result.EnergyRemaining = $drone.Energy
            $result.Message = "EMP blast activated"
            
            if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
                Send-GameEvent -EventType 'EMPBlast' -Data @{
                    DroneId = $DroneId
                    Position = $drone.Position
                    Radius = $empRadius
                    Damage = $empDamage
                }
            }
        }
        
        'Cloak' {
            $energyCost = 30
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $drone.Energy -= $energyCost
            $drone.Status = 'Cloaked'
            
            $result.Success = $true
            $result.Duration = 60
            $result.EnergyRemaining = $drone.Energy
            $result.Message = "Stealth mode activated"
        }
        
        'Decloak' {
            if ($drone.Status -ne 'Cloaked') {
                $result.Reason = "Drone is not cloaked"
                return $result
            }
            
            $drone.Status = 'Deployed'
            
            $result.Success = $true
            $result.Message = "Stealth mode deactivated"
        }
        
        'MarkTarget' {
            $energyCost = 10
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $drone.Energy -= $energyCost
            
            $result.Success = $true
            $result.TargetId = $TargetId
            $result.Duration = 120
            $result.AccuracyBonus = 20
            $result.EnergyRemaining = $drone.Energy
        }
        
        'Suppression' {
            $energyCost = 25
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $drone.Energy -= $energyCost
            $drone.Status = 'Combat'
            
            $result.Success = $true
            $result.SuppressedArea = $TargetPosition ?? $drone.Position
            $result.Radius = 50
            $result.Duration = 30
            $result.EnergyRemaining = $drone.Energy
        }
        
        'MissileSalvo' {
            $energyCost = 50
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $drone.Energy -= $energyCost
            $baseDamage = $drone.Attack * 2
            $missileCount = 3
            
            $result.Success = $true
            $result.Damage = $baseDamage
            $result.MissileCount = $missileCount
            $result.TargetPosition = $TargetPosition
            $result.EnergyRemaining = $drone.Energy
            
            $drone.DamageDealt += $baseDamage
        }
        
        'Deploy' {
            $energyCost = 20
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $drone.Energy -= $energyCost
            
            $result.Success = $true
            $result.DeployedItem = $Parameters.Item ?? 'Supplies'
            $result.Position = $drone.Position
            $result.EnergyRemaining = $drone.Energy
        }
        
        'Evac' {
            $energyCost = 35
            if ($drone.Energy -lt $energyCost) {
                $result.Reason = "Insufficient energy"
                return $result
            }
            
            $drone.Energy -= $energyCost
            
            $result.Success = $true
            $result.EvacTarget = $TargetId
            $result.EvacTo = $Parameters.Destination ?? 'Base'
            $result.EnergyRemaining = $drone.Energy
        }
    }
    
    if ($result.Success -and (Get-Command Send-GameEvent -ErrorAction SilentlyContinue)) {
        Send-GameEvent -EventType 'DroneActionExecuted' -Data @{
            DroneId = $DroneId
            Action = $Action
            Result = $result
        }
    }
    
    return $result
}

function Move-Drone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [Parameter(Mandatory)]
        [hashtable]$TargetPosition
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        throw "Drone '$DroneId' not found."
    }
    
    if ($drone.Status -eq 'Disabled') {
        return @{
            Success = $false
            Reason = 'Drone is disabled'
        }
    }
    
    if ($drone.TypeInfo.Stationary) {
        return @{
            Success = $false
            Reason = 'This drone type cannot move'
        }
    }
    
    # Calculate distance
    $dx = $TargetPosition.X - $drone.Position.X
    $dy = $TargetPosition.Y - $drone.Position.Y
    $dz = ($TargetPosition.Z ?? 0) - ($drone.Position.Z ?? 0)
    $distance = [Math]::Sqrt($dx * $dx + $dy * $dy + $dz * $dz)
    
    # Energy cost based on distance
    $energyCost = [Math]::Ceiling($distance / 100 * 5)
    
    if ($drone.Energy -lt $energyCost) {
        return @{
            Success = $false
            Reason = "Insufficient energy. Need $energyCost, have $($drone.Energy)"
        }
    }
    
    $oldPosition = $drone.Position.Clone()
    $drone.Position = $TargetPosition
    $drone.Energy -= $energyCost
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'DroneMoved' -Data @{
            DroneId = $DroneId
            From = $oldPosition
            To = $TargetPosition
            Distance = $distance
        }
    }
    
    return @{
        Success = $true
        DroneId = $DroneId
        From = $oldPosition
        To = $TargetPosition
        Distance = [Math]::Round($distance, 2)
        EnergyCost = $energyCost
        EnergyRemaining = $drone.Energy
    }
}
#endregion

#region Drone Missions
function Start-DroneMission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [Parameter(Mandatory)]
        [ValidateSet('Patrol', 'Reconnaissance', 'Escort', 'Search', 'Strike', 
                     'Suppression', 'Overwatch', 'Sabotage', 'MedEvac')]
        [string]$MissionType,
        
        [hashtable]$MissionParameters = @{}
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        throw "Drone '$DroneId' not found."
    }
    
    if ($drone.CurrentMission) {
        return @{
            Success = $false
            Reason = 'Drone already on a mission'
        }
    }
    
    $missionInfo = $script:MissionTypes[$MissionType]
    
    # Check ability requirement
    if ($missionInfo.RequiredAbility -and $drone.Abilities -notcontains $missionInfo.RequiredAbility) {
        return @{
            Success = $false
            Reason = "Drone lacks required ability: $($missionInfo.RequiredAbility)"
        }
    }
    
    # Check energy
    if ($drone.Energy -lt $missionInfo.EnergyCost) {
        return @{
            Success = $false
            Reason = "Insufficient energy. Need $($missionInfo.EnergyCost), have $($drone.Energy)"
        }
    }
    
    $drone.Energy -= $missionInfo.EnergyCost
    
    $mission = @{
        MissionId = [guid]::NewGuid().ToString()
        DroneId = $DroneId
        MissionType = $MissionType
        Parameters = $MissionParameters
        StartTime = Get-Date
        Duration = $missionInfo.Duration
        Status = 'Active'
        XPReward = $missionInfo.XPReward
    }
    
    $drone.CurrentMission = $mission.MissionId
    $drone.Status = 'OnMission'
    
    $script:DroneSystemState.ActiveMissions[$mission.MissionId] = $mission
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'DroneMissionStarted' -Data @{
            DroneId = $DroneId
            MissionId = $mission.MissionId
            MissionType = $MissionType
        }
    }
    
    return @{
        Success = $true
        MissionId = $mission.MissionId
        DroneId = $DroneId
        MissionType = $MissionType
        Duration = $missionInfo.Duration
        XPReward = $missionInfo.XPReward
    }
}

function Get-DroneMission {
    [CmdletBinding()]
    param(
        [string]$MissionId,
        [string]$DroneId,
        [switch]$ActiveOnly
    )
    
    if ($MissionId) {
        return $script:DroneSystemState.ActiveMissions[$MissionId]
    }
    
    if ($DroneId) {
        $drone = $script:DroneSystemState.Drones[$DroneId]
        if ($drone -and $drone.CurrentMission) {
            return $script:DroneSystemState.ActiveMissions[$drone.CurrentMission]
        }
        return $null
    }
    
    $missions = $script:DroneSystemState.ActiveMissions.Values
    
    if ($ActiveOnly) {
        $missions = $missions | Where-Object { $_.Status -eq 'Active' }
    }
    
    return ,@($missions)
}

function Complete-DroneMission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MissionId,
        
        [bool]$Success = $true,
        
        [hashtable]$Results = @{}
    )
    
    $mission = $script:DroneSystemState.ActiveMissions[$MissionId]
    if (-not $mission) {
        return @{
            Success = $false
            Reason = 'Mission not found'
        }
    }
    
    $drone = $script:DroneSystemState.Drones[$mission.DroneId]
    
    $mission.Status = if ($Success) { 'Completed' } else { 'Failed' }
    $mission.EndTime = Get-Date
    $mission.Results = $Results
    
    # Award XP on success
    $xpAwarded = 0
    if ($Success -and $drone) {
        $xpAwarded = $mission.XPReward
        $drone.XP += $xpAwarded
        $drone.MissionsCompleted++
        
        # Check for level up
        if ($drone.XP -ge $drone.XPToNextLevel) {
            $drone.Level++
            $drone.XP -= $drone.XPToNextLevel
            $drone.XPToNextLevel = 100 * $drone.Level
            
            # Apply level bonus
            $drone.MaxHP = [int]($drone.TypeInfo.BaseHP * (1 + ($drone.Level - 1) * 0.1))
            $drone.HP = [Math]::Min($drone.HP + 10, $drone.MaxHP)
            
            if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
                Send-GameEvent -EventType 'DroneLevelUp' -Data @{
                    DroneId = $drone.DroneId
                    NewLevel = $drone.Level
                }
            }
        }
        
        $script:DroneSystemState.TotalMissionsCompleted++
    }
    
    if ($drone) {
        $drone.CurrentMission = $null
        $drone.Status = 'Deployed'
    }
    
    # Move to history
    [void]$script:DroneSystemState.MissionHistory.Add($mission)
    $script:DroneSystemState.ActiveMissions.Remove($MissionId)
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'DroneMissionCompleted' -Data @{
            MissionId = $MissionId
            DroneId = $mission.DroneId
            Success = $Success
            XPAwarded = $xpAwarded
        }
    }
    
    return @{
        Success = $true
        MissionId = $MissionId
        MissionSuccess = $Success
        XPAwarded = $xpAwarded
        Results = $Results
    }
}

function Cancel-DroneMission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone -or -not $drone.CurrentMission) {
        return @{
            Success = $false
            Reason = 'No active mission'
        }
    }
    
    $missionId = $drone.CurrentMission
    $mission = $script:DroneSystemState.ActiveMissions[$missionId]
    
    $mission.Status = 'Cancelled'
    $mission.EndTime = Get-Date
    
    $drone.CurrentMission = $null
    $drone.Status = 'Deployed'
    
    [void]$script:DroneSystemState.MissionHistory.Add($mission)
    $script:DroneSystemState.ActiveMissions.Remove($missionId)
    
    return @{
        Success = $true
        MissionId = $missionId
        DroneId = $DroneId
    }
}
#endregion

#region Drone Combat
function Invoke-DroneDamage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [Parameter(Mandatory)]
        [int]$Damage,
        
        [ValidateSet('Kinetic', 'Energy', 'EMP', 'Explosive')]
        [string]$DamageType = 'Kinetic',
        
        [string]$SourceId = ''
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        throw "Drone '$DroneId' not found."
    }
    
    # Apply armor reduction (except EMP)
    $actualDamage = $Damage
    if ($DamageType -ne 'EMP') {
        $actualDamage = [Math]::Max(1, $Damage - $drone.Armor)
    }
    
    # EMP does bonus damage to drones
    if ($DamageType -eq 'EMP') {
        $actualDamage = [int]($actualDamage * 1.5)
    }
    
    $drone.HP -= $actualDamage
    $drone.DamageTaken += $actualDamage
    
    $result = @{
        DroneId = $DroneId
        DamageType = $DamageType
        RawDamage = $Damage
        ActualDamage = $actualDamage
        ArmorMitigation = $Damage - $actualDamage
        RemainingHP = $drone.HP
        SourceId = $SourceId
    }
    
    if ($drone.HP -le 0) {
        $drone.HP = 0
        $drone.Status = 'Disabled'
        $result.Destroyed = $true
        
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'DroneDisabled' -Data @{
                DroneId = $DroneId
                DestroyedBy = $SourceId
            }
        }
    }
    elseif ($drone.HP -lt ($drone.MaxHP * 0.3)) {
        $drone.Status = 'Damaged'
        $result.Destroyed = $false
        $result.Critical = $true
    }
    else {
        $result.Destroyed = $false
        $result.Critical = $false
    }
    
    return $result
}

function Repair-Drone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [int]$Amount = 0,
        
        [switch]$FullRepair
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        throw "Drone '$DroneId' not found."
    }
    
    $oldHP = $drone.HP
    
    if ($FullRepair) {
        $drone.HP = $drone.MaxHP
        if ($drone.Status -eq 'Disabled') {
            $drone.Status = 'Idle'
        }
        elseif ($drone.Status -eq 'Damaged') {
            $drone.Status = 'Deployed'
        }
    }
    else {
        $repairAmount = if ($Amount -gt 0) { $Amount } else { 20 }
        $drone.HP = [Math]::Min($drone.MaxHP, $drone.HP + $repairAmount)
        
        if ($drone.HP -ge ($drone.MaxHP * 0.3) -and $drone.Status -eq 'Damaged') {
            $drone.Status = 'Deployed'
        }
    }
    
    return @{
        DroneId = $DroneId
        OldHP = $oldHP
        NewHP = $drone.HP
        MaxHP = $drone.MaxHP
        Repaired = $drone.HP - $oldHP
        Status = $drone.Status
    }
}

function Recharge-Drone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [int]$Amount = 0,
        
        [switch]$FullRecharge
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        throw "Drone '$DroneId' not found."
    }
    
    $oldEnergy = $drone.Energy
    
    if ($FullRecharge) {
        $drone.Energy = $drone.MaxEnergy
    }
    else {
        $rechargeAmount = if ($Amount -gt 0) { $Amount } else { $drone.EnergyRegenRate * 10 }
        $drone.Energy = [Math]::Min($drone.MaxEnergy, $drone.Energy + $rechargeAmount)
    }
    
    return @{
        DroneId = $DroneId
        OldEnergy = $oldEnergy
        NewEnergy = $drone.Energy
        MaxEnergy = $drone.MaxEnergy
        Recharged = $drone.Energy - $oldEnergy
    }
}
#endregion

#region Drone Override (Hacking)
function Invoke-DroneOverride {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [string]$HackerId = 'player',
        
        [int]$Intelligence = 10,
        
        [int]$HackingSkill = 0
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        throw "Drone '$DroneId' not found."
    }
    
    if (-not $drone.IsEnemy) {
        return @{
            Success = $false
            Reason = 'Cannot override friendly drone'
        }
    }
    
    if ($drone.Status -eq 'Disabled') {
        return @{
            Success = $false
            Reason = 'Drone is disabled'
        }
    }
    
    $config = $script:DroneSystemState.Configuration
    
    # Calculate override chance
    $baseChance = 100 - $config.OverrideBaseDifficulty
    $intBonus = ($Intelligence - 10) * $config.OverrideIntelBonus
    $skillBonus = $HackingSkill * 10
    $dronePenalty = $drone.Level * 5
    $typePenalty = switch ($drone.Type) {
        'Scout' { 0 }
        'Stealth' { 10 }
        'Combat' { 15 }
        'Support' { 5 }
        'EMP' { 20 }
        'Heavy' { 25 }
        'Carrier' { 10 }
        'Turret' { 30 }
        default { 10 }
    }
    
    $totalChance = [Math]::Max(5, [Math]::Min(95, $baseChance + $intBonus + $skillBonus - $dronePenalty - $typePenalty))
    
    $roll = Get-Random -Minimum 1 -Maximum 101
    $success = $roll -le $totalChance
    
    $result = @{
        DroneId = $DroneId
        Roll = $roll
        RequiredRoll = $totalChance
        Success = $success
    }
    
    if ($success) {
        # Transfer ownership
        $script:DroneSystemState.EnemyDrones.Remove($DroneId)
        $drone.IsEnemy = $false
        $drone.OwnerId = $HackerId
        $script:DroneSystemState.PlayerDrones[$DroneId] = $drone
        $script:DroneSystemState.TotalDronesOverridden++
        
        $result.Message = "Successfully overrode $($drone.Name)"
        $result.NewOwnerId = $HackerId
        
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'DroneOverridden' -Data @{
                DroneId = $DroneId
                NewOwner = $HackerId
                DroneType = $drone.Type
            }
        }
    }
    else {
        $result.Message = "Failed to override drone"
        
        # Alert the drone
        $drone.Status = 'Combat'
        $drone.Target = $HackerId
    }
    
    return $result
}
#endregion

#region Drone Upgrades
function Get-DroneUpgrade {
    [CmdletBinding()]
    param(
        [string]$UpgradeName
    )
    
    if ($UpgradeName) {
        $upgrade = $script:DroneUpgrades[$UpgradeName]
        if ($upgrade) {
            return @{
                Name = $UpgradeName
                Description = $upgrade.Description
                Effect = $upgrade.Effect
                Cost = $upgrade.Cost
                MaxLevel = $upgrade.MaxLevel
            }
        }
        return $null
    }
    
    $upgrades = [System.Collections.ArrayList]::new()
    foreach ($name in $script:DroneUpgrades.Keys) {
        $upgrade = $script:DroneUpgrades[$name]
        [void]$upgrades.Add(@{
            Name = $name
            Description = $upgrade.Description
            Effect = $upgrade.Effect
            Cost = $upgrade.Cost
            MaxLevel = $upgrade.MaxLevel
        })
    }
    
    return ,@($upgrades)
}

function Install-DroneUpgrade {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DroneId,
        
        [Parameter(Mandatory)]
        [string]$UpgradeName
    )
    
    $drone = $script:DroneSystemState.Drones[$DroneId]
    if (-not $drone) {
        throw "Drone '$DroneId' not found."
    }
    
    if (-not $script:DroneUpgrades.ContainsKey($UpgradeName)) {
        throw "Unknown upgrade: $UpgradeName"
    }
    
    $upgrade = $script:DroneUpgrades[$UpgradeName]
    $currentLevel = $drone.Upgrades[$UpgradeName] ?? 0
    
    if ($currentLevel -ge $upgrade.MaxLevel) {
        return @{
            Success = $false
            Reason = "Upgrade already at max level ($($upgrade.MaxLevel))"
        }
    }
    
    # Apply upgrade effects
    foreach ($effect in $upgrade.Effect.Keys) {
        switch ($effect) {
            'Armor' { $drone.Armor += $upgrade.Effect[$effect] }
            'Energy' { 
                $drone.Energy += $upgrade.Effect[$effect]
                $drone.MaxEnergy += $upgrade.Effect[$effect]
            }
            'EnergyRegen' { $drone.EnergyRegenRate += $upgrade.Effect[$effect] }
            'Speed' { $drone.Speed += $upgrade.Effect[$effect] }
            'ScanRadius' { $drone.ScanRadius += $upgrade.Effect[$effect] }
            'Attack' { $drone.Attack += $upgrade.Effect[$effect] }
            'AttackRange' { $drone.AttackRange += $upgrade.Effect[$effect] }
            'DetectionDifficulty' { $drone.DetectionDifficulty += $upgrade.Effect[$effect] }
            'HPRegen' { $drone.HPRegen += $upgrade.Effect[$effect] }
        }
    }
    
    $drone.Upgrades[$UpgradeName] = $currentLevel + 1
    
    return @{
        Success = $true
        DroneId = $DroneId
        Upgrade = $UpgradeName
        NewLevel = $currentLevel + 1
        MaxLevel = $upgrade.MaxLevel
        Cost = $upgrade.Cost
    }
}
#endregion

#region State Management
function Get-DroneSystemState {
    [CmdletBinding()]
    param()
    
    return @{
        Initialized = $script:DroneSystemState.Initialized
        TotalDrones = $script:DroneSystemState.Drones.Count
        PlayerDrones = $script:DroneSystemState.PlayerDrones.Count
        EnemyDrones = $script:DroneSystemState.EnemyDrones.Count
        InventoryCount = $script:DroneSystemState.DroneInventory.Count
        ActiveMissions = $script:DroneSystemState.ActiveMissions.Count
        TotalMissionsCompleted = $script:DroneSystemState.TotalMissionsCompleted
        TotalDronesDestroyed = $script:DroneSystemState.TotalDronesDestroyed
        TotalDronesOverridden = $script:DroneSystemState.TotalDronesOverridden
        Configuration = $script:DroneSystemState.Configuration
    }
}

function Get-DroneStatistics {
    [CmdletBinding()]
    param(
        [string]$DroneId
    )
    
    if ($DroneId) {
        $drone = $script:DroneSystemState.Drones[$DroneId]
        if (-not $drone) {
            return $null
        }
        
        return @{
            DroneId = $drone.DroneId
            Name = $drone.Name
            Type = $drone.Type
            Level = $drone.Level
            XP = $drone.XP
            XPToNextLevel = $drone.XPToNextLevel
            TotalFlightTime = $drone.TotalFlightTime
            MissionsCompleted = $drone.MissionsCompleted
            DamageDealt = $drone.DamageDealt
            DamageTaken = $drone.DamageTaken
            KillCount = $drone.KillCount
            Upgrades = $drone.Upgrades
        }
    }
    
    # Overall statistics
    $playerDrones = $script:DroneSystemState.PlayerDrones.Values
    
    return @{
        TotalDamageDealt = ($playerDrones | Measure-Object -Property DamageDealt -Sum).Sum
        TotalDamageTaken = ($playerDrones | Measure-Object -Property DamageTaken -Sum).Sum
        TotalKills = ($playerDrones | Measure-Object -Property KillCount -Sum).Sum
        TotalMissions = ($playerDrones | Measure-Object -Property MissionsCompleted -Sum).Sum
        TotalFlightTime = ($playerDrones | Measure-Object -Property TotalFlightTime -Sum).Sum
        HighestLevel = ($playerDrones | Measure-Object -Property Level -Maximum).Maximum
    }
}

function Export-DroneData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    $exportData = @{
        Drones = $script:DroneSystemState.Drones
        PlayerDrones = $script:DroneSystemState.PlayerDrones
        EnemyDrones = $script:DroneSystemState.EnemyDrones
        DroneInventory = @($script:DroneSystemState.DroneInventory)
        ActiveMissions = $script:DroneSystemState.ActiveMissions
        MissionHistory = @($script:DroneSystemState.MissionHistory)
        DroneCounter = $script:DroneSystemState.DroneCounter
        TotalMissionsCompleted = $script:DroneSystemState.TotalMissionsCompleted
        TotalDronesDestroyed = $script:DroneSystemState.TotalDronesDestroyed
        TotalDronesOverridden = $script:DroneSystemState.TotalDronesOverridden
        Configuration = $script:DroneSystemState.Configuration
        ExportedAt = Get-Date
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath
    
    return @{
        Success = $true
        FilePath = $FilePath
        DroneCount = $script:DroneSystemState.Drones.Count
    }
}

function Import-DroneData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $importData = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    
    Initialize-DroneSystem -Configuration @{} | Out-Null
    
    # Convert JSON objects back to hashtables
    $script:DroneSystemState.Drones = @{}
    foreach ($prop in $importData.Drones.PSObject.Properties) {
        $drone = @{}
        foreach ($p in $prop.Value.PSObject.Properties) {
            $drone[$p.Name] = $p.Value
        }
        $script:DroneSystemState.Drones[$prop.Name] = $drone
    }
    
    $script:DroneSystemState.PlayerDrones = @{}
    foreach ($prop in $importData.PlayerDrones.PSObject.Properties) {
        $script:DroneSystemState.PlayerDrones[$prop.Name] = $script:DroneSystemState.Drones[$prop.Name]
    }
    
    $script:DroneSystemState.EnemyDrones = @{}
    foreach ($prop in $importData.EnemyDrones.PSObject.Properties) {
        $script:DroneSystemState.EnemyDrones[$prop.Name] = $script:DroneSystemState.Drones[$prop.Name]
    }
    
    $script:DroneSystemState.DroneCounter = $importData.DroneCounter
    $script:DroneSystemState.TotalMissionsCompleted = $importData.TotalMissionsCompleted
    $script:DroneSystemState.TotalDronesDestroyed = $importData.TotalDronesDestroyed
    $script:DroneSystemState.TotalDronesOverridden = $importData.TotalDronesOverridden
    
    return @{
        Success = $true
        DroneCount = $script:DroneSystemState.Drones.Count
        InventoryCount = $script:DroneSystemState.DroneInventory.Count
    }
}
#endregion

#region Event Processing
function Process-DroneEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TimeAdvanced', 'CombatStarted', 'CombatEnded', 'EMPDetonated', 'AreaEntered')]
        [string]$EventType,
        
        [hashtable]$EventData = @{}
    )
    
    $results = [System.Collections.ArrayList]::new()
    
    switch ($EventType) {
        'TimeAdvanced' {
            # Energy regeneration
            $minutesPassed = $EventData.MinutesPassed ?? 1
            foreach ($drone in $script:DroneSystemState.Drones.Values) {
                if ($drone.Status -notin @('Disabled', 'Combat', 'OnMission')) {
                    $regenAmount = [int]($drone.EnergyRegenRate * ($minutesPassed / 60))
                    if ($regenAmount -gt 0) {
                        $drone.Energy = [Math]::Min($drone.MaxEnergy, $drone.Energy + $regenAmount)
                    }
                }
                
                # HP regeneration if has self-repair
                if ($drone.HPRegen -gt 0 -and $drone.HP -lt $drone.MaxHP) {
                    $hpRegen = [int]($drone.HPRegen * ($minutesPassed / 60))
                    if ($hpRegen -gt 0) {
                        $drone.HP = [Math]::Min($drone.MaxHP, $drone.HP + $hpRegen)
                    }
                }
            }
            
            # Check mission completions
            $now = Get-Date
            $completedMissions = @($script:DroneSystemState.ActiveMissions.Values | Where-Object {
                $_.Duration -gt 0 -and ($now - $_.StartTime).TotalSeconds -ge $_.Duration
            })
            
            foreach ($mission in $completedMissions) {
                $completeResult = Complete-DroneMission -MissionId $mission.MissionId -Success $true
                [void]$results.Add(@{ Type = 'MissionAutoCompleted'; MissionId = $mission.MissionId })
            }
        }
        
        'CombatStarted' {
            # Set deployed drones to combat mode
            foreach ($drone in $script:DroneSystemState.PlayerDrones.Values) {
                if ($drone.Status -eq 'Deployed') {
                    $drone.Status = 'Combat'
                    [void]$results.Add(@{ Type = 'DroneCombatReady'; DroneId = $drone.DroneId })
                }
            }
        }
        
        'CombatEnded' {
            # Return to deployed status
            foreach ($drone in $script:DroneSystemState.PlayerDrones.Values) {
                if ($drone.Status -eq 'Combat') {
                    $drone.Status = 'Deployed'
                    $drone.Target = $null
                }
            }
        }
        
        'EMPDetonated' {
            $position = $EventData.Position
            $radius = $EventData.Radius ?? 100
            $damage = $EventData.Damage ?? 50
            
            foreach ($drone in $script:DroneSystemState.Drones.Values) {
                $dx = $drone.Position.X - $position.X
                $dy = $drone.Position.Y - $position.Y
                $distance = [Math]::Sqrt($dx * $dx + $dy * $dy)
                
                if ($distance -le $radius) {
                    $damageResult = Invoke-DroneDamage -DroneId $drone.DroneId -Damage $damage -DamageType 'EMP'
                    [void]$results.Add(@{ 
                        Type = 'DroneEMPDamage'
                        DroneId = $drone.DroneId
                        Damage = $damageResult.ActualDamage
                    })
                }
            }
        }
        
        'AreaEntered' {
            # Check for enemy drones in area
            $position = $EventData.Position
            $detectionRange = $script:DroneSystemState.Configuration.BaseDetectionRange
            
            foreach ($drone in $script:DroneSystemState.EnemyDrones.Values) {
                if ($drone.Status -eq 'Disabled') { continue }
                
                $dx = $drone.Position.X - $position.X
                $dy = $drone.Position.Y - $position.Y
                $distance = [Math]::Sqrt($dx * $dx + $dy * $dy)
                
                if ($distance -le $detectionRange) {
                    [void]$results.Add(@{
                        Type = 'EnemyDroneDetected'
                        DroneId = $drone.DroneId
                        DroneType = $drone.Type
                        Distance = [Math]::Round($distance, 2)
                    })
                }
            }
        }
    }
    
    return ,@($results)
}
#endregion

# Export all functions
Export-ModuleMember -Function @(
    # Initialization
    'Initialize-DroneSystem'
    
    # Drone Management
    'New-Drone'
    'Get-Drone'
    'Remove-Drone'
    'Set-DroneStatus'
    
    # Inventory
    'Add-DroneToInventory'
    'Get-DroneInventory'
    'Remove-DroneFromInventory'
    
    # Deployment
    'Deploy-Drone'
    'Recall-Drone'
    
    # Actions
    'Invoke-DroneAction'
    'Move-Drone'
    
    # Missions
    'Start-DroneMission'
    'Get-DroneMission'
    'Complete-DroneMission'
    'Cancel-DroneMission'
    
    # Combat
    'Invoke-DroneDamage'
    'Repair-Drone'
    'Recharge-Drone'
    
    # Override
    'Invoke-DroneOverride'
    
    # Upgrades
    'Get-DroneUpgrade'
    'Install-DroneUpgrade'
    
    # State Management
    'Get-DroneSystemState'
    'Get-DroneStatistics'
    'Export-DroneData'
    'Import-DroneData'
    
    # Event Processing
    'Process-DroneEvent'
)
