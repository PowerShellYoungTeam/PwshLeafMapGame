# QuestSystem Module
# Handles missions, quests, objectives, and progress tracking for the cyberpunk RPG

#region Module State
$script:QuestSystemState = @{
    Initialized = $false
    ActiveQuests = @{}          # QuestId -> Quest object
    CompletedQuests = @{}       # QuestId -> Quest object (with completion data)
    FailedQuests = @{}          # QuestId -> Quest object (with failure data)
    QuestTemplates = @{}        # TemplateId -> Quest template
    ObjectiveTypes = @{}        # ObjectiveType -> Validator function
    QuestGivers = @{}           # GiverId -> Giver info
    Configuration = @{}
}
#endregion

#region Quest Types and Objective Types
$script:QuestTypes = @{
    'MainStory'    = @{ Priority = 100; CanAbandon = $false; TracksOnMap = $true }
    'Side'         = @{ Priority = 50;  CanAbandon = $true;  TracksOnMap = $true }
    'Faction'      = @{ Priority = 75;  CanAbandon = $true;  TracksOnMap = $true }
    'Repeatable'   = @{ Priority = 25;  CanAbandon = $true;  TracksOnMap = $false }
    'Contract'     = @{ Priority = 60;  CanAbandon = $true;  TracksOnMap = $true }  # Fixer jobs
    'Discovery'    = @{ Priority = 30;  CanAbandon = $true;  TracksOnMap = $false } # Hidden quests
}

$script:ObjectiveTypeDefinitions = @{
    'GoToLocation'   = @{ RequiresTarget = $true;  ProgressType = 'Boolean' }
    'KillTarget'     = @{ RequiresTarget = $true;  ProgressType = 'Count' }
    'CollectItem'    = @{ RequiresTarget = $true;  ProgressType = 'Count' }
    'TalkToNPC'      = @{ RequiresTarget = $true;  ProgressType = 'Boolean' }
    'HackTerminal'   = @{ RequiresTarget = $true;  ProgressType = 'Boolean' }
    'DeliverItem'    = @{ RequiresTarget = $true;  ProgressType = 'Boolean' }
    'EscortNPC'      = @{ RequiresTarget = $true;  ProgressType = 'Boolean' }
    'SurviveTime'    = @{ RequiresTarget = $false; ProgressType = 'Time' }
    'ReachLevel'     = @{ RequiresTarget = $false; ProgressType = 'Value' }
    'EarnCredits'    = @{ RequiresTarget = $false; ProgressType = 'Value' }
    'Discover'       = @{ RequiresTarget = $true;  ProgressType = 'Boolean' }
    'Stealth'        = @{ RequiresTarget = $true;  ProgressType = 'Boolean' }  # Complete without detection
    'ChoiceRequired' = @{ RequiresTarget = $false; ProgressType = 'Choice' }   # Dialog/moral choice
}

$script:QuestDifficulty = @{
    'Trivial'    = @{ Level = 1;  XPMultiplier = 0.5;  CreditMultiplier = 0.5 }
    'Easy'       = @{ Level = 5;  XPMultiplier = 0.75; CreditMultiplier = 0.75 }
    'Normal'     = @{ Level = 10; XPMultiplier = 1.0;  CreditMultiplier = 1.0 }
    'Hard'       = @{ Level = 15; XPMultiplier = 1.5;  CreditMultiplier = 1.5 }
    'VeryHard'   = @{ Level = 20; XPMultiplier = 2.0;  CreditMultiplier = 2.0 }
    'Nightmare'  = @{ Level = 25; XPMultiplier = 3.0;  CreditMultiplier = 3.0 }
}
#endregion

#region Initialization
function Initialize-QuestSystem {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{}
    )
    
    Write-Host "Initializing QuestSystem module..."
    
    # Set default configuration
    $defaultConfig = @{
        MaxActiveQuests = 20
        MaxTrackedQuests = 5
        AutoTrackNewQuests = $true
        ShowQuestNotifications = $true
        QuestMarkerColor = '#FFD700'       # Gold
        ObjectiveMarkerColor = '#00FF00'   # Green
        EnableTimeLimit = $true
        DefaultTimeLimitHours = 24
    }
    
    # Merge with provided configuration
    foreach ($key in $Configuration.Keys) {
        $defaultConfig[$key] = $Configuration[$key]
    }
    
    $script:QuestSystemState.Configuration = $defaultConfig
    $script:QuestSystemState.ActiveQuests = @{}
    $script:QuestSystemState.CompletedQuests = @{}
    $script:QuestSystemState.FailedQuests = @{}
    $script:QuestSystemState.QuestTemplates = @{}
    $script:QuestSystemState.QuestGivers = @{}
    $script:QuestSystemState.Initialized = $true
    
    # Register objective validators
    Register-DefaultObjectiveValidators
    
    # Emit initialization event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'QuestSystemInitialized' -Data @{
            Configuration = $defaultConfig
            Timestamp = Get-Date
        }
    }
    
    return @{
        Initialized = $true
        ModuleName = 'QuestSystem'
        Configuration = $defaultConfig
        QuestTypes = $script:QuestTypes.Keys
        ObjectiveTypes = $script:ObjectiveTypeDefinitions.Keys
    }
}

function Register-DefaultObjectiveValidators {
    # Register default validators for objective types
    $script:QuestSystemState.ObjectiveTypes = @{
        'GoToLocation' = {
            param($Objective, $EventData)
            if ($EventData.EventType -eq 'PlayerArrivedAtLocation') {
                return $EventData.LocationId -eq $Objective.TargetId
            }
            return $false
        }
        'KillTarget' = {
            param($Objective, $EventData)
            if ($EventData.EventType -eq 'EnemyKilled') {
                if ($Objective.TargetId -eq $EventData.EnemyType -or $Objective.TargetId -eq $EventData.EnemyId) {
                    return $true
                }
            }
            return $false
        }
        'CollectItem' = {
            param($Objective, $EventData)
            if ($EventData.EventType -eq 'ItemCollected') {
                return $EventData.ItemId -eq $Objective.TargetId -or $EventData.ItemType -eq $Objective.TargetId
            }
            return $false
        }
        'TalkToNPC' = {
            param($Objective, $EventData)
            if ($EventData.EventType -eq 'DialogueCompleted') {
                return $EventData.NPCId -eq $Objective.TargetId
            }
            return $false
        }
        'HackTerminal' = {
            param($Objective, $EventData)
            if ($EventData.EventType -eq 'HackCompleted') {
                return $EventData.TerminalId -eq $Objective.TargetId
            }
            return $false
        }
        'DeliverItem' = {
            param($Objective, $EventData)
            if ($EventData.EventType -eq 'ItemDelivered') {
                return $EventData.ItemId -eq $Objective.TargetId -and $EventData.TargetNPC -eq $Objective.DeliverTo
            }
            return $false
        }
    }
}
#endregion

#region Quest Templates
function New-QuestTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplateId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [Parameter(Mandatory)]
        [ValidateSet('MainStory', 'Side', 'Faction', 'Repeatable', 'Contract', 'Discovery')]
        [string]$QuestType,
        
        [ValidateSet('Trivial', 'Easy', 'Normal', 'Hard', 'VeryHard', 'Nightmare')]
        [string]$Difficulty = 'Normal',
        
        [array]$Objectives = @(),
        
        [hashtable]$Rewards = @{},
        
        [string]$QuestGiverId,
        
        [string]$FactionId,
        
        [array]$Prerequisites = @(),    # Quest IDs that must be completed first
        
        [int]$MinLevel = 1,
        
        [int]$TimeLimitMinutes = 0,     # 0 = no time limit
        
        [hashtable]$Metadata = @{}
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized. Call Initialize-QuestSystem first."
    }
    
    $template = @{
        TemplateId = $TemplateId
        Name = $Name
        Description = $Description
        QuestType = $QuestType
        TypeInfo = $script:QuestTypes[$QuestType]
        Difficulty = $Difficulty
        DifficultyInfo = $script:QuestDifficulty[$Difficulty]
        Objectives = $Objectives
        Rewards = $Rewards
        QuestGiverId = $QuestGiverId
        FactionId = $FactionId
        Prerequisites = $Prerequisites
        MinLevel = $MinLevel
        TimeLimitMinutes = $TimeLimitMinutes
        Metadata = $Metadata
        CreatedAt = Get-Date
    }
    
    $script:QuestSystemState.QuestTemplates[$TemplateId] = $template
    
    return $template
}

function Get-QuestTemplate {
    [CmdletBinding()]
    param(
        [string]$TemplateId,
        [string]$QuestType,
        [string]$FactionId
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    $templates = $script:QuestSystemState.QuestTemplates.Values
    
    if ($TemplateId) {
        return $script:QuestSystemState.QuestTemplates[$TemplateId]
    }
    
    if ($QuestType) {
        $templates = $templates | Where-Object { $_.QuestType -eq $QuestType }
    }
    
    if ($FactionId) {
        $templates = $templates | Where-Object { $_.FactionId -eq $FactionId }
    }
    
    return @($templates)
}

function Remove-QuestTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplateId
    )
    
    if ($script:QuestSystemState.QuestTemplates.ContainsKey($TemplateId)) {
        $script:QuestSystemState.QuestTemplates.Remove($TemplateId)
        return $true
    }
    return $false
}
#endregion

#region Objective Management
function New-QuestObjective {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ObjectiveId,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [Parameter(Mandatory)]
        [ValidateSet('GoToLocation', 'KillTarget', 'CollectItem', 'TalkToNPC', 'HackTerminal', 
                     'DeliverItem', 'EscortNPC', 'SurviveTime', 'ReachLevel', 'EarnCredits', 
                     'Discover', 'Stealth', 'ChoiceRequired')]
        [string]$Type,
        
        [string]$TargetId,              # Location, NPC, Item, etc.
        
        [int]$RequiredCount = 1,        # For count-based objectives
        
        [int]$OrderIndex = 0,           # Sequence order (0 = can be done anytime)
        
        [bool]$IsOptional = $false,     # Optional bonus objective
        
        [bool]$IsHidden = $false,       # Don't show until revealed
        
        [string]$HintText,              # Optional hint for the player
        
        [hashtable]$BonusReward,        # Extra reward for this objective
        
        [hashtable]$Location,           # { Lat, Lng, Radius } for map marker
        
        [hashtable]$Metadata = @{}
    )
    
    $typeInfo = $script:ObjectiveTypeDefinitions[$Type]
    
    $objective = @{
        ObjectiveId = $ObjectiveId
        Description = $Description
        Type = $Type
        TypeInfo = $typeInfo
        TargetId = $TargetId
        RequiredCount = $RequiredCount
        CurrentCount = 0
        OrderIndex = $OrderIndex
        IsOptional = $IsOptional
        IsHidden = $IsHidden
        IsComplete = $false
        HintText = $HintText
        BonusReward = $BonusReward
        Location = $Location
        Metadata = $Metadata
    }
    
    return $objective
}
#endregion

#region Quest Lifecycle
function Start-Quest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByTemplate')]
        [string]$TemplateId,
        
        [Parameter(Mandatory, ParameterSetName = 'Direct')]
        [string]$QuestId,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$Name,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$Description,
        
        [Parameter(ParameterSetName = 'Direct')]
        [string]$QuestType = 'Side',
        
        [Parameter(ParameterSetName = 'Direct')]
        [array]$Objectives = @(),
        
        [Parameter(ParameterSetName = 'Direct')]
        [hashtable]$Rewards = @{},
        
        [bool]$AutoTrack = $true,
        
        [int]$PlayerLevel = 1
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    # Check max active quests
    $activeCount = $script:QuestSystemState.ActiveQuests.Count
    $maxQuests = $script:QuestSystemState.Configuration.MaxActiveQuests
    if ($activeCount -ge $maxQuests) {
        return @{
            Success = $false
            Error = "Maximum active quests reached ($maxQuests)"
        }
    }
    
    # Build quest from template or direct params
    if ($PSCmdlet.ParameterSetName -eq 'ByTemplate') {
        $template = $script:QuestSystemState.QuestTemplates[$TemplateId]
        if (-not $template) {
            return @{
                Success = $false
                Error = "Quest template '$TemplateId' not found"
            }
        }
        
        # Check prerequisites
        foreach ($prereq in $template.Prerequisites) {
            if (-not $script:QuestSystemState.CompletedQuests.ContainsKey($prereq)) {
                return @{
                    Success = $false
                    Error = "Prerequisite quest '$prereq' not completed"
                }
            }
        }
        
        # Check level requirement
        if ($PlayerLevel -lt $template.MinLevel) {
            return @{
                Success = $false
                Error = "Player level ($PlayerLevel) below minimum ($($template.MinLevel))"
            }
        }
        
        # Check if already active or completed (for non-repeatable)
        $questId = "$TemplateId-$(Get-Date -Format 'yyyyMMddHHmmss')"
        if ($template.QuestType -ne 'Repeatable') {
            $existingActive = $script:QuestSystemState.ActiveQuests.Values | 
                Where-Object { $_.TemplateId -eq $TemplateId }
            if ($existingActive) {
                return @{
                    Success = $false
                    Error = "Quest already active"
                }
            }
            
            $existingCompleted = $script:QuestSystemState.CompletedQuests.Values |
                Where-Object { $_.TemplateId -eq $TemplateId }
            if ($existingCompleted) {
                return @{
                    Success = $false
                    Error = "Quest already completed"
                }
            }
            $questId = $TemplateId  # Use template ID for non-repeatable
        }
        
        # Clone objectives for this instance
        $questObjectives = @{}
        foreach ($obj in $template.Objectives) {
            $clonedObj = $obj.Clone()
            $clonedObj.CurrentCount = 0
            $clonedObj.IsComplete = $false
            $questObjectives[$obj.ObjectiveId] = $clonedObj
        }
        
        $quest = @{
            QuestId = $questId
            TemplateId = $TemplateId
            Name = $template.Name
            Description = $template.Description
            QuestType = $template.QuestType
            TypeInfo = $template.TypeInfo
            Difficulty = $template.Difficulty
            DifficultyInfo = $template.DifficultyInfo
            Objectives = $questObjectives
            Rewards = $template.Rewards.Clone()
            QuestGiverId = $template.QuestGiverId
            FactionId = $template.FactionId
            Status = 'Active'
            IsTracked = $AutoTrack -and $script:QuestSystemState.Configuration.AutoTrackNewQuests
            StartedAt = Get-Date
            TimeLimit = if ($template.TimeLimitMinutes -gt 0) { 
                (Get-Date).AddMinutes($template.TimeLimitMinutes) 
            } else { $null }
            Metadata = $template.Metadata.Clone()
        }
    }
    else {
        # Direct quest creation
        if ($script:QuestSystemState.ActiveQuests.ContainsKey($QuestId)) {
            return @{
                Success = $false
                Error = "Quest '$QuestId' already active"
            }
        }
        
        $questObjectives = @{}
        foreach ($obj in $Objectives) {
            $questObjectives[$obj.ObjectiveId] = $obj
        }
        
        $quest = @{
            QuestId = $QuestId
            TemplateId = $null
            Name = $Name
            Description = $Description
            QuestType = $QuestType
            TypeInfo = $script:QuestTypes[$QuestType]
            Difficulty = 'Normal'
            DifficultyInfo = $script:QuestDifficulty['Normal']
            Objectives = $questObjectives
            Rewards = $Rewards
            QuestGiverId = $null
            FactionId = $null
            Status = 'Active'
            IsTracked = $AutoTrack
            StartedAt = Get-Date
            TimeLimit = $null
            Metadata = @{}
        }
    }
    
    $script:QuestSystemState.ActiveQuests[$quest.QuestId] = $quest
    
    # Emit event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'QuestStarted' -Data @{
            QuestId = $quest.QuestId
            Name = $quest.Name
            QuestType = $quest.QuestType
            ObjectiveCount = $quest.Objectives.Count
        }
    }
    
    return @{
        Success = $true
        Quest = $quest
    }
}

function Get-Quest {
    [CmdletBinding()]
    param(
        [string]$QuestId,
        [ValidateSet('Active', 'Completed', 'Failed', 'All')]
        [string]$Status = 'Active',
        [string]$QuestType,
        [string]$FactionId,
        [switch]$TrackedOnly
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    # If specific ID requested
    if ($QuestId) {
        if ($script:QuestSystemState.ActiveQuests.ContainsKey($QuestId)) {
            return $script:QuestSystemState.ActiveQuests[$QuestId]
        }
        if ($script:QuestSystemState.CompletedQuests.ContainsKey($QuestId)) {
            return $script:QuestSystemState.CompletedQuests[$QuestId]
        }
        if ($script:QuestSystemState.FailedQuests.ContainsKey($QuestId)) {
            return $script:QuestSystemState.FailedQuests[$QuestId]
        }
        return $null
    }
    
    # Get quests by status
    $quests = @()
    switch ($Status) {
        'Active' { $quests = $script:QuestSystemState.ActiveQuests.Values }
        'Completed' { $quests = $script:QuestSystemState.CompletedQuests.Values }
        'Failed' { $quests = $script:QuestSystemState.FailedQuests.Values }
        'All' { 
            $quests = @()
            $quests += $script:QuestSystemState.ActiveQuests.Values
            $quests += $script:QuestSystemState.CompletedQuests.Values
            $quests += $script:QuestSystemState.FailedQuests.Values
        }
    }
    
    # Apply filters
    if ($QuestType) {
        $quests = $quests | Where-Object { $_.QuestType -eq $QuestType }
    }
    if ($FactionId) {
        $quests = $quests | Where-Object { $_.FactionId -eq $FactionId }
    }
    if ($TrackedOnly) {
        $quests = $quests | Where-Object { $_.IsTracked }
    }
    
    return @($quests)
}

function Set-QuestTracked {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$QuestId,
        
        [Parameter(Mandatory)]
        [bool]$Tracked
    )
    
    $quest = $script:QuestSystemState.ActiveQuests[$QuestId]
    if (-not $quest) {
        return $false
    }
    
    # Check max tracked quests
    if ($Tracked) {
        $trackedCount = ($script:QuestSystemState.ActiveQuests.Values | 
            Where-Object { $_.IsTracked }).Count
        $maxTracked = $script:QuestSystemState.Configuration.MaxTrackedQuests
        if ($trackedCount -ge $maxTracked) {
            return $false
        }
    }
    
    $quest.IsTracked = $Tracked
    return $true
}

function Complete-Quest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$QuestId,
        
        [switch]$Force    # Complete even if objectives not done
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    $quest = $script:QuestSystemState.ActiveQuests[$QuestId]
    if (-not $quest) {
        return @{
            Success = $false
            Error = "Quest '$QuestId' not found in active quests"
        }
    }
    
    # Check if all required objectives are complete
    if (-not $Force) {
        $incomplete = $quest.Objectives.Values | 
            Where-Object { -not $_.IsOptional -and -not $_.IsComplete }
        if ($incomplete) {
            return @{
                Success = $false
                Error = "Quest has incomplete required objectives"
                IncompleteObjectives = $incomplete.ObjectiveId
            }
        }
    }
    
    # Calculate rewards
    $rewards = @{
        Experience = $quest.Rewards.Experience ?? 0
        Credits = $quest.Rewards.Credits ?? 0
        Items = $quest.Rewards.Items ?? @()
        Reputation = $quest.Rewards.Reputation ?? @{}
    }
    
    # Apply difficulty multipliers
    if ($quest.DifficultyInfo) {
        $rewards.Experience = [int]($rewards.Experience * $quest.DifficultyInfo.XPMultiplier)
        $rewards.Credits = [int]($rewards.Credits * $quest.DifficultyInfo.CreditMultiplier)
    }
    
    # Add bonus rewards from completed optional objectives
    foreach ($obj in $quest.Objectives.Values) {
        if ($obj.IsOptional -and $obj.IsComplete -and $obj.BonusReward) {
            $rewards.Experience += ($obj.BonusReward.Experience ?? 0)
            $rewards.Credits += ($obj.BonusReward.Credits ?? 0)
            if ($obj.BonusReward.Items) {
                $rewards.Items += $obj.BonusReward.Items
            }
        }
    }
    
    # Move to completed
    $quest.Status = 'Completed'
    $quest.CompletedAt = Get-Date
    $quest.FinalRewards = $rewards
    $quest.IsTracked = $false
    
    $script:QuestSystemState.ActiveQuests.Remove($QuestId)
    $script:QuestSystemState.CompletedQuests[$QuestId] = $quest
    
    # Emit event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'QuestCompleted' -Data @{
            QuestId = $QuestId
            Name = $quest.Name
            QuestType = $quest.QuestType
            Rewards = $rewards
            Duration = ($quest.CompletedAt - $quest.StartedAt).TotalMinutes
        }
    }
    
    return @{
        Success = $true
        Quest = $quest
        Rewards = $rewards
    }
}

function Fail-Quest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$QuestId,
        
        [string]$Reason = 'Unknown'
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    $quest = $script:QuestSystemState.ActiveQuests[$QuestId]
    if (-not $quest) {
        return @{
            Success = $false
            Error = "Quest '$QuestId' not found in active quests"
        }
    }
    
    # Move to failed
    $quest.Status = 'Failed'
    $quest.FailedAt = Get-Date
    $quest.FailureReason = $Reason
    $quest.IsTracked = $false
    
    $script:QuestSystemState.ActiveQuests.Remove($QuestId)
    $script:QuestSystemState.FailedQuests[$QuestId] = $quest
    
    # Apply failure penalties if defined
    $penalties = @{
        ReputationLoss = @{}
    }
    if ($quest.Rewards.Reputation) {
        foreach ($faction in $quest.Rewards.Reputation.Keys) {
            $penalties.ReputationLoss[$faction] = -[int]($quest.Rewards.Reputation[$faction] * 0.5)
        }
    }
    
    # Emit event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'QuestFailed' -Data @{
            QuestId = $QuestId
            Name = $quest.Name
            Reason = $Reason
            Penalties = $penalties
        }
    }
    
    return @{
        Success = $true
        Quest = $quest
        Penalties = $penalties
    }
}

function Abandon-Quest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$QuestId
    )
    
    $quest = $script:QuestSystemState.ActiveQuests[$QuestId]
    if (-not $quest) {
        return @{
            Success = $false
            Error = "Quest '$QuestId' not found"
        }
    }
    
    # Check if can be abandoned
    if (-not $quest.TypeInfo.CanAbandon) {
        return @{
            Success = $false
            Error = "This quest cannot be abandoned"
        }
    }
    
    return Fail-Quest -QuestId $QuestId -Reason 'Abandoned'
}
#endregion

#region Objective Progress
function Update-QuestObjective {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$QuestId,
        
        [Parameter(Mandatory)]
        [string]$ObjectiveId,
        
        [int]$ProgressIncrement = 1,
        
        [switch]$SetComplete,
        
        [hashtable]$EventData
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    $quest = $script:QuestSystemState.ActiveQuests[$QuestId]
    if (-not $quest) {
        return @{
            Success = $false
            Error = "Quest '$QuestId' not found"
        }
    }
    
    $objective = $quest.Objectives[$ObjectiveId]
    if (-not $objective) {
        return @{
            Success = $false
            Error = "Objective '$ObjectiveId' not found in quest"
        }
    }
    
    if ($objective.IsComplete) {
        return @{
            Success = $true
            AlreadyComplete = $true
        }
    }
    
    # Check ordering constraints
    if ($objective.OrderIndex -gt 0) {
        $previousRequired = $quest.Objectives.Values | 
            Where-Object { $_.OrderIndex -gt 0 -and $_.OrderIndex -lt $objective.OrderIndex -and -not $_.IsOptional }
        $incompletePrereqs = $previousRequired | Where-Object { -not $_.IsComplete }
        if ($incompletePrereqs) {
            return @{
                Success = $false
                Error = "Previous objectives must be completed first"
                BlockedBy = $incompletePrereqs.ObjectiveId
            }
        }
    }
    
    # Update progress
    $wasHidden = $objective.IsHidden
    $objective.IsHidden = $false  # Reveal when progress is made
    
    if ($SetComplete) {
        $objective.CurrentCount = $objective.RequiredCount
        $objective.IsComplete = $true
    }
    else {
        $objective.CurrentCount += $ProgressIncrement
        if ($objective.CurrentCount -ge $objective.RequiredCount) {
            $objective.IsComplete = $true
        }
    }
    
    # Emit progress event
    if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType 'QuestObjectiveProgress' -Data @{
            QuestId = $QuestId
            ObjectiveId = $ObjectiveId
            Progress = $objective.CurrentCount
            Required = $objective.RequiredCount
            IsComplete = $objective.IsComplete
            WasHidden = $wasHidden
        }
    }
    
    # Check if quest is now completable
    $allRequiredComplete = -not ($quest.Objectives.Values | 
        Where-Object { -not $_.IsOptional -and -not $_.IsComplete })
    
    if ($allRequiredComplete) {
        if (Get-Command Send-GameEvent -ErrorAction SilentlyContinue) {
            Send-GameEvent -EventType 'QuestReadyToComplete' -Data @{
                QuestId = $QuestId
                Name = $quest.Name
            }
        }
    }
    
    return @{
        Success = $true
        Objective = $objective
        QuestReady = $allRequiredComplete
    }
}

function Get-QuestProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$QuestId
    )
    
    $quest = Get-Quest -QuestId $QuestId
    if (-not $quest) {
        return $null
    }
    
    $totalRequired = 0
    $totalComplete = 0
    $objectives = @()
    
    foreach ($obj in $quest.Objectives.Values) {
        if (-not $obj.IsHidden) {
            $totalRequired++
            if ($obj.IsComplete) {
                $totalComplete++
            }
            $objectives += @{
                ObjectiveId = $obj.ObjectiveId
                Description = $obj.Description
                Progress = "$($obj.CurrentCount)/$($obj.RequiredCount)"
                IsComplete = $obj.IsComplete
                IsOptional = $obj.IsOptional
            }
        }
    }
    
    return @{
        QuestId = $QuestId
        Name = $quest.Name
        Status = $quest.Status
        PercentComplete = if ($totalRequired -gt 0) { [int](($totalComplete / $totalRequired) * 100) } else { 0 }
        ObjectivesComplete = $totalComplete
        ObjectivesTotal = $totalRequired
        Objectives = $objectives
        TimeRemaining = if ($quest.TimeLimit) { $quest.TimeLimit - (Get-Date) } else { $null }
        IsTracked = $quest.IsTracked
    }
}

function Process-QuestEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventType,
        
        [Parameter(Mandatory)]
        [hashtable]$EventData
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        return @()
    }
    
    $updates = @()
    
    # Check all active quests for matching objectives
    foreach ($quest in $script:QuestSystemState.ActiveQuests.Values) {
        foreach ($objective in $quest.Objectives.Values) {
            if ($objective.IsComplete) { continue }
            
            # Get the validator for this objective type
            $validator = $script:QuestSystemState.ObjectiveTypes[$objective.Type]
            if ($validator) {
                $eventDataWithType = $EventData.Clone()
                $eventDataWithType.EventType = $EventType
                
                $matches = & $validator $objective $eventDataWithType
                if ($matches) {
                    $result = Update-QuestObjective -QuestId $quest.QuestId -ObjectiveId $objective.ObjectiveId
                    if ($result.Success) {
                        $updates += @{
                            QuestId = $quest.QuestId
                            QuestName = $quest.Name
                            ObjectiveId = $objective.ObjectiveId
                            ObjectiveDescription = $objective.Description
                            IsComplete = $result.Objective.IsComplete
                            QuestReady = $result.QuestReady
                        }
                    }
                }
            }
        }
    }
    
    return $updates
}
#endregion

#region Quest Givers
function Register-QuestGiver {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GiverId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Title,                  # "Fixer", "Contact", etc.
        
        [string]$FactionId,
        
        [array]$AvailableQuests = @(),   # Template IDs
        
        [hashtable]$Location,            # { Lat, Lng }
        
        [string]$LocationId,             # Reference to WorldSystem location
        
        [hashtable]$Requirements = @{},  # Min reputation, level, etc.
        
        [hashtable]$Metadata = @{}
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    $giver = @{
        GiverId = $GiverId
        Name = $Name
        Title = $Title
        FactionId = $FactionId
        AvailableQuests = $AvailableQuests
        Location = $Location
        LocationId = $LocationId
        Requirements = $Requirements
        Metadata = $Metadata
    }
    
    $script:QuestSystemState.QuestGivers[$GiverId] = $giver
    
    return $giver
}

function Get-QuestGiver {
    [CmdletBinding()]
    param(
        [string]$GiverId,
        [string]$FactionId,
        [string]$LocationId
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    if ($GiverId) {
        return $script:QuestSystemState.QuestGivers[$GiverId]
    }
    
    $givers = $script:QuestSystemState.QuestGivers.Values
    
    if ($FactionId) {
        $givers = $givers | Where-Object { $_.FactionId -eq $FactionId }
    }
    
    if ($LocationId) {
        $givers = $givers | Where-Object { $_.LocationId -eq $LocationId }
    }
    
    return @($givers)
}

function Get-AvailableQuests {
    [CmdletBinding()]
    param(
        [string]$GiverId,
        [int]$PlayerLevel = 1,
        [hashtable]$PlayerReputation = @{}
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        return @()
    }
    
    $available = @()
    $givers = if ($GiverId) { @($script:QuestSystemState.QuestGivers[$GiverId]) } 
              else { $script:QuestSystemState.QuestGivers.Values }
    
    foreach ($giver in $givers) {
        if (-not $giver) { continue }
        
        # Check giver requirements
        if ($giver.Requirements.MinLevel -and $PlayerLevel -lt $giver.Requirements.MinLevel) {
            continue
        }
        if ($giver.Requirements.MinReputation -and $giver.FactionId) {
            $playerRep = $PlayerReputation[$giver.FactionId] ?? 0
            if ($playerRep -lt $giver.Requirements.MinReputation) {
                continue
            }
        }
        
        foreach ($templateId in $giver.AvailableQuests) {
            $template = $script:QuestSystemState.QuestTemplates[$templateId]
            if (-not $template) { continue }
            
            # Check if already active or completed (non-repeatable)
            if ($template.QuestType -ne 'Repeatable') {
                $isActive = $script:QuestSystemState.ActiveQuests.Values | 
                    Where-Object { $_.TemplateId -eq $templateId }
                $isCompleted = $script:QuestSystemState.CompletedQuests.Values |
                    Where-Object { $_.TemplateId -eq $templateId }
                if ($isActive -or $isCompleted) { continue }
            }
            
            # Check level requirement
            if ($PlayerLevel -lt $template.MinLevel) { continue }
            
            # Check prerequisites
            $prereqsMet = $true
            foreach ($prereq in $template.Prerequisites) {
                if (-not $script:QuestSystemState.CompletedQuests.ContainsKey($prereq)) {
                    $prereqsMet = $false
                    break
                }
            }
            if (-not $prereqsMet) { continue }
            
            $available += @{
                TemplateId = $templateId
                Name = $template.Name
                Description = $template.Description
                QuestType = $template.QuestType
                Difficulty = $template.Difficulty
                MinLevel = $template.MinLevel
                GiverId = $giver.GiverId
                GiverName = $giver.Name
                FactionId = $template.FactionId
                Rewards = $template.Rewards
            }
        }
    }
    
    return $available
}
#endregion

#region Time Limit Management
function Update-QuestTimers {
    [CmdletBinding()]
    param()
    
    if (-not $script:QuestSystemState.Initialized) {
        return @()
    }
    
    $expired = @()
    $now = Get-Date
    
    foreach ($quest in $script:QuestSystemState.ActiveQuests.Values) {
        if ($quest.TimeLimit -and $quest.TimeLimit -lt $now) {
            $result = Fail-Quest -QuestId $quest.QuestId -Reason 'TimeExpired'
            if ($result.Success) {
                $expired += $quest.QuestId
            }
        }
    }
    
    return $expired
}

function Get-QuestTimeRemaining {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$QuestId
    )
    
    $quest = $script:QuestSystemState.ActiveQuests[$QuestId]
    if (-not $quest -or -not $quest.TimeLimit) {
        return $null
    }
    
    $remaining = $quest.TimeLimit - (Get-Date)
    
    return @{
        QuestId = $QuestId
        TimeLimit = $quest.TimeLimit
        Remaining = $remaining
        IsExpired = $remaining.TotalSeconds -le 0
        FormattedRemaining = if ($remaining.TotalHours -ge 1) {
            "{0:N0}h {1:N0}m" -f $remaining.TotalHours, $remaining.Minutes
        } else {
            "{0:N0}m {1:N0}s" -f $remaining.TotalMinutes, $remaining.Seconds
        }
    }
}
#endregion

#region State Export/Import
function Get-QuestSystemState {
    [CmdletBinding()]
    param()
    
    if (-not $script:QuestSystemState.Initialized) {
        return $null
    }
    
    return @{
        Initialized = $script:QuestSystemState.Initialized
        ActiveQuests = $script:QuestSystemState.ActiveQuests
        CompletedQuests = $script:QuestSystemState.CompletedQuests
        FailedQuests = $script:QuestSystemState.FailedQuests
        QuestTemplates = $script:QuestSystemState.QuestTemplates
        QuestGivers = $script:QuestSystemState.QuestGivers
        Statistics = @{
            TotalActive = $script:QuestSystemState.ActiveQuests.Count
            TotalCompleted = $script:QuestSystemState.CompletedQuests.Count
            TotalFailed = $script:QuestSystemState.FailedQuests.Count
            TotalTemplates = $script:QuestSystemState.QuestTemplates.Count
            TotalGivers = $script:QuestSystemState.QuestGivers.Count
        }
    }
}

function Export-QuestData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    $state = Get-QuestSystemState
    if (-not $state) {
        throw "QuestSystem not initialized."
    }
    
    $exportData = @{
        Version = '1.0'
        ExportedAt = Get-Date -Format 'o'
        ActiveQuests = $state.ActiveQuests
        CompletedQuests = $state.CompletedQuests
        FailedQuests = $state.FailedQuests
    }
    
    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath -Encoding UTF8
    
    return @{
        Success = $true
        FilePath = $FilePath
        QuestsExported = $exportData.ActiveQuests.Count + $exportData.CompletedQuests.Count + $exportData.FailedQuests.Count
    }
}

function Import-QuestData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [switch]$MergeWithExisting
    )
    
    if (-not $script:QuestSystemState.Initialized) {
        throw "QuestSystem not initialized."
    }
    
    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }
    
    $importData = Get-Content -Path $FilePath -Raw | ConvertFrom-Json -AsHashtable
    
    if (-not $MergeWithExisting) {
        $script:QuestSystemState.ActiveQuests = @{}
        $script:QuestSystemState.CompletedQuests = @{}
        $script:QuestSystemState.FailedQuests = @{}
    }
    
    # Import active quests
    foreach ($key in $importData.ActiveQuests.Keys) {
        if (-not $script:QuestSystemState.ActiveQuests.ContainsKey($key)) {
            $script:QuestSystemState.ActiveQuests[$key] = $importData.ActiveQuests[$key]
        }
    }
    
    # Import completed quests
    foreach ($key in $importData.CompletedQuests.Keys) {
        if (-not $script:QuestSystemState.CompletedQuests.ContainsKey($key)) {
            $script:QuestSystemState.CompletedQuests[$key] = $importData.CompletedQuests[$key]
        }
    }
    
    # Import failed quests
    foreach ($key in $importData.FailedQuests.Keys) {
        if (-not $script:QuestSystemState.FailedQuests.ContainsKey($key)) {
            $script:QuestSystemState.FailedQuests[$key] = $importData.FailedQuests[$key]
        }
    }
    
    return @{
        Success = $true
        ImportedActive = $importData.ActiveQuests.Count
        ImportedCompleted = $importData.CompletedQuests.Count
        ImportedFailed = $importData.FailedQuests.Count
    }
}
#endregion

#region Contract System (Fixer Jobs)
function New-Contract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [ValidateSet('Assassination', 'Retrieval', 'Sabotage', 'Escort', 'Delivery', 
                     'DataTheft', 'Infiltration', 'Protection', 'Extraction')]
        [string]$ContractType = 'Retrieval',
        
        [Parameter(Mandatory)]
        [string]$ClientId,              # Quest giver / Fixer
        
        [int]$PaymentCredits = 1000,
        
        [int]$PaymentUpfront = 0,       # Credits paid when accepted
        
        [ValidateSet('Trivial', 'Easy', 'Normal', 'Hard', 'VeryHard', 'Nightmare')]
        [string]$Difficulty = 'Normal',
        
        [int]$TimeLimitMinutes = 60,
        
        [array]$Objectives = @(),
        
        [hashtable]$BonusConditions = @{},  # e.g., @{ NoAlarms = 500; NoKills = 1000 }
        
        [hashtable]$Metadata = @{}
    )
    
    # Create quest template for this contract
    $rewards = @{
        Credits = $PaymentCredits
        Experience = [int]($PaymentCredits * 0.1)  # 10% of payment as XP
    }
    
    $template = New-QuestTemplate `
        -TemplateId $ContractId `
        -Name $Name `
        -Description $Description `
        -QuestType 'Contract' `
        -Difficulty $Difficulty `
        -Objectives $Objectives `
        -Rewards $rewards `
        -QuestGiverId $ClientId `
        -TimeLimitMinutes $TimeLimitMinutes `
        -Metadata @{
            ContractType = $ContractType
            PaymentUpfront = $PaymentUpfront
            BonusConditions = $BonusConditions
            IsContract = $true
        }
    
    return @{
        ContractId = $ContractId
        Template = $template
        PaymentTotal = $PaymentCredits
        PaymentUpfront = $PaymentUpfront
        PaymentOnCompletion = $PaymentCredits - $PaymentUpfront
        BonusConditions = $BonusConditions
    }
}

function Accept-Contract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContractId,
        
        [int]$PlayerLevel = 1
    )
    
    $template = Get-QuestTemplate -TemplateId $ContractId
    if (-not $template -or -not $template.Metadata.IsContract) {
        return @{
            Success = $false
            Error = "Contract '$ContractId' not found"
        }
    }
    
    $questResult = Start-Quest -TemplateId $ContractId -PlayerLevel $PlayerLevel
    
    # Build new result with upfront payment info
    $result = @{
        Success = $questResult.Success
        Quest = $questResult.Quest
        Error = $questResult.Error
        UpfrontPayment = if ($questResult.Success) { $template.Metadata.PaymentUpfront ?? 0 } else { 0 }
    }
    
    return $result
}
#endregion

# Export all public functions
Export-ModuleMember -Function @(
    # Initialization
    'Initialize-QuestSystem',
    
    # Quest Templates
    'New-QuestTemplate',
    'Get-QuestTemplate',
    'Remove-QuestTemplate',
    
    # Objectives
    'New-QuestObjective',
    
    # Quest Lifecycle
    'Start-Quest',
    'Get-Quest',
    'Set-QuestTracked',
    'Complete-Quest',
    'Fail-Quest',
    'Abandon-Quest',
    
    # Progress
    'Update-QuestObjective',
    'Get-QuestProgress',
    'Process-QuestEvent',
    
    # Quest Givers
    'Register-QuestGiver',
    'Get-QuestGiver',
    'Get-AvailableQuests',
    
    # Time Management
    'Update-QuestTimers',
    'Get-QuestTimeRemaining',
    
    # State
    'Get-QuestSystemState',
    'Export-QuestData',
    'Import-QuestData',
    
    # Contracts
    'New-Contract',
    'Accept-Contract'
)
