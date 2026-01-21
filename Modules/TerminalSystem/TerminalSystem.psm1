# TerminalSystem Module
# Handles hacking, terminals, network intrusion, data theft, and security systems

#region Module State
$script:TerminalSystemState = @{
    Initialized = $false
    Terminals = @{}
    Networks = @{}
    ActiveHacks = @{}
    HackHistory = @()
    SecurityAlerts = @()
    Configuration = @{}
}

# Terminal Types with security profiles
$script:TerminalTypes = @{
    'PublicTerminal' = @{
        Description = 'Public access terminal'
        BaseSecurityLevel = 1
        DefaultICE = @()
        DataTypes = @('PublicInfo', 'Maps', 'News')
        HackDifficulty = 'VeryEasy'
        RewardRange = @(10, 50)
    }
    'CorporateTerminal' = @{
        Description = 'Corporate office terminal'
        BaseSecurityLevel = 3
        DefaultICE = @('Firewall', 'Tracer')
        DataTypes = @('EmployeeData', 'Schedules', 'Credentials', 'Credits')
        HackDifficulty = 'Medium'
        RewardRange = @(100, 500)
    }
    'SecurityTerminal' = @{
        Description = 'Security system access point'
        BaseSecurityLevel = 4
        DefaultICE = @('Firewall', 'Tracer', 'Killer')
        DataTypes = @('CameraFeeds', 'AlarmCodes', 'PatrolRoutes', 'DoorControls')
        HackDifficulty = 'Hard'
        RewardRange = @(200, 800)
    }
    'DataServer' = @{
        Description = 'Corporate data server'
        BaseSecurityLevel = 5
        DefaultICE = @('Firewall', 'Tracer', 'Killer', 'BlackICE')
        DataTypes = @('SensitiveData', 'Financials', 'Research', 'Blackmail')
        HackDifficulty = 'VeryHard'
        RewardRange = @(500, 5000)
    }
    'BankTerminal' = @{
        Description = 'Financial institution terminal'
        BaseSecurityLevel = 5
        DefaultICE = @('Firewall', 'Tracer', 'Killer', 'Encryption')
        DataTypes = @('AccountData', 'Transfers', 'Credits')
        HackDifficulty = 'VeryHard'
        RewardRange = @(1000, 10000)
    }
    'MilitaryTerminal' = @{
        Description = 'Military/PMC terminal'
        BaseSecurityLevel = 6
        DefaultICE = @('Firewall', 'Tracer', 'Killer', 'BlackICE', 'Scorcher')
        DataTypes = @('WeaponSpecs', 'TroopMovements', 'Codes', 'AIControls')
        HackDifficulty = 'Extreme'
        RewardRange = @(2000, 20000)
    }
    'AICore' = @{
        Description = 'AI system core access'
        BaseSecurityLevel = 7
        DefaultICE = @('Firewall', 'Tracer', 'Killer', 'BlackICE', 'Scorcher', 'Sentinel')
        DataTypes = @('AIDirectives', 'SystemControl', 'MasterCodes')
        HackDifficulty = 'Legendary'
        RewardRange = @(5000, 50000)
    }
}

# ICE (Intrusion Countermeasures Electronics) types
$script:ICETypes = @{
    'Firewall' = @{
        Description = 'Basic intrusion barrier'
        Strength = 1
        Effect = 'BlocksProgress'
        BypassDifficulty = 10
        DamageOnFail = 0
    }
    'Tracer' = @{
        Description = 'Tracks intruder location'
        Strength = 2
        Effect = 'AlertsOnDetect'
        BypassDifficulty = 15
        DamageOnFail = 0
        TraceTime = 30  # seconds
    }
    'Killer' = @{
        Description = 'Attack program'
        Strength = 3
        Effect = 'DamagesHacker'
        BypassDifficulty = 20
        DamageOnFail = 10
    }
    'BlackICE' = @{
        Description = 'Lethal countermeasure'
        Strength = 4
        Effect = 'SevereDamage'
        BypassDifficulty = 25
        DamageOnFail = 25
    }
    'Encryption' = @{
        Description = 'Data encryption layer'
        Strength = 3
        Effect = 'HidesData'
        BypassDifficulty = 20
        DamageOnFail = 0
        DecryptTime = 60
    }
    'Scorcher' = @{
        Description = 'Burns out hacker hardware'
        Strength = 5
        Effect = 'EquipmentDamage'
        BypassDifficulty = 30
        DamageOnFail = 15
        EquipmentDamage = 20
    }
    'Sentinel' = @{
        Description = 'AI-controlled hunter program'
        Strength = 6
        Effect = 'PursuesHacker'
        BypassDifficulty = 35
        DamageOnFail = 30
        PursuitDuration = 300
    }
}

# Hacking difficulty modifiers
$script:DifficultyLevels = @{
    'VeryEasy' = @{ BaseChance = 90; XPMultiplier = 0.5 }
    'Easy' = @{ BaseChance = 75; XPMultiplier = 0.75 }
    'Medium' = @{ BaseChance = 60; XPMultiplier = 1.0 }
    'Hard' = @{ BaseChance = 45; XPMultiplier = 1.5 }
    'VeryHard' = @{ BaseChance = 30; XPMultiplier = 2.0 }
    'Extreme' = @{ BaseChance = 15; XPMultiplier = 3.0 }
    'Legendary' = @{ BaseChance = 5; XPMultiplier = 5.0 }
}

# Data types that can be stolen
$script:DataTypes = @{
    'PublicInfo' = @{ Value = 0; Legal = $true; Description = 'Public information' }
    'Maps' = @{ Value = 10; Legal = $true; Description = 'Location data' }
    'News' = @{ Value = 5; Legal = $true; Description = 'News feeds' }
    'EmployeeData' = @{ Value = 50; Legal = $false; Description = 'Employee records' }
    'Schedules' = @{ Value = 30; Legal = $false; Description = 'Schedule information' }
    'Credentials' = @{ Value = 100; Legal = $false; Description = 'Access credentials' }
    'Credits' = @{ Value = 0; Legal = $false; Description = 'Direct credit transfer' }
    'CameraFeeds' = @{ Value = 40; Legal = $false; Description = 'Security camera access' }
    'AlarmCodes' = @{ Value = 150; Legal = $false; Description = 'Alarm system codes' }
    'PatrolRoutes' = @{ Value = 80; Legal = $false; Description = 'Security patrol data' }
    'DoorControls' = @{ Value = 60; Legal = $false; Description = 'Door access controls' }
    'SensitiveData' = @{ Value = 500; Legal = $false; Description = 'Sensitive corporate data' }
    'Financials' = @{ Value = 300; Legal = $false; Description = 'Financial records' }
    'Research' = @{ Value = 1000; Legal = $false; Description = 'Research data' }
    'Blackmail' = @{ Value = 2000; Legal = $false; Description = 'Blackmail material' }
    'AccountData' = @{ Value = 200; Legal = $false; Description = 'Bank account data' }
    'Transfers' = @{ Value = 0; Legal = $false; Description = 'Credit transfer capability' }
    'WeaponSpecs' = @{ Value = 1500; Legal = $false; Description = 'Weapons specifications' }
    'TroopMovements' = @{ Value = 800; Legal = $false; Description = 'Military movements' }
    'Codes' = @{ Value = 500; Legal = $false; Description = 'Military codes' }
    'AIControls' = @{ Value = 5000; Legal = $false; Description = 'AI control access' }
    'AIDirectives' = @{ Value = 3000; Legal = $false; Description = 'AI programming' }
    'SystemControl' = @{ Value = 10000; Legal = $false; Description = 'System-wide control' }
    'MasterCodes' = @{ Value = 20000; Legal = $false; Description = 'Master access codes' }
}

# Hacking programs the player can use
$script:HackingPrograms = @{
    'BasicDecrypt' = @{
        Description = 'Basic decryption routine'
        Effect = 'BypassFirewall'
        Strength = 1
        Cost = 100
        UseTime = 5
    }
    'Probe' = @{
        Description = 'Scans terminal for vulnerabilities'
        Effect = 'RevealICE'
        Strength = 1
        Cost = 50
        UseTime = 3
    }
    'Mask' = @{
        Description = 'Hides your trace signature'
        Effect = 'ReduceDetection'
        Strength = 2
        Cost = 200
        UseTime = 2
        Duration = 30
    }
    'Sledgehammer' = @{
        Description = 'Brute force attack'
        Effect = 'ForceEntry'
        Strength = 3
        Cost = 500
        UseTime = 10
    }
    'Ghost' = @{
        Description = 'Advanced stealth protocol'
        Effect = 'Invisible'
        Strength = 4
        Cost = 1000
        UseTime = 5
        Duration = 60
    }
    'ICEBreaker' = @{
        Description = 'Neutralizes ICE programs'
        Effect = 'DestroyICE'
        Strength = 5
        Cost = 2000
        UseTime = 8
    }
    'DataVault' = @{
        Description = 'Secure data extraction'
        Effect = 'SafeExtract'
        Strength = 3
        Cost = 800
        UseTime = 15
    }
    'Worm' = @{
        Description = 'Self-replicating backdoor'
        Effect = 'CreateBackdoor'
        Strength = 4
        Cost = 1500
        UseTime = 20
    }
    'Neural Spike' = @{
        Description = 'Attacks enemy netrunners'
        Effect = 'DamageNetrunner'
        Strength = 5
        Cost = 3000
        UseTime = 3
        Damage = 30
    }
}
#endregion

#region Initialization
function Initialize-TerminalSystem {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{}
    )
    
    Write-Host "Initializing TerminalSystem module..."
    
    $defaultConfig = @{
        BaseHackSuccessRate = 30
        IntelligenceBonus = 3      # Per INT point
        SkillBonus = 15            # Per skill rank
        DetectionBaseChance = 20
        AlertDuration = 300        # 5 minutes
        MaxActiveHacks = 3
        HackCooldown = 60          # seconds
        TraceDecayRate = 10        # per minute
    }
    
    foreach ($key in $Configuration.Keys) {
        $defaultConfig[$key] = $Configuration[$key]
    }
    
    $script:TerminalSystemState = @{
        Initialized = $true
        Terminals = @{}
        Networks = @{}
        ActiveHacks = @{}
        HackHistory = [System.Collections.ArrayList]::new()
        SecurityAlerts = [System.Collections.ArrayList]::new()
        PlayerPrograms = @{}
        PlayerTraceLevel = 0
        Configuration = $defaultConfig
    }
    
    return @{
        Initialized = $true
        ModuleName = 'TerminalSystem'
        TerminalTypes = $script:TerminalTypes.Keys
        ICETypes = $script:ICETypes.Keys
        HackingPrograms = $script:HackingPrograms.Keys
        Configuration = $defaultConfig
    }
}
#endregion

#region Terminal Management
function New-Terminal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateSet('PublicTerminal', 'CorporateTerminal', 'SecurityTerminal', 
                     'DataServer', 'BankTerminal', 'MilitaryTerminal', 'AICore')]
        [string]$Type,
        
        [string]$LocationId = '',
        
        [string]$OwnerId = '',
        
        [string]$FactionId = '',
        
        [int]$SecurityLevel = -1,
        
        [string[]]$ICE = @(),
        
        [string[]]$AvailableData = @(),
        
        [hashtable]$Contents = @{},
        
        [bool]$IsActive = $true,
        
        [bool]$RequiresPhysicalAccess = $false,
        
        [string]$Description = ''
    )
    
    if (-not $script:TerminalSystemState.Initialized) {
        throw "TerminalSystem not initialized."
    }
    
    if ($script:TerminalSystemState.Terminals.ContainsKey($TerminalId)) {
        throw "Terminal '$TerminalId' already exists."
    }
    
    $typeInfo = $script:TerminalTypes[$Type]
    
    # Use type defaults if not specified
    $actualSecurityLevel = if ($SecurityLevel -ge 0) { $SecurityLevel } else { $typeInfo.BaseSecurityLevel }
    $actualICE = if ($ICE.Count -gt 0) { @($ICE) } else { @($typeInfo.DefaultICE) }
    $actualData = if ($AvailableData.Count -gt 0) { @($AvailableData) } else { @($typeInfo.DataTypes) }
    
    $terminal = @{
        TerminalId = $TerminalId
        Name = $Name
        Type = $Type
        TypeInfo = $typeInfo
        LocationId = $LocationId
        OwnerId = $OwnerId
        FactionId = $FactionId
        SecurityLevel = $actualSecurityLevel
        ICE = @($actualICE)
        ActiveICE = @($actualICE)  # ICE that hasn't been bypassed
        AvailableData = @($actualData)
        Contents = $Contents
        IsActive = $IsActive
        RequiresPhysicalAccess = $RequiresPhysicalAccess
        Description = $Description
        Compromised = $false
        Backdoor = $false
        LastAccess = $null
        AccessLog = [System.Collections.ArrayList]::new()
        CreatedAt = Get-Date
    }
    
    $script:TerminalSystemState.Terminals[$TerminalId] = $terminal
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'TerminalCreated' -Data @{
            TerminalId = $TerminalId
            Type = $Type
            LocationId = $LocationId
        }
    }
    
    return $terminal
}

function Get-Terminal {
    [CmdletBinding()]
    param(
        [string]$TerminalId,
        [string]$LocationId,
        [string]$Type,
        [string]$FactionId,
        [switch]$ActiveOnly,
        [switch]$CompromisedOnly
    )
    
    if (-not $script:TerminalSystemState.Initialized) {
        throw "TerminalSystem not initialized."
    }
    
    if ($TerminalId) {
        return $script:TerminalSystemState.Terminals[$TerminalId]
    }
    
    $terminals = $script:TerminalSystemState.Terminals.Values
    
    if ($LocationId) {
        $terminals = $terminals | Where-Object { $_.LocationId -eq $LocationId }
    }
    
    if ($Type) {
        $terminals = $terminals | Where-Object { $_.Type -eq $Type }
    }
    
    if ($FactionId) {
        $terminals = $terminals | Where-Object { $_.FactionId -eq $FactionId }
    }
    
    if ($ActiveOnly) {
        $terminals = $terminals | Where-Object { $_.IsActive }
    }
    
    if ($CompromisedOnly) {
        $terminals = $terminals | Where-Object { $_.Compromised }
    }
    
    return ,@($terminals)
}

function Set-TerminalActive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId,
        
        [Parameter(Mandatory)]
        [bool]$Active
    )
    
    $terminal = $script:TerminalSystemState.Terminals[$TerminalId]
    if (-not $terminal) {
        return $false
    }
    
    $terminal.IsActive = $Active
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'TerminalStatusChanged' -Data @{
            TerminalId = $TerminalId
            IsActive = $Active
        }
    }
    
    return $true
}

function Remove-Terminal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId
    )
    
    if (-not $script:TerminalSystemState.Terminals.ContainsKey($TerminalId)) {
        return $false
    }
    
    $script:TerminalSystemState.Terminals.Remove($TerminalId)
    
    return $true
}
#endregion

#region Network Management
function New-Network {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NetworkId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$OwnerId = '',
        
        [string]$FactionId = '',
        
        [int]$SecurityLevel = 3,
        
        [string[]]$ConnectedTerminals = @(),
        
        [string]$Description = ''
    )
    
    if (-not $script:TerminalSystemState.Initialized) {
        throw "TerminalSystem not initialized."
    }
    
    if ($script:TerminalSystemState.Networks.ContainsKey($NetworkId)) {
        throw "Network '$NetworkId' already exists."
    }
    
    $network = @{
        NetworkId = $NetworkId
        Name = $Name
        OwnerId = $OwnerId
        FactionId = $FactionId
        SecurityLevel = $SecurityLevel
        ConnectedTerminals = $ConnectedTerminals
        Description = $Description
        IsOnline = $true
        Compromised = $false
        AlertLevel = 0
        CreatedAt = Get-Date
    }
    
    $script:TerminalSystemState.Networks[$NetworkId] = $network
    
    return $network
}

function Get-Network {
    [CmdletBinding()]
    param(
        [string]$NetworkId,
        [string]$FactionId
    )
    
    if ($NetworkId) {
        return $script:TerminalSystemState.Networks[$NetworkId]
    }
    
    $networks = $script:TerminalSystemState.Networks.Values
    
    if ($FactionId) {
        $networks = $networks | Where-Object { $_.FactionId -eq $FactionId }
    }
    
    return ,@($networks)
}

function Add-TerminalToNetwork {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NetworkId,
        
        [Parameter(Mandatory)]
        [string]$TerminalId
    )
    
    $network = $script:TerminalSystemState.Networks[$NetworkId]
    if (-not $network) {
        throw "Network '$NetworkId' not found."
    }
    
    if (-not $script:TerminalSystemState.Terminals.ContainsKey($TerminalId)) {
        throw "Terminal '$TerminalId' not found."
    }
    
    if ($network.ConnectedTerminals -notcontains $TerminalId) {
        $network.ConnectedTerminals += $TerminalId
    }
    
    return $true
}

function Remove-TerminalFromNetwork {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NetworkId,
        
        [Parameter(Mandatory)]
        [string]$TerminalId
    )
    
    $network = $script:TerminalSystemState.Networks[$NetworkId]
    if (-not $network) {
        return $false
    }
    
    $network.ConnectedTerminals = @($network.ConnectedTerminals | Where-Object { $_ -ne $TerminalId })
    
    return $true
}
#endregion

#region Hacking System
function Get-HackChance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId,
        
        [int]$Intelligence = 10,
        
        [int]$HackingSkill = 0,
        
        [string[]]$ActivePrograms = @()
    )
    
    $terminal = $script:TerminalSystemState.Terminals[$TerminalId]
    if (-not $terminal) {
        throw "Terminal '$TerminalId' not found."
    }
    
    $config = $script:TerminalSystemState.Configuration
    $difficulty = $script:DifficultyLevels[$terminal.TypeInfo.HackDifficulty]
    
    # Base chance from difficulty
    $baseChance = $difficulty.BaseChance
    
    # Intelligence bonus
    $intBonus = ($Intelligence - 10) * $config.IntelligenceBonus
    
    # Skill bonus
    $skillBonus = $HackingSkill * $config.SkillBonus
    
    # Security level penalty
    $securityPenalty = $terminal.SecurityLevel * 5
    
    # Active ICE penalty
    $icePenalty = $terminal.ActiveICE.Count * 3
    
    # Program bonuses
    $programBonus = 0
    foreach ($prog in $ActivePrograms) {
        if ($script:HackingPrograms.ContainsKey($prog)) {
            $programBonus += $script:HackingPrograms[$prog].Strength * 5
        }
    }
    
    # Backdoor bonus
    $backdoorBonus = if ($terminal.Backdoor) { 30 } else { 0 }
    
    $totalChance = $baseChance + $intBonus + $skillBonus + $programBonus + $backdoorBonus - $securityPenalty - $icePenalty
    
    # Clamp between 5% and 95%
    $totalChance = [Math]::Max(5, [Math]::Min(95, $totalChance))
    
    return @{
        TotalChance = $totalChance
        BaseChance = $baseChance
        IntelligenceBonus = $intBonus
        SkillBonus = $skillBonus
        ProgramBonus = $programBonus
        BackdoorBonus = $backdoorBonus
        SecurityPenalty = $securityPenalty
        ICEPenalty = $icePenalty
        Difficulty = $terminal.TypeInfo.HackDifficulty
        ActiveICE = $terminal.ActiveICE
    }
}

function Start-Hack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId,
        
        [string]$HackerId = 'player',
        
        [int]$Intelligence = 10,
        
        [int]$HackingSkill = 0,
        
        [string[]]$Programs = @()
    )
    
    if (-not $script:TerminalSystemState.Initialized) {
        throw "TerminalSystem not initialized."
    }
    
    $terminal = $script:TerminalSystemState.Terminals[$TerminalId]
    if (-not $terminal) {
        throw "Terminal '$TerminalId' not found."
    }
    
    if (-not $terminal.IsActive) {
        return @{
            Success = $false
            Reason = 'Terminal is offline'
            TerminalId = $TerminalId
        }
    }
    
    # Check for existing active hack
    if ($script:TerminalSystemState.ActiveHacks.ContainsKey($TerminalId)) {
        return @{
            Success = $false
            Reason = 'Hack already in progress on this terminal'
            TerminalId = $TerminalId
        }
    }
    
    # Calculate success chance
    $hackChance = Get-HackChance -TerminalId $TerminalId -Intelligence $Intelligence `
        -HackingSkill $HackingSkill -ActivePrograms $Programs
    
    # Roll for success
    $roll = Get-Random -Minimum 1 -Maximum 101
    $success = $roll -le $hackChance.TotalChance
    
    $hackResult = @{
        HackId = [guid]::NewGuid().ToString()
        TerminalId = $TerminalId
        HackerId = $HackerId
        StartTime = Get-Date
        Success = $success
        Roll = $roll
        RequiredRoll = $hackChance.TotalChance
        Difficulty = $hackChance.Difficulty
        ICEEncountered = $terminal.ActiveICE
        Detected = $false
        DamageReceived = 0
        DataStolen = @()
        CreditsStolen = 0
        XPEarned = 0
    }
    
    if ($success) {
        # Successful hack
        $hackResult.AccessGranted = $true
        
        # Mark terminal as compromised
        $terminal.Compromised = $true
        $terminal.LastAccess = Get-Date
        
        # Log access
        [void]$terminal.AccessLog.Add(@{
            Time = Get-Date
            HackerId = $HackerId
            Type = 'Hack'
            Success = $true
        })
        
        # Calculate XP
        $xpMultiplier = $script:DifficultyLevels[$hackChance.Difficulty].XPMultiplier
        $hackResult.XPEarned = [int](50 * $xpMultiplier * $terminal.SecurityLevel)
        
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'HackSucceeded' -Data @{
                TerminalId = $TerminalId
                HackerId = $HackerId
                XP = $hackResult.XPEarned
            }
        }
    }
    else {
        # Failed hack
        $hackResult.AccessGranted = $false
        
        # Check for ICE damage
        foreach ($ice in $terminal.ActiveICE) {
            $iceInfo = $script:ICETypes[$ice]
            if ($iceInfo.DamageOnFail -gt 0) {
                $hackResult.DamageReceived += $iceInfo.DamageOnFail
            }
        }
        
        # Detection check
        $detectionRoll = Get-Random -Minimum 1 -Maximum 101
        $detectionChance = $script:TerminalSystemState.Configuration.DetectionBaseChance + ($terminal.SecurityLevel * 10)
        
        if ($detectionRoll -le $detectionChance) {
            $hackResult.Detected = $true
            
            # Create security alert
            $alert = @{
                AlertId = [guid]::NewGuid().ToString()
                TerminalId = $TerminalId
                LocationId = $terminal.LocationId
                FactionId = $terminal.FactionId
                SuspectId = $HackerId
                Time = Get-Date
                Type = 'HackAttempt'
                Severity = $terminal.SecurityLevel
            }
            [void]$script:TerminalSystemState.SecurityAlerts.Add($alert)
            
            if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
                Send-GameEvent -EventType 'SecurityAlert' -Data $alert
            }
        }
        
        # Log failed access
        [void]$terminal.AccessLog.Add(@{
            Time = Get-Date
            HackerId = $HackerId
            Type = 'HackAttempt'
            Success = $false
            Detected = $hackResult.Detected
        })
        
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'HackFailed' -Data @{
                TerminalId = $TerminalId
                HackerId = $HackerId
                Detected = $hackResult.Detected
                Damage = $hackResult.DamageReceived
            }
        }
    }
    
    # Record in history
    [void]$script:TerminalSystemState.HackHistory.Add($hackResult)
    
    return $hackResult
}

function Invoke-DataTheft {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId,
        
        [string]$HackerId = 'player',
        
        [string]$DataType = '',
        
        [switch]$All
    )
    
    $terminal = $script:TerminalSystemState.Terminals[$TerminalId]
    if (-not $terminal) {
        throw "Terminal '$TerminalId' not found."
    }
    
    if (-not $terminal.Compromised) {
        return @{
            Success = $false
            Reason = 'Terminal not compromised - hack first'
            TerminalId = $TerminalId
        }
    }
    
    $stolenData = [System.Collections.ArrayList]::new()
    $totalValue = 0
    $creditsStolen = 0
    
    $dataToSteal = if ($All) { 
        $terminal.AvailableData 
    } 
    elseif ($DataType) { 
        @($DataType) 
    } 
    else { 
        $terminal.AvailableData | Get-Random -Count 1 
    }
    
    foreach ($data in $dataToSteal) {
        if ($terminal.AvailableData -contains $data) {
            $dataInfo = $script:DataTypes[$data]
            
            if ($data -eq 'Credits' -or $data -eq 'Transfers') {
                # Steal credits directly
                $rewardRange = $terminal.TypeInfo.RewardRange
                $credits = Get-Random -Minimum $rewardRange[0] -Maximum ($rewardRange[1] + 1)
                $creditsStolen += $credits
            }
            else {
                [void]$stolenData.Add(@{
                    DataType = $data
                    Value = $dataInfo.Value
                    Legal = $dataInfo.Legal
                    Description = $dataInfo.Description
                    SourceTerminal = $TerminalId
                    StolenAt = Get-Date
                })
                $totalValue += $dataInfo.Value
            }
        }
    }
    
    $result = @{
        Success = $true
        TerminalId = $TerminalId
        HackerId = $HackerId
        StolenData = @($stolenData)
        TotalDataValue = $totalValue
        CreditsStolen = $creditsStolen
        StolenAt = Get-Date
    }
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'DataStolen' -Data @{
            TerminalId = $TerminalId
            HackerId = $HackerId
            DataCount = $stolenData.Count
            Value = $totalValue
            Credits = $creditsStolen
        }
    }
    
    return $result
}

function Invoke-TerminalAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId,
        
        [Parameter(Mandatory)]
        [ValidateSet('DisableAlarms', 'OpenDoors', 'DisableCameras', 'ControlTurrets', 
                     'TransferCredits', 'PlantBackdoor', 'WipeAccessLog', 'OverloadSystem')]
        [string]$Action,
        
        [string]$HackerId = 'player',
        
        [hashtable]$Parameters = @{}
    )
    
    $terminal = $script:TerminalSystemState.Terminals[$TerminalId]
    if (-not $terminal) {
        throw "Terminal '$TerminalId' not found."
    }
    
    if (-not $terminal.Compromised) {
        return @{
            Success = $false
            Reason = 'Terminal not compromised'
            Action = $Action
        }
    }
    
    $result = @{
        Success = $false
        Action = $Action
        TerminalId = $TerminalId
        HackerId = $HackerId
        Time = Get-Date
    }
    
    switch ($Action) {
        'DisableAlarms' {
            $result.Success = $true
            $result.Duration = 300  # 5 minutes
            $result.Message = 'Alarm systems disabled'
        }
        
        'OpenDoors' {
            $result.Success = $true
            $result.DoorsOpened = $terminal.Contents.Doors ?? @('all')
            $result.Message = 'Door locks disengaged'
        }
        
        'DisableCameras' {
            $result.Success = $true
            $result.Duration = 180  # 3 minutes
            $result.Message = 'Camera feeds looping'
        }
        
        'ControlTurrets' {
            if ($terminal.Type -in @('SecurityTerminal', 'MilitaryTerminal')) {
                $result.Success = $true
                $result.TurretsControlled = $terminal.Contents.Turrets ?? 0
                $result.Message = 'Turret control acquired'
            }
            else {
                $result.Reason = 'Terminal does not control turrets'
            }
        }
        
        'TransferCredits' {
            if ($terminal.Type -in @('BankTerminal', 'CorporateTerminal')) {
                $rewardRange = $terminal.TypeInfo.RewardRange
                $amount = Get-Random -Minimum $rewardRange[0] -Maximum ($rewardRange[1] + 1)
                $result.Success = $true
                $result.CreditsTransferred = $amount
                $result.Message = "₡$amount transferred"
            }
            else {
                $result.Reason = 'Terminal cannot transfer credits'
            }
        }
        
        'PlantBackdoor' {
            $terminal.Backdoor = $true
            $result.Success = $true
            $result.Message = 'Backdoor installed - future hacks will be easier'
        }
        
        'WipeAccessLog' {
            $terminal.AccessLog.Clear()
            $result.Success = $true
            $result.Message = 'Access logs wiped'
        }
        
        'OverloadSystem' {
            $terminal.IsActive = $false
            $result.Success = $true
            $result.Message = 'System overloaded - terminal offline'
        }
    }
    
    if ($result.Success) {
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'TerminalActionExecuted' -Data @{
                TerminalId = $TerminalId
                Action = $Action
                HackerId = $HackerId
            }
        }
    }
    
    return $result
}
#endregion

#region ICE Management
function Get-TerminalICE {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId,
        
        [switch]$ActiveOnly
    )
    
    $terminal = $script:TerminalSystemState.Terminals[$TerminalId]
    if (-not $terminal) {
        throw "Terminal '$TerminalId' not found."
    }
    
    $iceList = if ($ActiveOnly) { $terminal.ActiveICE } else { $terminal.ICE }
    
    $result = [System.Collections.ArrayList]::new()
    foreach ($ice in $iceList) {
        $iceInfo = $script:ICETypes[$ice]
        [void]$result.Add(@{
            Name = $ice
            Description = $iceInfo.Description
            Strength = $iceInfo.Strength
            Effect = $iceInfo.Effect
            BypassDifficulty = $iceInfo.BypassDifficulty
            DamageOnFail = $iceInfo.DamageOnFail
            IsActive = $terminal.ActiveICE -contains $ice
        })
    }
    
    return ,@($result)
}

function Invoke-ICEBypass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId,
        
        [Parameter(Mandatory)]
        [string]$ICEName,
        
        [string]$HackerId = 'player',
        
        [int]$Intelligence = 10,
        
        [int]$HackingSkill = 0,
        
        [string]$Program = ''
    )
    
    $terminal = $script:TerminalSystemState.Terminals[$TerminalId]
    if (-not $terminal) {
        throw "Terminal '$TerminalId' not found."
    }
    
    if ($terminal.ActiveICE -notcontains $ICEName) {
        return @{
            Success = $false
            Reason = 'ICE not active on this terminal'
            ICE = $ICEName
        }
    }
    
    $iceInfo = $script:ICETypes[$ICEName]
    $config = $script:TerminalSystemState.Configuration
    
    # Calculate bypass chance
    $baseChance = 50
    $intBonus = ($Intelligence - 10) * $config.IntelligenceBonus
    $skillBonus = $HackingSkill * 10
    $difficultyPenalty = $iceInfo.BypassDifficulty
    
    # Program bonus
    $programBonus = 0
    if ($Program -and $script:HackingPrograms.ContainsKey($Program)) {
        $prog = $script:HackingPrograms[$Program]
        if ($prog.Effect -in @('DestroyICE', 'BypassFirewall', 'ForceEntry')) {
            $programBonus = $prog.Strength * 10
        }
    }
    
    $totalChance = [Math]::Max(5, [Math]::Min(95, $baseChance + $intBonus + $skillBonus + $programBonus - $difficultyPenalty))
    
    # Roll
    $roll = Get-Random -Minimum 1 -Maximum 101
    $success = $roll -le $totalChance
    
    $result = @{
        Success = $success
        ICE = $ICEName
        TerminalId = $TerminalId
        Roll = $roll
        RequiredRoll = $totalChance
        DamageReceived = 0
    }
    
    if ($success) {
        # Remove ICE from active list
        $terminal.ActiveICE = @($terminal.ActiveICE | Where-Object { $_ -ne $ICEName })
        $result.Message = "Successfully bypassed $ICEName"
        
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'ICEBypassed' -Data @{
                TerminalId = $TerminalId
                ICE = $ICEName
                HackerId = $HackerId
            }
        }
    }
    else {
        # Apply ICE damage
        $result.DamageReceived = $iceInfo.DamageOnFail
        $result.Message = "Failed to bypass $ICEName"
        
        # Special ICE effects
        switch ($iceInfo.Effect) {
            'AlertsOnDetect' {
                $result.AlertTriggered = $true
            }
            'PursuesHacker' {
                $result.PursuitStarted = $true
            }
            'EquipmentDamage' {
                $result.EquipmentDamage = $iceInfo.EquipmentDamage
            }
        }
    }
    
    return $result
}

function Reset-TerminalICE {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerminalId
    )
    
    $terminal = $script:TerminalSystemState.Terminals[$TerminalId]
    if (-not $terminal) {
        return $false
    }
    
    $terminal.ActiveICE = @($terminal.ICE)
    $terminal.Compromised = $false
    $terminal.Backdoor = $false
    
    return $true
}
#endregion

#region Hacking Programs
function Get-HackingProgram {
    [CmdletBinding()]
    param(
        [string]$ProgramName,
        [switch]$Owned
    )
    
    if ($ProgramName) {
        $prog = $script:HackingPrograms[$ProgramName]
        if ($prog) {
            return @{
                Name = $ProgramName
                Description = $prog.Description
                Effect = $prog.Effect
                Strength = $prog.Strength
                Cost = $prog.Cost
                UseTime = $prog.UseTime
                Owned = $script:TerminalSystemState.PlayerPrograms.ContainsKey($ProgramName)
            }
        }
        return $null
    }
    
    $programs = [System.Collections.ArrayList]::new()
    foreach ($name in $script:HackingPrograms.Keys) {
        $prog = $script:HackingPrograms[$name]
        $isOwned = $script:TerminalSystemState.PlayerPrograms.ContainsKey($name)
        
        if (-not $Owned -or $isOwned) {
            [void]$programs.Add(@{
                Name = $name
                Description = $prog.Description
                Effect = $prog.Effect
                Strength = $prog.Strength
                Cost = $prog.Cost
                UseTime = $prog.UseTime
                Owned = $isOwned
            })
        }
    }
    
    return ,@($programs)
}

function Add-HackingProgram {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProgramName
    )
    
    if (-not $script:HackingPrograms.ContainsKey($ProgramName)) {
        throw "Unknown program: $ProgramName"
    }
    
    if ($script:TerminalSystemState.PlayerPrograms.ContainsKey($ProgramName)) {
        return @{
            Success = $false
            Reason = 'Program already owned'
            Program = $ProgramName
        }
    }
    
    $prog = $script:HackingPrograms[$ProgramName]
    $script:TerminalSystemState.PlayerPrograms[$ProgramName] = @{
        AcquiredAt = Get-Date
        Uses = -1  # Unlimited
    }
    
    return @{
        Success = $true
        Program = $ProgramName
        Description = $prog.Description
    }
}

function Remove-HackingProgram {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProgramName
    )
    
    if ($script:TerminalSystemState.PlayerPrograms.ContainsKey($ProgramName)) {
        $script:TerminalSystemState.PlayerPrograms.Remove($ProgramName)
        return $true
    }
    
    return $false
}
#endregion

#region Security Alerts
function Get-SecurityAlert {
    [CmdletBinding()]
    param(
        [string]$AlertId,
        [string]$FactionId,
        [string]$LocationId,
        [switch]$ActiveOnly
    )
    
    if ($AlertId) {
        return $script:TerminalSystemState.SecurityAlerts | Where-Object { $_.AlertId -eq $AlertId }
    }
    
    $alerts = $script:TerminalSystemState.SecurityAlerts
    
    if ($FactionId) {
        $alerts = $alerts | Where-Object { $_.FactionId -eq $FactionId }
    }
    
    if ($LocationId) {
        $alerts = $alerts | Where-Object { $_.LocationId -eq $LocationId }
    }
    
    if ($ActiveOnly) {
        $config = $script:TerminalSystemState.Configuration
        $cutoff = (Get-Date).AddSeconds(-$config.AlertDuration)
        $alerts = $alerts | Where-Object { $_.Time -gt $cutoff }
    }
    
    return ,@($alerts)
}

function Clear-SecurityAlert {
    [CmdletBinding()]
    param(
        [string]$AlertId,
        [string]$FactionId,
        [switch]$All
    )
    
    if ($All) {
        $script:TerminalSystemState.SecurityAlerts.Clear()
        return $true
    }
    
    if ($AlertId) {
        $toRemove = $script:TerminalSystemState.SecurityAlerts | Where-Object { $_.AlertId -eq $AlertId }
        foreach ($alert in $toRemove) {
            [void]$script:TerminalSystemState.SecurityAlerts.Remove($alert)
        }
        return $true
    }
    
    if ($FactionId) {
        $toRemove = @($script:TerminalSystemState.SecurityAlerts | Where-Object { $_.FactionId -eq $FactionId })
        foreach ($alert in $toRemove) {
            [void]$script:TerminalSystemState.SecurityAlerts.Remove($alert)
        }
        return $true
    }
    
    return $false
}

function Get-TraceLevel {
    [CmdletBinding()]
    param()
    
    return $script:TerminalSystemState.PlayerTraceLevel
}

function Add-TraceLevel {
    [CmdletBinding()]
    param(
        [int]$Amount = 10
    )
    
    $script:TerminalSystemState.PlayerTraceLevel += $Amount
    $script:TerminalSystemState.PlayerTraceLevel = [Math]::Min(100, $script:TerminalSystemState.PlayerTraceLevel)
    
    $level = $script:TerminalSystemState.PlayerTraceLevel
    
    if ($level -ge 100) {
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'TraceLevelMaxed' -Data @{
                TraceLevel = $level
            }
        }
    }
    
    return $level
}

function Reduce-TraceLevel {
    [CmdletBinding()]
    param(
        [int]$Amount = 10
    )
    
    $script:TerminalSystemState.PlayerTraceLevel -= $Amount
    $script:TerminalSystemState.PlayerTraceLevel = [Math]::Max(0, $script:TerminalSystemState.PlayerTraceLevel)
    
    return $script:TerminalSystemState.PlayerTraceLevel
}
#endregion

#region Hack History
function Get-HackHistory {
    [CmdletBinding()]
    param(
        [string]$TerminalId,
        [string]$HackerId,
        [switch]$SuccessOnly,
        [int]$Limit = 0
    )
    
    $history = $script:TerminalSystemState.HackHistory
    
    if ($TerminalId) {
        $history = $history | Where-Object { $_.TerminalId -eq $TerminalId }
    }
    
    if ($HackerId) {
        $history = $history | Where-Object { $_.HackerId -eq $HackerId }
    }
    
    if ($SuccessOnly) {
        $history = $history | Where-Object { $_.Success }
    }
    
    if ($Limit -gt 0) {
        $history = $history | Select-Object -Last $Limit
    }
    
    return ,@($history)
}

function Get-HackStatistics {
    [CmdletBinding()]
    param(
        [string]$HackerId = 'player'
    )
    
    $history = @($script:TerminalSystemState.HackHistory | Where-Object { $_.HackerId -eq $HackerId })
    
    if ($history.Count -eq 0) {
        return @{
            TotalAttempts = 0
            SuccessfulHacks = 0
            FailedHacks = 0
            SuccessRate = 0
            TotalXP = 0
            TotalDamage = 0
            TimesDetected = 0
        }
    }
    
    $successful = @($history | Where-Object { $_.Success })
    $failed = @($history | Where-Object { -not $_.Success })
    $detected = @($history | Where-Object { $_.Detected })
    
    return @{
        TotalAttempts = $history.Count
        SuccessfulHacks = $successful.Count
        FailedHacks = $failed.Count
        SuccessRate = [Math]::Round(($successful.Count / $history.Count) * 100, 1)
        TotalXP = ($successful | Measure-Object -Property XPEarned -Sum).Sum
        TotalDamage = ($history | Measure-Object -Property DamageReceived -Sum).Sum
        TimesDetected = $detected.Count
    }
}
#endregion

#region State Management
function Get-TerminalSystemState {
    [CmdletBinding()]
    param()
    
    return @{
        Initialized = $script:TerminalSystemState.Initialized
        TerminalCount = $script:TerminalSystemState.Terminals.Count
        NetworkCount = $script:TerminalSystemState.Networks.Count
        CompromisedTerminals = @($script:TerminalSystemState.Terminals.Values | Where-Object { $_.Compromised }).Count
        ActiveAlerts = $script:TerminalSystemState.SecurityAlerts.Count
        HackHistoryCount = $script:TerminalSystemState.HackHistory.Count
        PlayerTraceLevel = $script:TerminalSystemState.PlayerTraceLevel
        OwnedPrograms = $script:TerminalSystemState.PlayerPrograms.Keys.Count
        Configuration = $script:TerminalSystemState.Configuration
    }
}

function Export-TerminalData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    $exportData = @{
        Terminals = $script:TerminalSystemState.Terminals
        Networks = $script:TerminalSystemState.Networks
        PlayerPrograms = $script:TerminalSystemState.PlayerPrograms
        PlayerTraceLevel = $script:TerminalSystemState.PlayerTraceLevel
        HackHistory = @($script:TerminalSystemState.HackHistory)
        SecurityAlerts = @($script:TerminalSystemState.SecurityAlerts)
        Configuration = $script:TerminalSystemState.Configuration
        ExportedAt = Get-Date
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath
    
    return @{
        Success = $true
        FilePath = $FilePath
        TerminalCount = $script:TerminalSystemState.Terminals.Count
    }
}

function Import-TerminalData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $importData = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    
    # Initialize first
    Initialize-TerminalSystem -Configuration @{} | Out-Null
    
    # Convert JSON objects back to hashtables
    $script:TerminalSystemState.Terminals = @{}
    foreach ($prop in $importData.Terminals.PSObject.Properties) {
        $terminal = @{}
        foreach ($p in $prop.Value.PSObject.Properties) {
            $terminal[$p.Name] = $p.Value
        }
        $script:TerminalSystemState.Terminals[$prop.Name] = $terminal
    }
    
    $script:TerminalSystemState.Networks = @{}
    foreach ($prop in $importData.Networks.PSObject.Properties) {
        $network = @{}
        foreach ($p in $prop.Value.PSObject.Properties) {
            $network[$p.Name] = $p.Value
        }
        $script:TerminalSystemState.Networks[$prop.Name] = $network
    }
    
    $script:TerminalSystemState.PlayerPrograms = @{}
    foreach ($prop in $importData.PlayerPrograms.PSObject.Properties) {
        $prog = @{}
        foreach ($p in $prop.Value.PSObject.Properties) {
            $prog[$p.Name] = $p.Value
        }
        $script:TerminalSystemState.PlayerPrograms[$prop.Name] = $prog
    }
    
    $script:TerminalSystemState.PlayerTraceLevel = $importData.PlayerTraceLevel
    
    return @{
        Success = $true
        TerminalCount = $script:TerminalSystemState.Terminals.Count
        NetworkCount = $script:TerminalSystemState.Networks.Count
    }
}
#endregion

#region Event Processing
function Process-TerminalEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TimeAdvanced', 'LocationEntered', 'MissionComplete', 'FactionChange')]
        [string]$EventType,
        
        [hashtable]$EventData = @{}
    )
    
    $results = [System.Collections.ArrayList]::new()
    
    switch ($EventType) {
        'TimeAdvanced' {
            # Reduce trace level over time
            $config = $script:TerminalSystemState.Configuration
            $reduction = [int]($EventData.MinutesPassed * ($config.TraceDecayRate / 60))
            if ($reduction -gt 0) {
                $newLevel = Reduce-TraceLevel -Amount $reduction
                [void]$results.Add(@{ Type = 'TraceLevelReduced'; NewLevel = $newLevel })
            }
            
            # Clear old alerts
            $cutoff = (Get-Date).AddSeconds(-$config.AlertDuration)
            $oldAlerts = @($script:TerminalSystemState.SecurityAlerts | Where-Object { $_.Time -lt $cutoff })
            foreach ($alert in $oldAlerts) {
                [void]$script:TerminalSystemState.SecurityAlerts.Remove($alert)
            }
            if ($oldAlerts.Count -gt 0) {
                [void]$results.Add(@{ Type = 'AlertsCleared'; Count = $oldAlerts.Count })
            }
        }
        
        'LocationEntered' {
            # Check for terminals at location
            $terminals = Get-Terminal -LocationId $EventData.LocationId -ActiveOnly
            if ($terminals.Count -gt 0) {
                [void]$results.Add(@{ 
                    Type = 'TerminalsAvailable'
                    LocationId = $EventData.LocationId
                    Count = $terminals.Count
                    Terminals = @($terminals | ForEach-Object { $_.TerminalId })
                })
            }
        }
        
        'MissionComplete' {
            # Reset terminal ICE if mission involves terminal
            if ($EventData.TerminalId) {
                Reset-TerminalICE -TerminalId $EventData.TerminalId | Out-Null
                [void]$results.Add(@{ Type = 'TerminalReset'; TerminalId = $EventData.TerminalId })
            }
        }
        
        'FactionChange' {
            # Update security alerts based on faction standing
            if ($EventData.FactionId -and $EventData.NewStanding -eq 'Allied') {
                Clear-SecurityAlert -FactionId $EventData.FactionId | Out-Null
                [void]$results.Add(@{ Type = 'AlertsCleared'; FactionId = $EventData.FactionId })
            }
        }
    }
    
    return ,@($results)
}
#endregion

# Export all functions
Export-ModuleMember -Function @(
    # Initialization
    'Initialize-TerminalSystem'
    
    # Terminal Management
    'New-Terminal'
    'Get-Terminal'
    'Set-TerminalActive'
    'Remove-Terminal'
    
    # Network Management
    'New-Network'
    'Get-Network'
    'Add-TerminalToNetwork'
    'Remove-TerminalFromNetwork'
    
    # Hacking System
    'Get-HackChance'
    'Start-Hack'
    'Invoke-DataTheft'
    'Invoke-TerminalAction'
    
    # ICE Management
    'Get-TerminalICE'
    'Invoke-ICEBypass'
    'Reset-TerminalICE'
    
    # Hacking Programs
    'Get-HackingProgram'
    'Add-HackingProgram'
    'Remove-HackingProgram'
    
    # Security Alerts
    'Get-SecurityAlert'
    'Clear-SecurityAlert'
    'Get-TraceLevel'
    'Add-TraceLevel'
    'Reduce-TraceLevel'
    
    # Hack History
    'Get-HackHistory'
    'Get-HackStatistics'
    
    # State Management
    'Get-TerminalSystemState'
    'Export-TerminalData'
    'Import-TerminalData'
    
    # Event Processing
    'Process-TerminalEvent'
)
