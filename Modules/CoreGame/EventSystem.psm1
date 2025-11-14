<#
.SYNOPSIS
    Advanced event system for PowerShell Leafmap Game with JavaScript integration.

.DESCRIPTION
    This module provides a comprehensive event-driven communication system between
    PowerShell backend and JavaScript frontend. Supports event queuing, handler
    registration, priority-based processing, and cross-platform communication.

.NOTES
    Author: PowerShell Leafmap Game Development Team
    Version: 2.0.0
    Created: July 31, 2025

    Features:
    - Bidirectional PowerShell-JavaScript communication
    - Priority-based event handling
    - Event queuing and persistence
    - Handler registration with pattern matching
    - Performance monitoring and debugging
    - Automatic event log rotation
#>

# Import logging system
Import-Module (Join-Path $PSScriptRoot "GameLogging.psm1") -Force

# Event system configuration
$script:EventConfig = @{
    EventQueueFile             = "events.json"
    CommandQueueFile           = "commands.json"
    EventLogFile               = "event_log.json"
    MaxEventLogSize            = 1000
    ProcessingInterval         = 1
    EnablePersistence          = $true
    EnableEventDeduplication   = $true
    DeduplicationWindowMinutes = 5
    MaxQueueSize               = 10000
    EventRetentionDays         = 7
    PerformanceMonitoring      = $true
}

# Event queue for JavaScript consumption
$script:EventQueue = @()

# Command queue from JavaScript
$script:CommandQueue = @()

# Event log for debugging and auditing
$script:EventLog = @()

# Registered event handlers with priority support
$script:EventHandlers = @{}

# Performance metrics
$script:EventMetrics = @{
    TotalEvents           = 0
    EventsProcessed       = 0
    HandlersRegistered    = 0
    AverageProcessingTime = 0
    LastProcessingTime    = $null
    ErrorCount            = 0
}

<#
.SYNOPSIS
    Initializes the event system with comprehensive configuration options.

.DESCRIPTION
    Sets up the event system infrastructure including file paths, event handlers,
    persistence layer, and performance monitoring. Loads existing event logs
    and establishes JavaScript communication channels.

.PARAMETER GamePath
    The root path for the game where event files will be stored.

.PARAMETER Config
    Optional configuration hashtable to override default settings.

.NOTES
    Verbose output is controlled by $VerbosePreference. Set to 'Continue' for detailed logging.

.EXAMPLE
    Initialize-EventSystem -GamePath "C:\Game"

.EXAMPLE
    $VerbosePreference = 'Continue'; Initialize-EventSystem -GamePath "C:\Game"

.EXAMPLE
    Initialize-EventSystem -Config @{ MaxEventLogSize = 5000; EnablePersistence = $false }

.NOTES
    This function must be called before using any other event system functions.
#>
function Initialize-EventSystem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GamePath = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [hashtable]$Config = @{}
    )

    Write-GameLog -Message "Initializing PowerShell Event System..." -Level Info -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')

    try {
        # Apply custom configuration
        foreach ($key in $Config.Keys) {
            if ($script:EventConfig.ContainsKey($key)) {
                $script:EventConfig[$key] = $Config[$key]
                Write-GameLog -Message "Config override: $key = $($Config[$key])" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
            }
        }

        # Set up file paths
        $script:EventConfig.EventQueueFile = Join-Path $GamePath "events.json"
        $script:EventConfig.CommandQueueFile = Join-Path $GamePath "commands.json"
        $script:EventConfig.EventLogFile = Join-Path $GamePath "event_log.json"

        # Load existing event log if persistence is enabled
        if ($script:EventConfig.EnablePersistence -and (Test-Path $script:EventConfig.EventLogFile)) {
            try {
                $loadedEvents = Get-Content $script:EventConfig.EventLogFile -Raw | ConvertFrom-Json
                $script:EventLog = $loadedEvents

                Write-GameLog -Message "Loaded existing event log with $($script:EventLog.Count) events" -Level Info -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')

                # Clean up old events if retention is configured
                if ($script:EventConfig.EventRetentionDays -gt 0) {
                    Clear-OldEvents
                }

            }
            catch {
                Write-ErrorLog -Message "Could not load existing event log" -Module "EventSystem" -Exception $_ -Data @{ FilePath = $script:EventConfig.EventLogFile }
                $script:EventLog = @()
            }
        }

        # Register default event handlers
        Register-DefaultEventHandlers

        # Initialize performance monitoring
        $script:EventMetrics.LastProcessingTime = Get-Date

        Write-GameLog -Message "Event system initialized successfully" -Level Info -Module "EventSystem" -Data @{
            GamePath           = $GamePath
            HandlersRegistered = $script:EventHandlers.Count
            PersistenceEnabled = $script:EventConfig.EnablePersistence
            MaxQueueSize       = $script:EventConfig.MaxQueueSize
        } -Verbose:($VerbosePreference -eq 'Continue')

        return @{
            Success              = $true
            HandlersRegistered   = $script:EventHandlers.Count
            ConfigurationApplied = $Config
            EventLogSize         = $script:EventLog.Count
        }

    }
    catch {
        Write-ErrorLog -Message "Failed to initialize event system" -Module "EventSystem" -Exception $_ -Data @{ GamePath = $GamePath }
        throw
    }
}

<#
.SYNOPSIS
    Cleans up old events based on retention policy.

.DESCRIPTION
    Internal function that removes events older than the configured retention period.
#>
function Clear-OldEvents {
    [CmdletBinding()]
    param()

    if ($script:EventConfig.EventRetentionDays -le 0) {
        return
    }

    $cutoffDate = (Get-Date).AddDays(-$script:EventConfig.EventRetentionDays)
    $originalCount = $script:EventLog.Count

    $script:EventLog = $script:EventLog | Where-Object {
        $eventDate = [DateTime]::Parse($_.Timestamp)
        $eventDate -gt $cutoffDate
    }

    $removedCount = $originalCount - $script:EventLog.Count
    if ($removedCount -gt 0) {
        Write-GameLog -Message "Cleaned up $removedCount old events (older than $($script:EventConfig.EventRetentionDays) days)" -Level Info -Module "EventSystem"
    }
}

<#
.SYNOPSIS
    Registers an event handler for a specific event type.

.DESCRIPTION
    Adds an event handler that will be invoked when events of the specified type are triggered.
    Supports one-time handlers, wildcard patterns, and priority-based execution.

.PARAMETER EventType
    The type of event to handle (supports wildcard patterns).

.PARAMETER ScriptBlock
    The script block to execute when the event is triggered.

.PARAMETER Once
    If specified, the handler will be removed after first execution.

.PARAMETER Priority
    Priority level for handler execution (higher numbers execute first).

.NOTES
    Verbose output is controlled by $VerbosePreference. Set to 'Continue' for detailed logging.

.EXAMPLE
    Register-GameEvent -EventType "player.connected" -ScriptBlock { param($Data) Write-Host "Player: $($Data.Name)" }

.EXAMPLE
    Register-GameEvent -EventType "system.*" -ScriptBlock { param($Data) Log-SystemEvent $Data } -Priority 100
#>
function Register-GameEvent {
    param(
        [Parameter(Mandatory)]
        [string]$EventType,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [int]$Priority = 0,

        [switch]$Once
    )

    if (-not $script:EventHandlers.ContainsKey($EventType)) {
        $script:EventHandlers[$EventType] = @()
    }

    $handler = @{
        ScriptBlock  = $ScriptBlock
        Priority     = $Priority
        Once         = $Once
        Id           = (New-Guid).ToString()
        RegisteredAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    }

    # Ensure the array exists and convert to array
    $script:EventHandlers[$EventType] = @($script:EventHandlers[$EventType])
    $script:EventHandlers[$EventType] += $handler

    # Sort by priority (higher first)
    $script:EventHandlers[$EventType] = $script:EventHandlers[$EventType] | Sort-Object Priority -Descending

    Write-Host "Registered event handler for '$($EventType)' (Priority: $($Priority))" -ForegroundColor Cyan
    return $handler.Id
}

<#
.SYNOPSIS
    Sends a game event for JavaScript consumption and local processing.

.DESCRIPTION
    Creates and dispatches a game event that can be consumed by JavaScript frontend
    and/or processed by local PowerShell event handlers. Supports priority-based
    processing, event deduplication, and performance monitoring.

.PARAMETER EventType
    The type/category of the event (e.g., "player.levelUp", "game.stateChanged").

.PARAMETER Data
    The event payload containing relevant data for the event.

.PARAMETER Source
    The source component that generated this event.

.PARAMETER ProcessLocally
    Force local processing even if no handlers are registered.

.PARAMETER Priority
    The priority level for event processing (High, Normal, Low).

.PARAMETER Deduplicate
    Whether to check for and prevent duplicate events.

.NOTES
    Verbose output is controlled by $VerbosePreference. Set to 'Continue' for detailed logging.
    Events can be deduplicated based on EventType and Data content to prevent spam.
    Priority affects execution order: High > Normal > Low.

.EXAMPLE
    Send-GameEvent -EventType "player.connected" -Data @{ PlayerId = "123"; Name = "John" }

.EXAMPLE
    Send-GameEvent -EventType "error.critical" -Data @{ Message = "Database error" } -Priority High

.EXAMPLE
    $VerbosePreference = 'Continue'; Send-GameEvent -EventType "debug.info" -Data @{ Component = "AI" } -Deduplicate

.NOTES
    Events are automatically queued for JavaScript consumption and logged for auditing.
#>
function Send-GameEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventType,

        [Parameter(Mandatory = $false)]
        [object]$Data = @{},

        [Parameter(Mandatory = $false)]
        [string]$Source = "powershell",

        [Parameter(Mandatory = $false)]
        [switch]$ProcessLocally,

        [Parameter(Mandatory = $false)]
        [ValidateSet("High", "Normal", "Low")]
        [string]$Priority = "Normal",

        [Parameter(Mandatory = $false)]
        [switch]$Deduplicate
    )

    $startTime = Get-Date

    try {
        # Create event object
        $event = @{
            type      = $EventType
            data      = $Data
            timestamp = $startTime.ToString('yyyy-MM-ddTHH:mm:ss.fff')
            id        = "ps_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(((New-Guid).ToString().Substring(0,8)))"
            source    = $Source
            priority  = $Priority
        }

        Write-GameLog -Message "Sending event: $EventType" -Level Debug -Module "EventSystem" -Data @{
            EventId  = $event.id
            Source   = $Source
            Priority = $Priority
            DataSize = ($Data | ConvertTo-Json -Compress).Length
        } -Verbose:($VerbosePreference -eq 'Continue')

        # Check for duplicates if enabled
        if ($Deduplicate -and $script:EventConfig.EnableEventDeduplication) {
            $isDuplicate = Test-DuplicateEvent -Event $event
            if ($isDuplicate) {
                Write-GameLog -Message "Duplicate event prevented: $EventType" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
                return $null
            }
        }

        # Check queue size limits
        if ($script:EventQueue.Count -ge $script:EventConfig.MaxQueueSize) {
            Write-GameLog -Message "Event queue full, removing oldest events" -Level Warning -Module "EventSystem"
            $script:EventQueue = $script:EventQueue | Select-Object -Last ($script:EventConfig.MaxQueueSize - 100)
        }

        # Add to event log
        Add-ToEventLog -Event $event

        # Process locally if handlers exist or forced
        if ($ProcessLocally -or $script:EventHandlers.ContainsKey($EventType) -or (Get-WildcardHandlers -EventType $EventType).Count -gt 0) {
            Invoke-EventHandlers -Event $event
        }

        # Queue for JavaScript consumption
        $script:EventQueue = @($script:EventQueue)
        $script:EventQueue += $event

        # Save events to file for JavaScript to read
        Save-EventQueue

        # Update metrics
        $script:EventMetrics.TotalEvents++
        $processingTime = (Get-Date) - $startTime
        Update-EventProcessingMetrics -ProcessingTime $processingTime

        Write-GameLog -Message "Event sent successfully: $EventType" -Level Debug -Module "EventSystem" -Data @{
            EventId          = $event.id
            ProcessingTimeMs = $processingTime.TotalMilliseconds
        } -Verbose:($VerbosePreference -eq 'Continue')

        return $event.id

    }
    catch {
        Write-ErrorLog -Message "Failed to send event: $EventType" -Module "EventSystem" -Exception $_ -Data @{
            EventType    = $EventType
            Source       = $Source
            DataProvided = $null -ne $Data
        }

        $script:EventMetrics.ErrorCount++
        throw
    }
}

# Process incoming commands from JavaScript
<#
.SYNOPSIS
    Processes commands received from JavaScript frontend.

.DESCRIPTION
    Reads and processes commands from the JavaScript command queue,
    enabling bidirectional communication between frontend and backend.

.PARAMETER Verbose
    Enable verbose logging for command processing.
#>
function Process-JavaScriptCommands {
    [CmdletBinding()]
    param()

    if (-not (Test-Path $script:EventConfig.CommandQueueFile)) {
        Write-GameLog -Message "Command queue file not found" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
        return
    }

    try {
        $commands = Get-Content $script:EventConfig.CommandQueueFile -Raw | ConvertFrom-Json

        if ($commands -and $commands.Count -gt 0) {
            Write-GameLog -Message "Processing $($commands.Count) commands from JavaScript" -Level Info -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')

            foreach ($command in $commands) {
                Process-JavaScriptCommand -Command $command -Verbose:($VerbosePreference -eq 'Continue')
            }

            # Clear processed commands
            @() | ConvertTo-Json | Set-Content $script:EventConfig.CommandQueueFile

            Write-GameLog -Message "Cleared processed commands from queue" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
        }
        else {
            Write-GameLog -Message "No commands to process" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
        }
    }
    catch {
        Write-ErrorLog -Message "Error processing JavaScript commands" -Module "EventSystem" -Exception $_ -Data @{
            CommandQueueFile = $script:EventConfig.CommandQueueFile
        }
    }
}

<#
.SYNOPSIS
    Processes a single command received from JavaScript frontend.

.DESCRIPTION
    Executes commands from JavaScript with proper error handling,
    response generation, and performance monitoring.

.PARAMETER Command
    The command object containing type, data, and other metadata.

.PARAMETER Verbose
    Enable verbose logging for command processing.
#>
function Process-JavaScriptCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Parameter(Mandatory = $true)]
        [object]$Command
    )

    $startTime = Get-Date

    Write-GameLog -Message "Processing command: $($Command.type)" -Level Info -Module "EventSystem" -Data @{
        CommandId    = $Command.id
        CommandType  = $Command.type
        DataProvided = $null -ne $Command.data
    } -Verbose:($VerbosePreference -eq 'Continue')

    try {
        switch ($Command.type) {
            "powershell.generateLocations" {
                $result = Invoke-GenerateLocations -Parameters $Command.data
                Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                    commandId   = $Command.id
                    commandType = "generateLocations"
                    result      = $result
                    success     = $true
                } -Source "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
            }

            "powershell.saveProgress" {
                $result = Save-PlayerProgressInternal -PlayerName $Command.data.playerName -Progress $Command.data.progress
                Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                    commandId   = $Command.id
                    commandType = "saveProgress"
                    result      = $result
                    success     = $true
                } -Source "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
            }

            "powershell.loadProgress" {
                $result = Get-PlayerProgressInternal -PlayerName $Command.data.playerName
                Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                    commandId   = $Command.id
                    commandType = "loadProgress"
                    result      = $result
                    success     = $true
                } -Source "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
            }

            "powershell.calculateStats" {
                $result = Get-GameStatisticsInternal -GameData $Command.data.gameData
                Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                    commandId   = $Command.id
                    commandType = "calculateStats"
                    result      = $result
                    success     = $true
                } -Source "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
            }

            "powershell.findNearby" {
                $result = Find-NearbyLocationsInternal -GameData $Command.data.gameData -Latitude $Command.data.latitude -Longitude $Command.data.longitude -RadiusKm $Command.data.radius
                Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                    commandId   = $Command.id
                    commandType = "findNearby"
                    result      = $result
                    success     = $true
                } -Source "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
            }

            default {
                Write-GameLog -Message "Unknown command type: $($Command.type)" -Level Warning -Module "EventSystem" -Data @{
                    CommandId   = $Command.id
                    CommandType = $Command.type
                } -Verbose:($VerbosePreference -eq 'Continue')

                Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                    commandId   = $Command.id
                    commandType = $Command.type
                    error       = "Unknown command type"
                    success     = $false
                } -Source "EventSystem" -Priority "High" -Verbose:($VerbosePreference -eq 'Continue')
            }
        }

        $processingTime = (Get-Date) - $startTime
        Write-GameLog -Message "Command processed successfully" -Level Debug -Module "EventSystem" -Data @{
            CommandId        = $Command.id
            CommandType      = $Command.type
            ProcessingTimeMs = $processingTime.TotalMilliseconds
        } -Verbose:($VerbosePreference -eq 'Continue')

    }
    catch {
        Write-ErrorLog -Message "Error processing command: $($Command.type)" -Module "EventSystem" -Exception $_ -Data @{
            CommandId   = $Command.id
            CommandType = $Command.type
            CommandData = $Command.data
        }

        # Send error response
        Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
            commandId   = $Command.id
            commandType = $Command.type
            error       = $_.Exception.Message
            success     = $false
        } -Source "EventSystem" -Priority "High"
    }
}

# Invoke event handlers for an event
<#
.SYNOPSIS
    Invokes registered event handlers for a specific event.

.DESCRIPTION
    Executes all registered handlers for an event type, with support for
    one-time handlers, error handling, and verbose logging.

.PARAMETER Event
    The event object to process.

.PARAMETER Verbose
    Enable verbose logging for handler execution.
#>
function Invoke-EventHandlers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Event
    )

    # Get direct handlers
    $handlers = $script:EventHandlers[$Event.type]

    # Get wildcard handlers
    $wildcardHandlers = Get-WildcardHandlers -EventType $Event.type

    # Combine all handlers
    $allHandlers = @()
    if ($handlers) { $allHandlers += $handlers }
    if ($wildcardHandlers) { $allHandlers += $wildcardHandlers }

    if (-not $allHandlers -or $allHandlers.Count -eq 0) {
        Write-GameLog -Message "No handlers found for event: $($Event.type)" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
        return
    }

    Write-GameLog -Message "Executing $($allHandlers.Count) handlers for event: $($Event.type)" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')

    foreach ($handler in $allHandlers) {
        try {
            $startTime = Get-Date

            Write-GameLog -Message "Executing handler $($handler.Id) for event: $($Event.type)" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')

            & $handler.ScriptBlock $Event.data $Event

            $executionTime = (Get-Date) - $startTime
            Write-GameLog -Message "Handler executed successfully in $($executionTime.TotalMilliseconds)ms" -Level Debug -Module "EventSystem" -Data @{
                HandlerId       = $handler.Id
                EventType       = $Event.type
                ExecutionTimeMs = $executionTime.TotalMilliseconds
            } -Verbose:($VerbosePreference -eq 'Continue')

            # Remove handler if it's a one-time handler
            if ($handler.Once) {
                $script:EventHandlers[$Event.type] = $script:EventHandlers[$Event.type] | Where-Object { $_.Id -ne $handler.Id }
                Write-GameLog -Message "Removed one-time handler: $($handler.Id)" -Level Debug -Module "EventSystem" -Verbose:($VerbosePreference -eq 'Continue')
            }
        }
        catch {
            Write-ErrorLog -Message "Error executing event handler for $($Event.type)" -Module "EventSystem" -Exception $_ -Data @{
                HandlerId = $handler.Id
                EventType = $Event.type
                EventId   = $Event.id
            }

            # Send error event (but prevent infinite loops)
            if ($Event.type -ne "system.error") {
                try {
                    Send-GameEvent -EventType "system.error" -Data @{
                        message         = $_.Exception.Message
                        eventType       = $Event.type
                        handlerId       = $handler.Id
                        source          = "powershell"
                        originalEventId = $Event.id
                    } -Source "EventSystem" -Priority "High"
                }
                catch {
                    Write-Warning "Failed to send error event for handler failure: $($_.Exception.Message)"
                }
            }
        }
    }
}

# Register default event handlers
function Register-DefaultEventHandlers {
    # Player events
    Register-GameEvent -EventType "player.created" -ScriptBlock {
        param($Data, $Event)
        Write-Host "Player created: $($Data.playerName)" -ForegroundColor Green

        # Initialize player data files
        $playerFile = "player_$($Data.playerName).json"
        $initialData = @{
            playerName       = $Data.playerName
            createdAt        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
            level            = 1
            experience       = 0
            score            = 0
            visitedLocations = @()
            inventory        = @()
            achievements     = @()
        }

        $initialData | ConvertTo-Json -Depth 5 | Set-Content $playerFile
        Write-Host "Player data file created: $($playerFile)" -ForegroundColor Cyan
    }

    # Location events
    Register-GameEvent -EventType "location.visited" -ScriptBlock {
        param($Data, $Event)
        Write-Host "Location visited: $($Data.location.name) by player $($Data.playerId)" -ForegroundColor Yellow

        # Update player progress with visited location
        $progress = Get-PlayerProgressInternal -PlayerName $Data.playerId

        # Add location to visited list if not already there
        if ($progress.visitedLocations -notcontains $Data.location.id) {
            # Ensure visitedLocations is an array
            if (-not $progress.visitedLocations) {
                $progress.visitedLocations = @()
            }

            # Convert to array if it's not already
            $visitedArray = @($progress.visitedLocations)
            $visitedArray += $Data.location.id
            $progress.visitedLocations = $visitedArray

            # Save updated progress
            Save-PlayerProgressInternal -PlayerName $Data.playerId -Progress $progress
        }

        # Log location visit
        $visitLog = @{
            playerId     = $Data.playerId
            locationId   = $Data.location.id
            locationName = $Data.location.name
            timestamp    = $Event.timestamp
            points       = $Data.location.points
            items        = $Data.location.items
        }

        Add-ToVisitLog -Visit $visitLog

        # Send achievement check event
        Send-GameEvent -EventType "achievement.check" -Data @{
            playerId   = $Data.playerId
            action     = "locationVisit"
            locationId = $Data.location.id
        }
    }

    # System events
    Register-GameEvent -EventType "system.startup" -ScriptBlock {
        param($Data, $Event)
        Write-Host "Game system starting up..." -ForegroundColor Green

        # Perform startup tasks
        Send-GameEvent -EventType "system.dataLoaded" -Data @{
            message   = "System initialized"
            timestamp = $Event.timestamp
        }
    }

    # Achievement events
    Register-GameEvent -EventType "achievement.check" -ScriptBlock {
        param($Data, $Event)
        Check-Achievements -PlayerId $Data.playerId -Action $Data.action -Context $Data
    }
}

# Save event queue to file
function Save-EventQueue {
    try {
        $script:EventQueue | ConvertTo-Json -Depth 10 | Set-Content $script:EventConfig.EventQueueFile
    }
    catch {
        Write-Warning "Failed to save event queue: $($_.Exception.Message)"
    }
}

# Add event to log
function Add-ToEventLog {
    param([object]$Event)

    # Ensure EventLog is an array
    if (-not $script:EventLog) {
        $script:EventLog = @()
    }
    $script:EventLog = @($script:EventLog)
    $script:EventLog += $Event

    # Trim log if too large
    if ($script:EventLog.Count -gt $script:EventConfig.MaxEventLogSize) {
        $script:EventLog = $script:EventLog[ - $script:EventConfig.MaxEventLogSize..-1]
    }

    # Save log to file periodically
    if ($script:EventLog.Count % 10 -eq 0) {
        Save-EventLog
    }
}

# Save event log to file
function Save-EventLog {
    try {
        $script:EventLog | ConvertTo-Json -Depth 10 | Set-Content $script:EventConfig.EventLogFile
    }
    catch {
        Write-Warning "Failed to save event log: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Tests if an event is a duplicate based on configured deduplication rules.

.DESCRIPTION
    Checks recent events to determine if the current event is a duplicate.
    Uses configurable time windows and comparison rules.
#>
function Test-DuplicateEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Event
    )

    if (-not $script:EventConfig.EnableEventDeduplication) {
        return $false
    }

    $cutoffTime = (Get-Date).AddMinutes(-$script:EventConfig.DeduplicationWindowMinutes)
    $recentEvents = $script:EventLog | Where-Object {
        [DateTime]$_.timestamp -gt $cutoffTime -and
        $_.type -eq $Event.type -and
        $_.source -eq $Event.source
    }

    foreach ($recentEvent in $recentEvents) {
        # Simple comparison - can be made more sophisticated
        if (($recentEvent.data | ConvertTo-Json -Compress) -eq ($Event.data | ConvertTo-Json -Compress)) {
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
    Gets event handlers that match wildcard patterns for the given event type.

.DESCRIPTION
    Searches registered event handlers for wildcard patterns that match the event type.
#>
function Get-WildcardHandlers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventType
    )

    $matchingHandlers = @()

    foreach ($handlerType in $script:EventHandlers.Keys) {
        if ($handlerType -like "*.*" -and $EventType -like $handlerType) {
            $matchingHandlers += $script:EventHandlers[$handlerType]
        }
    }

    return $matchingHandlers
}

<#
.SYNOPSIS
    Updates event processing performance metrics.

.DESCRIPTION
    Tracks event processing performance for monitoring and optimization.
#>
function Update-EventProcessingMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [TimeSpan]$ProcessingTime
    )

    if (-not $script:EventMetrics) {
        $script:EventMetrics = @{
            TotalEvents             = 0
            ErrorCount              = 0
            AverageProcessingTimeMs = 0
            MaxProcessingTimeMs     = 0
            LastUpdated             = Get-Date
        }
    }

    $processingTimeMs = $ProcessingTime.TotalMilliseconds

    # Update average processing time
    if ($script:EventMetrics.TotalEvents -gt 0) {
        $script:EventMetrics.AverageProcessingTimeMs = (
            ($script:EventMetrics.AverageProcessingTimeMs * ($script:EventMetrics.TotalEvents - 1)) + $processingTimeMs
        ) / $script:EventMetrics.TotalEvents
    }
    else {
        $script:EventMetrics.AverageProcessingTimeMs = $processingTimeMs
    }

    # Update max processing time
    if ($processingTimeMs -gt $script:EventMetrics.MaxProcessingTimeMs) {
        $script:EventMetrics.MaxProcessingTimeMs = $processingTimeMs
    }

    $script:EventMetrics.LastUpdated = Get-Date
}

<#
.SYNOPSIS
    Writes error information to the game log with enhanced context.

.DESCRIPTION
    Standardized error logging function that captures exception details,
    context data, and stack traces for debugging.
#>
function Write-ErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$Module,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$Exception,

        [Parameter(Mandatory = $false)]
        [object]$Data = @{}
    )

    $errorData = $Data.Clone()

    if ($Exception) {
        $errorData.ExceptionMessage = $Exception.Exception.Message
        $errorData.ExceptionType = $Exception.Exception.GetType().Name
        $errorData.ScriptStackTrace = $Exception.ScriptStackTrace
        $errorData.CategoryInfo = $Exception.CategoryInfo.ToString()
    }

    Write-GameLog -Message $Message -Level Error -Module $Module -Data $errorData
}

# Add visit to log
function Add-ToVisitLog {
    param([object]$Visit)

    $visitLogFile = "visit_log.json"
    $visits = @()

    if (Test-Path $visitLogFile) {
        try {
            $visits = Get-Content $visitLogFile -Raw | ConvertFrom-Json
            # Ensure it's an array
            $visits = @($visits)
        }
        catch {
            Write-Warning "Could not load existing visit log"
        }
    }

    $visits += $Visit

    try {
        $visits | ConvertTo-Json -Depth 5 | Set-Content $visitLogFile
    }
    catch {
        Write-Warning "Could not save visit log"
    }
}

# Check for achievements
function Check-Achievements {
    param(
        [string]$PlayerId,
        [string]$Action,
        [object]$Context
    )

    # Load player progress
    $progress = Get-PlayerProgressInternal -PlayerName $PlayerId

    switch ($Action) {
        "locationVisit" {
            $visitCount = if ($progress.visitedLocations) { $progress.visitedLocations.Count } else { 0 }

            # First visit achievement
            if ($visitCount -eq 1) {
                Send-GameEvent -EventType "achievement.unlocked" -Data @{
                    playerId      = $PlayerId
                    achievementId = "first_visit"
                    title         = "First Steps"
                    description   = "Visited your first location"
                    points        = 50
                }
            }

            # Explorer achievements
            if ($visitCount -eq 5) {
                Send-GameEvent -EventType "achievement.unlocked" -Data @{
                    playerId      = $PlayerId
                    achievementId = "explorer"
                    title         = "Explorer"
                    description   = "Visited 5 locations"
                    points        = 100
                }
            }

            if ($visitCount -eq 10) {
                Send-GameEvent -EventType "achievement.unlocked" -Data @{
                    playerId      = $PlayerId
                    achievementId = "veteran_explorer"
                    title         = "Veteran Explorer"
                    description   = "Visited 10 locations"
                    points        = 200
                }
            }
        }
    }
}

# Internal function to get player progress (duplicated from Game-Manager.ps1 to avoid dependencies)
function Get-PlayerProgressInternal {
    param([string]$PlayerName)

    $progressFile = "player_$($PlayerName).json"
    if (Test-Path $progressFile) {
        try {
            return Get-Content $progressFile -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "Could not load player progress for $($PlayerName): $($_.Exception.Message)"
        }
    }

    # Return new player data if file doesn't exist or couldn't be loaded
    return @{
        playerName       = $PlayerName
        score            = 0
        visitedLocations = @()
        inventory        = @()
        achievements     = @()
        startTime        = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    }
}

# Internal function to save player progress
function Save-PlayerProgressInternal {
    param(
        [string]$PlayerName,
        [object]$Progress
    )

    $progressFile = "player_$($PlayerName).json"
    try {
        $Progress | ConvertTo-Json -Depth 5 | Set-Content $progressFile
        Write-Host "Player progress saved to: $($progressFile)" -ForegroundColor Green
        return $progressFile
    }
    catch {
        Write-Warning "Could not save player progress for $($PlayerName): $($_.Exception.Message)"
        return $null
    }
}

# Internal function to generate locations (simplified version)
function Invoke-GenerateLocations {
    param([object]$Parameters)

    try {
        $city = $Parameters.city
        $locationCount = $Parameters.locationCount

        Write-Host "Generating $($locationCount) locations for $($city)" -ForegroundColor Cyan

        # Simplified location generation
        $locations = @()
        $locationTypes = @("treasure", "quest", "shop", "landmark", "mystery")

        for ($i = 1; $i -le $locationCount; $i++) {
            $type = $locationTypes | Get-Random

            # Generate coordinates (simplified - using NYC area)
            $lat = [math]::Round((40.7128 + (Get-Random -Minimum -0.1 -Maximum 0.1)), 6)
            $lng = [math]::Round((-74.0060 + (Get-Random -Minimum -0.1 -Maximum 0.1)), 6)

            $location = @{
                id          = "generated_location_$($i)"
                lat         = $lat
                lng         = $lng
                name        = "$($type) Location #$($i)"
                type        = $type
                description = "A dynamically generated $($type) location"
                points      = Get-Random -Minimum 25 -Maximum 150
                items       = @("item_$($i)")
                discovered  = $false
                timestamp   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
            }

            $locations = @($locations)
            $locations += $location
        }

        $result = @{
            generatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
            city        = $city
            version     = "1.0"
            locations   = $locations
            metadata    = @{
                totalLocations = $locationCount
                generator      = "PowerShell Event System"
            }
        }

        Write-Host "Successfully generated $($locationCount) locations" -ForegroundColor Green
        return $result

    }
    catch {
        Write-Warning "Error generating locations: $($_.Exception.Message)"
        return @{
            error     = $_.Exception.Message
            locations = @()
        }
    }
}

# Internal function to get game statistics (simplified)
function Get-GameStatisticsInternal {
    param([object]$GameData)

    if (-not $GameData -or -not $GameData.locations) {
        return @{
            error          = "No game data provided"
            TotalLocations = 0
        }
    }

    try {
        $stats = @{
            TotalLocations = $GameData.locations.Count
            LocationTypes  = $GameData.locations | Group-Object type | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } }
            TotalPoints    = ($GameData.locations | Where-Object { $_.points } | Measure-Object points -Sum).Sum
            AveragePoints  = if ($GameData.locations.Count -gt 0) {
                [math]::Round(($GameData.locations | Where-Object { $_.points } | Measure-Object points -Average).Average, 2)
            }
            else { 0 }
        }

        return $stats
    }
    catch {
        Write-Warning "Error calculating game statistics: $($_.Exception.Message)"
        return @{
            error          = $_.Exception.Message
            TotalLocations = 0
        }
    }
}

# Internal function to find nearby locations (simplified)
function Find-NearbyLocationsInternal {
    param(
        [object]$GameData,
        [double]$Latitude,
        [double]$Longitude,
        [double]$RadiusKm = 5
    )

    if (-not $GameData -or -not $GameData.locations) {
        return @()
    }

    try {
        $nearbyLocations = @()

        foreach ($location in $GameData.locations) {
            if ($location.lat -and $location.lng) {
                # Simplified distance calculation (not accurate but good for demo)
                $latDiff = [math]::Abs($location.lat - $Latitude)
                $lngDiff = [math]::Abs($location.lng - $Longitude)
                $distance = [math]::Sqrt(($latDiff * $latDiff) + ($lngDiff * $lngDiff)) * 111 # Rough km conversion

                if ($distance -le $RadiusKm) {
                    $nearbyLocations = @($nearbyLocations)
                    $nearbyLocations += @{
                        Location = $location
                        Distance = [math]::Round($distance, 2)
                    }
                }
            }
        }

        return $nearbyLocations | Sort-Object Distance
    }
    catch {
        Write-Warning "Error finding nearby locations: $($_.Exception.Message)"
        return @()
    }
}

# Start event processing loop
function Start-EventProcessing {
    param([int]$IntervalSeconds = 1)

    Write-Host "Starting event processing loop (interval: $($IntervalSeconds) seconds)" -ForegroundColor Green

    while ($true) {
        try {
            # Process commands from JavaScript
            Process-JavaScriptCommands

            # Clear processed events for JavaScript
            $script:EventQueue = @()

            Start-Sleep -Seconds $IntervalSeconds
        }
        catch {
            Write-Error "Error in event processing loop: $($_.Exception.Message)"
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
}

# Get event statistics
function Get-EventStatistics {
    return @{
        TotalEventsLogged  = $script:EventLog.Count
        RegisteredHandlers = $script:EventHandlers.Keys.Count
        QueuedEvents       = $script:EventQueue.Count
        EventTypes         = $script:EventLog | Group-Object type | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } }
        RecentEvents       = $script:EventLog | Select-Object -Last 10
    }
}

# Export functions for external use
Export-ModuleMember -Function @(
    'Initialize-EventSystem',
    'Register-GameEvent',
    'Invoke-GameEvent',
    'Get-GameEvent',
    'Send-GameEvent',
    'Process-JavaScriptCommands',
    'Start-EventProcessing',
    'Get-EventStatistics'
)
