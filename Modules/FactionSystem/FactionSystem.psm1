# FactionSystem Module
# Manages factions, reputation, relationships, and territory control for the cyberpunk RPG

#region Module State
$script:FactionSystemState = @{
    Initialized = $false
    Factions = @{}              # FactionId -> Faction object
    PlayerReputation = @{}      # FactionId -> Reputation value
    FactionRelations = @{}      # "FactionA:FactionB" -> Relationship
    TerritoryControl = @{}      # TerritoryId -> FactionId
    Configuration = @{}
}
#endregion

#region Faction Types and Standing Levels
$script:FactionTypes = @{
    'Corporation' = @{
        Description = 'MegaCorps - control tech, resources, and prime territory'
        OrganizationLevel = 'VeryHigh'
        DefaultDanger = 'High'
        DefaultWealth = 'Massive'
        TypicalServices = @('LegalGoods', 'Cyberware', 'Employment', 'Security')
    }
    'Crew' = @{
        Description = 'Ex-military crime gangs - professional, disciplined, deadly'
        OrganizationLevel = 'VeryHigh'
        DefaultDanger = 'VeryHigh'
        DefaultWealth = 'High'
        TypicalServices = @('Weapons', 'Mercenaries', 'Smuggling', 'Protection')
    }
    'Syndicate' = @{
        Description = 'Organized street gangs - mafia-style, territorial, structured'
        OrganizationLevel = 'High'
        DefaultDanger = 'High'
        DefaultWealth = 'Medium'
        TypicalServices = @('BlackMarket', 'Protection', 'Drugs', 'Gambling')
    }
    'YoungTeam' = @{
        Description = 'Youth street gangs - chaotic, everywhere, unpredictable'
        OrganizationLevel = 'Low'
        DefaultDanger = 'Variable'
        DefaultWealth = 'Low'
        TypicalServices = @('StreetInfo', 'Lookouts', 'SmallCrimes')
    }
    'Underground' = @{
        Description = 'Fixers, data brokers, neutral service providers'
        OrganizationLevel = 'Medium'
        DefaultDanger = 'Low'
        DefaultWealth = 'Medium'
        TypicalServices = @('Intel', 'Contracts', 'Fencing', 'SafeHouses')
    }
    'Independent' = @{
        Description = 'Police, militia, cults - local authority figures'
        OrganizationLevel = 'Variable'
        DefaultDanger = 'Variable'
        DefaultWealth = 'Variable'
        TypicalServices = @('Law', 'LocalServices', 'Ideology')
    }
    'Player' = @{
        Description = 'Player-built faction (late game)'
        OrganizationLevel = 'PlayerControlled'
        DefaultDanger = 'PlayerControlled'
        DefaultWealth = 'PlayerControlled'
        TypicalServices = @()
    }
}

$script:StandingLevels = @{
    'Hostile'    = @{ MinRep = -1000; MaxRep = -50;  PriceModifier = 2.0;  AccessLevel = 0; AttackOnSight = $true }
    'Unfriendly' = @{ MinRep = -49;   MaxRep = -10;  PriceModifier = 1.5;  AccessLevel = 1; AttackOnSight = $false }
    'Neutral'    = @{ MinRep = -9;    MaxRep = 25;   PriceModifier = 1.0;  AccessLevel = 2; AttackOnSight = $false }
    'Friendly'   = @{ MinRep = 26;    MaxRep = 75;   PriceModifier = 0.9;  AccessLevel = 3; AttackOnSight = $false }
    'Allied'     = @{ MinRep = 76;    MaxRep = 1000; PriceModifier = 0.8;  AccessLevel = 4; AttackOnSight = $false }
}

$script:RelationshipTypes = @{
    'AtWar'    = @{ Modifier = -50; AllowsTrade = $false; SharesIntel = $false }
    'Hostile'  = @{ Modifier = -25; AllowsTrade = $false; SharesIntel = $false }
    'Rival'    = @{ Modifier = -10; AllowsTrade = $true;  SharesIntel = $false }
    'Neutral'  = @{ Modifier = 0;   AllowsTrade = $true;  SharesIntel = $false }
    'Friendly' = @{ Modifier = 10;  AllowsTrade = $true;  SharesIntel = $true }
    'Allied'   = @{ Modifier = 25;  AllowsTrade = $true;  SharesIntel = $true }
}
#endregion

#region Initialization
function Initialize-FactionSystem {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{}
    )
    
    Write-Host "Initializing FactionSystem module..."
    
    # Set default configuration
    $defaultConfig = @{
        DefaultPlayerReputation = 0
        ReputationDecayEnabled = $false
        ReputationDecayRate = 1          # Points per game day toward neutral
        MaxReputation = 1000
        MinReputation = -1000
        RivalryReputationSpread = $true  # Helping one faction hurts rivals
        RivalrySpreadFactor = 0.5        # 50% of rep change spreads to rivals
    }
    
    # Merge with provided configuration
    foreach ($key in $Configuration.Keys) {
        $defaultConfig[$key] = $Configuration[$key]
    }
    
    $script:FactionSystemState.Configuration = $defaultConfig
    $script:FactionSystemState.Factions = @{}
    $script:FactionSystemState.PlayerReputation = @{}
    $script:FactionSystemState.FactionRelations = @{}
    $script:FactionSystemState.TerritoryControl = @{}
    $script:FactionSystemState.Initialized = $true
    
    # Emit initialization event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'FactionSystemInitialized' -Data @{
            Configuration = $defaultConfig
            FactionTypes = $script:FactionTypes.Keys
            Timestamp = Get-Date
        }
    }
    
    return @{
        Initialized = $true
        ModuleName = 'FactionSystem'
        Configuration = $defaultConfig
        FactionTypes = $script:FactionTypes.Keys
        StandingLevels = $script:StandingLevels.Keys
    }
}
#endregion

#region Faction Management
function New-Faction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateSet('Corporation', 'Crew', 'Syndicate', 'YoungTeam', 'Underground', 'Independent', 'Player')]
        [string]$Type,
        
        [string]$Description,
        
        [string]$Leader,
        
        [string]$LeaderTitle,
        
        [string]$Headquarters,          # LocationId from WorldSystem
        
        [array]$ControlledTerritories = @(),
        
        [string]$Colors,                # Visual identifier (e.g., "Red & Black")
        
        [string]$Symbol,                # Icon/logo description
        
        [array]$Services = @(),         # What they offer when friendly
        
        [array]$Specializations = @(),  # Combat/criminal specialties
        
        [hashtable]$ReputationEffects = @{},  # Standing -> effects hashtable
        
        [ValidateSet('VeryLow', 'Low', 'Medium', 'High', 'VeryHigh', 'Variable')]
        [string]$OrganizationLevel,
        
        [ValidateSet('None', 'Low', 'Medium', 'High', 'VeryHigh', 'Extreme', 'Variable')]
        [string]$DangerLevel = 'Medium',
        
        [bool]$IsHidden = $false,       # Secret faction, not shown until discovered
        
        [hashtable]$Metadata = @{}
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized. Call Initialize-FactionSystem first."
    }
    
    $typeInfo = $script:FactionTypes[$Type]
    
    # Use defaults from type if not specified
    if (-not $OrganizationLevel) {
        $OrganizationLevel = $typeInfo.OrganizationLevel
    }
    if (-not $Services -or $Services.Count -eq 0) {
        $Services = $typeInfo.TypicalServices
    }
    
    $faction = @{
        FactionId = $FactionId
        Name = $Name
        Type = $Type
        TypeInfo = $typeInfo
        Description = $Description ?? $typeInfo.Description
        Leader = $Leader
        LeaderTitle = $LeaderTitle
        Headquarters = $Headquarters
        ControlledTerritories = $ControlledTerritories
        Colors = $Colors
        Symbol = $Symbol
        Services = $Services
        Specializations = $Specializations
        ReputationEffects = $ReputationEffects
        OrganizationLevel = $OrganizationLevel
        DangerLevel = $DangerLevel
        IsHidden = $IsHidden
        IsActive = $true
        CreatedAt = Get-Date
        Metadata = $Metadata
    }
    
    $script:FactionSystemState.Factions[$FactionId] = $faction
    
    # Initialize player reputation with this faction
    $script:FactionSystemState.PlayerReputation[$FactionId] = $script:FactionSystemState.Configuration.DefaultPlayerReputation
    
    # Register territory control
    foreach ($territory in $ControlledTerritories) {
        $script:FactionSystemState.TerritoryControl[$territory] = $FactionId
    }
    
    # Emit event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'FactionCreated' -Data @{
            FactionId = $FactionId
            Name = $Name
            Type = $Type
        }
    }
    
    return $faction
}

function Get-Faction {
    [CmdletBinding()]
    param(
        [string]$FactionId,
        [string]$Type,
        [string]$TerritoryId,
        [switch]$IncludeHidden
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized."
    }
    
    # Get by specific ID
    if ($FactionId) {
        return $script:FactionSystemState.Factions[$FactionId]
    }
    
    $factions = $script:FactionSystemState.Factions.Values
    
    # Filter hidden unless requested
    if (-not $IncludeHidden) {
        $factions = $factions | Where-Object { -not $_.IsHidden }
    }
    
    # Filter by type
    if ($Type) {
        $factions = $factions | Where-Object { $_.Type -eq $Type }
    }
    
    # Filter by territory
    if ($TerritoryId) {
        $factions = $factions | Where-Object { $_.ControlledTerritories -contains $TerritoryId }
    }
    
    return @($factions)
}

function Set-FactionActive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId,
        
        [Parameter(Mandatory)]
        [bool]$Active
    )
    
    $faction = $script:FactionSystemState.Factions[$FactionId]
    if (-not $faction) {
        return $false
    }
    
    $faction.IsActive = $Active
    
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'FactionStatusChanged' -Data @{
            FactionId = $FactionId
            IsActive = $Active
        }
    }
    
    return $true
}

function Remove-Faction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId
    )
    
    if (-not $script:FactionSystemState.Factions.ContainsKey($FactionId)) {
        return $false
    }
    
    # Remove territory control
    $territories = $script:FactionSystemState.TerritoryControl.Keys | 
        Where-Object { $script:FactionSystemState.TerritoryControl[$_] -eq $FactionId }
    foreach ($t in $territories) {
        $script:FactionSystemState.TerritoryControl.Remove($t)
    }
    
    # Remove reputation
    $script:FactionSystemState.PlayerReputation.Remove($FactionId)
    
    # Remove relationships
    $relations = $script:FactionSystemState.FactionRelations.Keys |
        Where-Object { $_ -match "^$FactionId`:" -or $_ -match ":$FactionId`$" }
    foreach ($r in $relations) {
        $script:FactionSystemState.FactionRelations.Remove($r)
    }
    
    # Remove faction
    $script:FactionSystemState.Factions.Remove($FactionId)
    
    return $true
}
#endregion

#region Reputation System
function Get-Reputation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized."
    }
    
    $reputation = $script:FactionSystemState.PlayerReputation[$FactionId]
    if ($null -eq $reputation) {
        return $null
    }
    
    $standing = Get-StandingFromReputation -Reputation $reputation
    $standingInfo = $script:StandingLevels[$standing]
    
    return @{
        FactionId = $FactionId
        Reputation = $reputation
        Standing = $standing
        PriceModifier = $standingInfo.PriceModifier
        AccessLevel = $standingInfo.AccessLevel
        AttackOnSight = $standingInfo.AttackOnSight
        NextThreshold = Get-NextReputationThreshold -CurrentRep $reputation
    }
}

function Get-StandingFromReputation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Reputation
    )
    
    foreach ($standing in @('Hostile', 'Unfriendly', 'Neutral', 'Friendly', 'Allied')) {
        $level = $script:StandingLevels[$standing]
        if ($Reputation -ge $level.MinRep -and $Reputation -le $level.MaxRep) {
            return $standing
        }
    }
    
    # Fallback
    if ($Reputation -lt -50) { return 'Hostile' }
    if ($Reputation -gt 75) { return 'Allied' }
    return 'Neutral'
}

function Get-NextReputationThreshold {
    [CmdletBinding()]
    param(
        [int]$CurrentRep
    )
    
    $currentStanding = Get-StandingFromReputation -Reputation $CurrentRep
    $currentLevel = $script:StandingLevels[$currentStanding]
    
    # If positive, show next tier up
    if ($CurrentRep -ge 0) {
        $nextUp = switch ($currentStanding) {
            'Neutral' { @{ Standing = 'Friendly'; Required = 26 - $CurrentRep } }
            'Friendly' { @{ Standing = 'Allied'; Required = 76 - $CurrentRep } }
            'Allied' { @{ Standing = 'Max'; Required = 0 } }
            default { @{ Standing = 'Neutral'; Required = -9 - $CurrentRep } }
        }
        return $nextUp
    }
    else {
        # If negative, show how much to reach neutral
        return @{ Standing = 'Neutral'; Required = -9 - $CurrentRep }
    }
}

function Set-Reputation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId,
        
        [Parameter(Mandatory)]
        [int]$Reputation
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized."
    }
    
    if (-not $script:FactionSystemState.Factions.ContainsKey($FactionId)) {
        return @{
            Success = $false
            Error = "Faction '$FactionId' not found"
        }
    }
    
    $config = $script:FactionSystemState.Configuration
    $clampedRep = [Math]::Max($config.MinReputation, [Math]::Min($config.MaxReputation, $Reputation))
    
    $oldRep = $script:FactionSystemState.PlayerReputation[$FactionId] ?? 0
    $oldStanding = Get-StandingFromReputation -Reputation $oldRep
    
    $script:FactionSystemState.PlayerReputation[$FactionId] = $clampedRep
    
    $newStanding = Get-StandingFromReputation -Reputation $clampedRep
    
    # Emit event if standing changed
    if ($oldStanding -ne $newStanding) {
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'FactionStandingChanged' -Data @{
                FactionId = $FactionId
                OldStanding = $oldStanding
                NewStanding = $newStanding
                Reputation = $clampedRep
            }
        }
    }
    
    return @{
        Success = $true
        FactionId = $FactionId
        OldReputation = $oldRep
        NewReputation = $clampedRep
        OldStanding = $oldStanding
        NewStanding = $newStanding
    }
}

function Add-Reputation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId,
        
        [Parameter(Mandatory)]
        [int]$Amount,
        
        [string]$Reason,
        
        [switch]$SpreadToRivals    # Apply inverse to rival factions
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized."
    }
    
    if (-not $script:FactionSystemState.Factions.ContainsKey($FactionId)) {
        return @{
            Success = $false
            Error = "Faction '$FactionId' not found"
        }
    }
    
    $currentRep = $script:FactionSystemState.PlayerReputation[$FactionId] ?? 0
    $newRep = $currentRep + $Amount
    
    $result = Set-Reputation -FactionId $FactionId -Reputation $newRep
    $result.Change = $Amount
    $result.Reason = $Reason
    $result.RivalEffects = @()
    
    # Spread reputation to rivals if enabled
    $config = $script:FactionSystemState.Configuration
    if ($SpreadToRivals -or $config.RivalryReputationSpread) {
        $rivalAmount = -[int]($Amount * $config.RivalrySpreadFactor)
        
        if ($rivalAmount -ne 0) {
            # Find rival/hostile factions
            $rivals = Get-FactionRelationships -FactionId $FactionId | 
                Where-Object { $_.Relationship -in @('Hostile', 'Rival', 'AtWar') }
            
            foreach ($rival in $rivals) {
                $rivalResult = Set-Reputation -FactionId $rival.OtherFactionId -Reputation (
                    ($script:FactionSystemState.PlayerReputation[$rival.OtherFactionId] ?? 0) + $rivalAmount
                )
                $result.RivalEffects += @{
                    FactionId = $rival.OtherFactionId
                    Change = $rivalAmount
                }
            }
        }
    }
    
    # Emit event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'ReputationChanged' -Data @{
            FactionId = $FactionId
            Change = $Amount
            NewReputation = $result.NewReputation
            NewStanding = $result.NewStanding
            Reason = $Reason
        }
    }
    
    return $result
}

function Get-AllReputations {
    [CmdletBinding()]
    param(
        [switch]$IncludeHidden
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        return @()
    }
    
    $reputations = @()
    
    foreach ($factionId in $script:FactionSystemState.PlayerReputation.Keys) {
        $faction = $script:FactionSystemState.Factions[$factionId]
        if (-not $faction) { continue }
        if ($faction.IsHidden -and -not $IncludeHidden) { continue }
        
        $rep = Get-Reputation -FactionId $factionId
        $reputations += @{
            FactionId = $factionId
            FactionName = $faction.Name
            FactionType = $faction.Type
            Reputation = $rep.Reputation
            Standing = $rep.Standing
            PriceModifier = $rep.PriceModifier
        }
    }
    
    return $reputations | Sort-Object -Property Reputation -Descending
}
#endregion

#region Faction Relationships
function Set-FactionRelationship {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionA,
        
        [Parameter(Mandatory)]
        [string]$FactionB,
        
        [Parameter(Mandatory)]
        [ValidateSet('AtWar', 'Hostile', 'Rival', 'Neutral', 'Friendly', 'Allied')]
        [string]$Relationship
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized."
    }
    
    # Validate factions exist
    if (-not $script:FactionSystemState.Factions.ContainsKey($FactionA)) {
        return @{ Success = $false; Error = "Faction '$FactionA' not found" }
    }
    if (-not $script:FactionSystemState.Factions.ContainsKey($FactionB)) {
        return @{ Success = $false; Error = "Faction '$FactionB' not found" }
    }
    
    # Store relationship (bidirectional, use sorted key)
    $key = ($FactionA, $FactionB | Sort-Object) -join ':'
    
    $script:FactionSystemState.FactionRelations[$key] = @{
        FactionA = $FactionA
        FactionB = $FactionB
        Relationship = $Relationship
        RelationshipInfo = $script:RelationshipTypes[$Relationship]
        SetAt = Get-Date
    }
    
    # Emit event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'FactionRelationshipChanged' -Data @{
            FactionA = $FactionA
            FactionB = $FactionB
            Relationship = $Relationship
        }
    }
    
    return @{
        Success = $true
        FactionA = $FactionA
        FactionB = $FactionB
        Relationship = $Relationship
    }
}

function Get-FactionRelationship {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionA,
        
        [Parameter(Mandatory)]
        [string]$FactionB
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized."
    }
    
    $key = ($FactionA, $FactionB | Sort-Object) -join ':'
    $relation = $script:FactionSystemState.FactionRelations[$key]
    
    if (-not $relation) {
        # Default to Neutral if not set
        return @{
            FactionA = $FactionA
            FactionB = $FactionB
            Relationship = 'Neutral'
            RelationshipInfo = $script:RelationshipTypes['Neutral']
            IsDefault = $true
        }
    }
    
    return $relation
}

function Get-FactionRelationships {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        return @()
    }
    
    $relationships = @()
    
    foreach ($key in $script:FactionSystemState.FactionRelations.Keys) {
        $relation = $script:FactionSystemState.FactionRelations[$key]
        
        if ($relation.FactionA -eq $FactionId) {
            $relationships += @{
                OtherFactionId = $relation.FactionB
                Relationship = $relation.Relationship
                RelationshipInfo = $relation.RelationshipInfo
            }
        }
        elseif ($relation.FactionB -eq $FactionId) {
            $relationships += @{
                OtherFactionId = $relation.FactionA
                Relationship = $relation.Relationship
                RelationshipInfo = $relation.RelationshipInfo
            }
        }
    }
    
    return $relationships
}

function Test-FactionsHostile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionA,
        
        [Parameter(Mandatory)]
        [string]$FactionB
    )
    
    $relation = Get-FactionRelationship -FactionA $FactionA -FactionB $FactionB
    return $relation.Relationship -in @('AtWar', 'Hostile')
}

function Test-FactionsAllied {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionA,
        
        [Parameter(Mandatory)]
        [string]$FactionB
    )
    
    $relation = Get-FactionRelationship -FactionA $FactionA -FactionB $FactionB
    return $relation.Relationship -in @('Allied', 'Friendly')
}
#endregion

#region Territory Control
function Set-TerritoryControl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerritoryId,
        
        [Parameter(Mandatory)]
        [string]$FactionId
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized."
    }
    
    # Validate faction exists
    if (-not $script:FactionSystemState.Factions.ContainsKey($FactionId)) {
        return @{ Success = $false; Error = "Faction '$FactionId' not found" }
    }
    
    $oldController = $script:FactionSystemState.TerritoryControl[$TerritoryId]
    
    # Update territory control
    $script:FactionSystemState.TerritoryControl[$TerritoryId] = $FactionId
    
    # Update faction's controlled territories list
    $faction = $script:FactionSystemState.Factions[$FactionId]
    if ($TerritoryId -notin $faction.ControlledTerritories) {
        $faction.ControlledTerritories += $TerritoryId
    }
    
    # Remove from old controller
    if ($oldController -and $oldController -ne $FactionId) {
        $oldFaction = $script:FactionSystemState.Factions[$oldController]
        if ($oldFaction) {
            $oldFaction.ControlledTerritories = $oldFaction.ControlledTerritories | 
                Where-Object { $_ -ne $TerritoryId }
        }
    }
    
    # Emit event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'TerritoryControlChanged' -Data @{
            TerritoryId = $TerritoryId
            OldController = $oldController
            NewController = $FactionId
        }
    }
    
    return @{
        Success = $true
        TerritoryId = $TerritoryId
        OldController = $oldController
        NewController = $FactionId
    }
}

function Get-TerritoryController {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerritoryId
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        return $null
    }
    
    $factionId = $script:FactionSystemState.TerritoryControl[$TerritoryId]
    if (-not $factionId) {
        return $null
    }
    
    return $script:FactionSystemState.Factions[$factionId]
}

function Get-FactionTerritories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId
    )
    
    $faction = $script:FactionSystemState.Factions[$FactionId]
    if (-not $faction) {
        return @()
    }
    
    return @($faction.ControlledTerritories)
}

function Transfer-Territory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TerritoryId,
        
        [Parameter(Mandatory)]
        [string]$ToFactionId,
        
        [ValidateSet('Conquest', 'Purchase', 'Treaty', 'Abandonment')]
        [string]$Method = 'Conquest'
    )
    
    $result = Set-TerritoryControl -TerritoryId $TerritoryId -FactionId $ToFactionId
    
    if ($result.Success) {
        $result.Method = $Method
        
        # Emit specific transfer event
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'TerritoryTransferred' -Data @{
                TerritoryId = $TerritoryId
                FromFaction = $result.OldController
                ToFaction = $ToFactionId
                Method = $Method
            }
        }
    }
    
    return $result
}
#endregion

#region Standing Effects
function Get-StandingEffects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId
    )
    
    $faction = $script:FactionSystemState.Factions[$FactionId]
    if (-not $faction) {
        return $null
    }
    
    $rep = Get-Reputation -FactionId $FactionId
    $standing = $rep.Standing
    $standingInfo = $script:StandingLevels[$standing]
    
    # Get faction-specific effects for this standing
    $factionEffects = $faction.ReputationEffects[$standing] ?? @{}
    
    return @{
        FactionId = $FactionId
        FactionName = $faction.Name
        Standing = $standing
        PriceModifier = $standingInfo.PriceModifier
        AccessLevel = $standingInfo.AccessLevel
        AttackOnSight = $standingInfo.AttackOnSight
        CanAccessServices = $standingInfo.AccessLevel -ge 2
        CanAccessSpecialServices = $standingInfo.AccessLevel -ge 3
        FactionSpecificEffects = $factionEffects
        AvailableServices = if ($standingInfo.AccessLevel -ge 2) { $faction.Services } else { @() }
    }
}

function Test-CanAccessFaction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId,
        
        [int]$RequiredAccessLevel = 2
    )
    
    $rep = Get-Reputation -FactionId $FactionId
    if (-not $rep) {
        return $false
    }
    
    return $rep.AccessLevel -ge $RequiredAccessLevel
}

function Get-PriceModifier {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FactionId
    )
    
    $rep = Get-Reputation -FactionId $FactionId
    if (-not $rep) {
        return 1.0  # Default to no modifier
    }
    
    return $rep.PriceModifier
}
#endregion

#region Faction Events
function Process-FactionEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('QuestCompleted', 'QuestFailed', 'EnemyKilled', 'ItemSold', 
                     'TerritoryContested', 'AllianceFormed', 'WarDeclared')]
        [string]$EventType,
        
        [Parameter(Mandatory)]
        [hashtable]$EventData
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        return @()
    }
    
    $results = @()
    
    switch ($EventType) {
        'QuestCompleted' {
            # Apply reputation from quest rewards
            if ($EventData.FactionId -and $EventData.ReputationReward) {
                $result = Add-Reputation `
                    -FactionId $EventData.FactionId `
                    -Amount $EventData.ReputationReward `
                    -Reason "Quest completed: $($EventData.QuestName)"
                $results += $result
            }
        }
        
        'QuestFailed' {
            # Apply reputation penalty
            if ($EventData.FactionId -and $EventData.ReputationPenalty) {
                $result = Add-Reputation `
                    -FactionId $EventData.FactionId `
                    -Amount (-$EventData.ReputationPenalty) `
                    -Reason "Quest failed: $($EventData.QuestName)"
                $results += $result
            }
        }
        
        'EnemyKilled' {
            # Killing faction members reduces reputation
            if ($EventData.FactionId) {
                $penalty = $EventData.ReputationPenalty ?? 5
                $result = Add-Reputation `
                    -FactionId $EventData.FactionId `
                    -Amount (-$penalty) `
                    -Reason "Killed faction member"
                $results += $result
            }
        }
        
        'TerritoryContested' {
            # Territory conflict affects reputation with both factions
            if ($EventData.AttackingFaction -and $EventData.DefendingFaction) {
                # Defender loses respect for player if player helped attacker
                if ($EventData.PlayerSide -eq 'Attacker') {
                    $result = Add-Reputation `
                        -FactionId $EventData.DefendingFaction `
                        -Amount -25 `
                        -Reason "Helped attack their territory"
                    $results += $result
                }
                elseif ($EventData.PlayerSide -eq 'Defender') {
                    $result = Add-Reputation `
                        -FactionId $EventData.DefendingFaction `
                        -Amount 25 `
                        -Reason "Helped defend their territory"
                    $results += $result
                }
            }
        }
    }
    
    return $results
}
#endregion

#region State Export/Import
function Get-FactionSystemState {
    [CmdletBinding()]
    param()
    
    if (-not $script:FactionSystemState.Initialized) {
        return $null
    }
    
    return @{
        Initialized = $script:FactionSystemState.Initialized
        Factions = $script:FactionSystemState.Factions
        PlayerReputation = $script:FactionSystemState.PlayerReputation
        FactionRelations = $script:FactionSystemState.FactionRelations
        TerritoryControl = $script:FactionSystemState.TerritoryControl
        Statistics = @{
            TotalFactions = $script:FactionSystemState.Factions.Count
            TotalTerritories = $script:FactionSystemState.TerritoryControl.Count
            TotalRelationships = $script:FactionSystemState.FactionRelations.Count
        }
    }
}

function Export-FactionData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    $state = Get-FactionSystemState
    if (-not $state) {
        throw "FactionSystem not initialized."
    }
    
    $exportData = @{
        Version = '1.0'
        ExportedAt = Get-Date -Format 'o'
        Factions = $state.Factions
        PlayerReputation = $state.PlayerReputation
        FactionRelations = $state.FactionRelations
        TerritoryControl = $state.TerritoryControl
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath -Encoding UTF8
    
    return @{
        Success = $true
        FilePath = $FilePath
        FactionsExported = $state.Factions.Count
    }
}

function Import-FactionData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [switch]$MergeWithExisting
    )
    
    if (-not $script:FactionSystemState.Initialized) {
        throw "FactionSystem not initialized."
    }
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $importData = Get-Content -Path $FilePath -Raw | ConvertFrom-Json -AsHashtable
    
    if (-not $MergeWithExisting) {
        $script:FactionSystemState.Factions = @{}
        $script:FactionSystemState.PlayerReputation = @{}
        $script:FactionSystemState.FactionRelations = @{}
        $script:FactionSystemState.TerritoryControl = @{}
    }
    
    # Import factions
    foreach ($key in $importData.Factions.Keys) {
        if (-not $script:FactionSystemState.Factions.ContainsKey($key) -or -not $MergeWithExisting) {
            $script:FactionSystemState.Factions[$key] = $importData.Factions[$key]
        }
    }
    
    # Import reputation
    foreach ($key in $importData.PlayerReputation.Keys) {
        $script:FactionSystemState.PlayerReputation[$key] = $importData.PlayerReputation[$key]
    }
    
    # Import relations
    foreach ($key in $importData.FactionRelations.Keys) {
        $script:FactionSystemState.FactionRelations[$key] = $importData.FactionRelations[$key]
    }
    
    # Import territory control
    foreach ($key in $importData.TerritoryControl.Keys) {
        $script:FactionSystemState.TerritoryControl[$key] = $importData.TerritoryControl[$key]
    }
    
    return @{
        Success = $true
        ImportedFactions = $importData.Factions.Count
        ImportedTerritories = $importData.TerritoryControl.Count
    }
}
#endregion

# Export all public functions
Export-ModuleMember -Function @(
    # Initialization
    'Initialize-FactionSystem',
    
    # Faction Management
    'New-Faction',
    'Get-Faction',
    'Set-FactionActive',
    'Remove-Faction',
    
    # Reputation
    'Get-Reputation',
    'Set-Reputation',
    'Add-Reputation',
    'Get-AllReputations',
    
    # Relationships
    'Set-FactionRelationship',
    'Get-FactionRelationship',
    'Get-FactionRelationships',
    'Test-FactionsHostile',
    'Test-FactionsAllied',
    
    # Territory
    'Set-TerritoryControl',
    'Get-TerritoryController',
    'Get-FactionTerritories',
    'Transfer-Territory',
    
    # Standing Effects
    'Get-StandingEffects',
    'Test-CanAccessFaction',
    'Get-PriceModifier',
    
    # Events
    'Process-FactionEvent',
    
    # State
    'Get-FactionSystemState',
    'Export-FactionData',
    'Import-FactionData'
)