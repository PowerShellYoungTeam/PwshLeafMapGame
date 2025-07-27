# PowerShell Event System Module
# Provides event handling and communication with JavaScript frontend

# Event system configuration
$script:EventConfig = @{
    EventQueueFile = "events.json"
    CommandQueueFile = "commands.json"
    EventLogFile = "event_log.json"
    MaxEventLogSize = 1000
    ProcessingInterval = 1
}

# Event queue for JavaScript consumption
$script:EventQueue = @()

# Command queue from JavaScript
$script:CommandQueue = @()

# Event log for debugging and auditing
$script:EventLog = @()

# Registered event handlers
$script:EventHandlers = @{}

# Initialize the event system
function Initialize-EventSystem {
    param(
        [string]$GamePath = (Get-Location).Path
    )

    Write-Host "Initializing PowerShell Event System..." -ForegroundColor Green

    # Set up file paths
    $script:EventConfig.EventQueueFile = Join-Path $GamePath "events.json"
    $script:EventConfig.CommandQueueFile = Join-Path $GamePath "commands.json"
    $script:EventConfig.EventLogFile = Join-Path $GamePath "event_log.json"

    # Load existing event log
    if (Test-Path $script:EventConfig.EventLogFile) {
        try {
            $script:EventLog = Get-Content $script:EventConfig.EventLogFile -Raw | ConvertFrom-Json
            Write-Host "Loaded existing event log with $($script:EventLog.Count) events" -ForegroundColor Cyan
        } catch {
            Write-Warning "Could not load existing event log: $($_.Exception.Message)"
            $script:EventLog = @()
        }
    }

    # Register default event handlers
    Register-DefaultEventHandlers

    Write-Host "PowerShell Event System initialized" -ForegroundColor Green
}

# Register an event handler
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
        ScriptBlock = $ScriptBlock
        Priority = $Priority
        Once = $Once
        Id = (New-Guid).ToString()
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

# Emit an event for JavaScript consumption
function Send-GameEvent {
    param(
        [Parameter(Mandatory)]
        [string]$EventType,

        [object]$Data = @{},

        [string]$Source = "powershell",

        [switch]$ProcessLocally
    )

    $event = @{
        type = $EventType
        data = $Data
        timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fff')
        id = "ps_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(((New-Guid).ToString().Substring(0,8)))"
        source = $Source
    }

    # Add to event log
    Add-ToEventLog -Event $event

    # Process locally if handlers exist
    if ($ProcessLocally -or $script:EventHandlers.ContainsKey($EventType)) {
        Invoke-EventHandlers -Event $event
    }

    # Queue for JavaScript consumption
    $script:EventQueue = @($script:EventQueue)
    $script:EventQueue += $event

    # Save events to file for JavaScript to read
    Save-EventQueue

    Write-Host "Sent event: $($EventType)" -ForegroundColor Green
    return $event.id
}

# Process incoming commands from JavaScript
function Process-JavaScriptCommands {
    if (-not (Test-Path $script:EventConfig.CommandQueueFile)) {
        return
    }

    try {
        $commands = Get-Content $script:EventConfig.CommandQueueFile -Raw | ConvertFrom-Json

        if ($commands -and $commands.Count -gt 0) {
            Write-Host "Processing $($commands.Count) commands from JavaScript" -ForegroundColor Yellow

            foreach ($command in $commands) {
                Process-JavaScriptCommand -Command $command
            }

            # Clear processed commands
            @() | ConvertTo-Json | Set-Content $script:EventConfig.CommandQueueFile
        }
    } catch {
        Write-Warning "Error processing JavaScript commands: $($_.Exception.Message)"
    }
}

# Process a single command from JavaScript
function Process-JavaScriptCommand {
    param([object]$Command)

    Write-Host "Processing command: $($Command.type)" -ForegroundColor Cyan

    switch ($Command.type) {
        "powershell.generateLocations" {
            $result = Invoke-GenerateLocations -Parameters $Command.data
            Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                commandId = $Command.id
                commandType = "generateLocations"
                result = $result
                success = $true
            }
        }

        "powershell.saveProgress" {
            $result = Save-PlayerProgressInternal -PlayerName $Command.data.playerName -Progress $Command.data.progress
            Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                commandId = $Command.id
                commandType = "saveProgress"
                result = $result
                success = $true
            }
        }

        "powershell.loadProgress" {
            $result = Get-PlayerProgressInternal -PlayerName $Command.data.playerName
            Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                commandId = $Command.id
                commandType = "loadProgress"
                result = $result
                success = $true
            }
        }

        "powershell.calculateStats" {
            $result = Get-GameStatisticsInternal -GameData $Command.data.gameData
            Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                commandId = $Command.id
                commandType = "calculateStats"
                result = $result
                success = $true
            }
        }

        "powershell.findNearby" {
            $result = Find-NearbyLocationsInternal -GameData $Command.data.gameData -Latitude $Command.data.latitude -Longitude $Command.data.longitude -RadiusKm $Command.data.radius
            Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                commandId = $Command.id
                commandType = "findNearby"
                result = $result
                success = $true
            }
        }

        default {
            Write-Warning "Unknown command type: $($Command.type)"
            Send-GameEvent -EventType "powershell.commandCompleted" -Data @{
                commandId = $Command.id
                commandType = $Command.type
                error = "Unknown command type"
                success = $false
            }
        }
    }
}

# Invoke event handlers for an event
function Invoke-EventHandlers {
    param([object]$Event)

    $handlers = $script:EventHandlers[$Event.type]
    if (-not $handlers) {
        return
    }

    foreach ($handler in $handlers) {
        try {
            Write-Host "Executing handler for event: $($Event.type)" -ForegroundColor Gray
            & $handler.ScriptBlock $Event.data $Event

            # Remove handler if it's a one-time handler
            if ($handler.Once) {
                $script:EventHandlers[$Event.type] = $script:EventHandlers[$Event.type] | Where-Object { $_.Id -ne $handler.Id }
            }
        } catch {
            Write-Error "Error executing event handler for $($Event.type): $($_.Exception.Message)"

            # Send error event
            Send-GameEvent -EventType "system.error" -Data @{
                message = $_.Exception.Message
                eventType = $Event.type
                handlerId = $handler.Id
                source = "powershell"
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
            playerName = $Data.playerName
            createdAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
            level = 1
            experience = 0
            score = 0
            visitedLocations = @()
            inventory = @()
            achievements = @()
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
            playerId = $Data.playerId
            locationId = $Data.location.id
            locationName = $Data.location.name
            timestamp = $Event.timestamp
            points = $Data.location.points
            items = $Data.location.items
        }

        Add-ToVisitLog -Visit $visitLog

        # Send achievement check event
        Send-GameEvent -EventType "achievement.check" -Data @{
            playerId = $Data.playerId
            action = "locationVisit"
            locationId = $Data.location.id
        }
    }

    # System events
    Register-GameEvent -EventType "system.startup" -ScriptBlock {
        param($Data, $Event)
        Write-Host "Game system starting up..." -ForegroundColor Green

        # Perform startup tasks
        Send-GameEvent -EventType "system.dataLoaded" -Data @{
            message = "System initialized"
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
    } catch {
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
        $script:EventLog = $script:EventLog[-$script:EventConfig.MaxEventLogSize..-1]
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
    } catch {
        Write-Warning "Failed to save event log: $($_.Exception.Message)"
    }
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
        } catch {
            Write-Warning "Could not load existing visit log"
        }
    }

    $visits += $Visit

    try {
        $visits | ConvertTo-Json -Depth 5 | Set-Content $visitLogFile
    } catch {
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
                    playerId = $PlayerId
                    achievementId = "first_visit"
                    title = "First Steps"
                    description = "Visited your first location"
                    points = 50
                }
            }

            # Explorer achievements
            if ($visitCount -eq 5) {
                Send-GameEvent -EventType "achievement.unlocked" -Data @{
                    playerId = $PlayerId
                    achievementId = "explorer"
                    title = "Explorer"
                    description = "Visited 5 locations"
                    points = 100
                }
            }

            if ($visitCount -eq 10) {
                Send-GameEvent -EventType "achievement.unlocked" -Data @{
                    playerId = $PlayerId
                    achievementId = "veteran_explorer"
                    title = "Veteran Explorer"
                    description = "Visited 10 locations"
                    points = 200
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
        } catch {
            Write-Warning "Could not load player progress for $($PlayerName): $($_.Exception.Message)"
        }
    }

    # Return new player data if file doesn't exist or couldn't be loaded
    return @{
        playerName = $PlayerName
        score = 0
        visitedLocations = @()
        inventory = @()
        achievements = @()
        startTime = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
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
    } catch {
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
                id = "generated_location_$($i)"
                lat = $lat
                lng = $lng
                name = "$($type) Location #$($i)"
                type = $type
                description = "A dynamically generated $($type) location"
                points = Get-Random -Minimum 25 -Maximum 150
                items = @("item_$($i)")
                discovered = $false
                timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
            }

            $locations = @($locations)
            $locations += $location
        }

        $result = @{
            generatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
            city = $city
            version = "1.0"
            locations = $locations
            metadata = @{
                totalLocations = $locationCount
                generator = "PowerShell Event System"
            }
        }

        Write-Host "Successfully generated $($locationCount) locations" -ForegroundColor Green
        return $result

    } catch {
        Write-Warning "Error generating locations: $($_.Exception.Message)"
        return @{
            error = $_.Exception.Message
            locations = @()
        }
    }
}

# Internal function to get game statistics (simplified)
function Get-GameStatisticsInternal {
    param([object]$GameData)

    if (-not $GameData -or -not $GameData.locations) {
        return @{
            error = "No game data provided"
            TotalLocations = 0
        }
    }

    try {
        $stats = @{
            TotalLocations = $GameData.locations.Count
            LocationTypes = $GameData.locations | Group-Object type | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } }
            TotalPoints = ($GameData.locations | Where-Object { $_.points } | Measure-Object points -Sum).Sum
            AveragePoints = if ($GameData.locations.Count -gt 0) {
                [math]::Round(($GameData.locations | Where-Object { $_.points } | Measure-Object points -Average).Average, 2)
            } else { 0 }
        }

        return $stats
    } catch {
        Write-Warning "Error calculating game statistics: $($_.Exception.Message)"
        return @{
            error = $_.Exception.Message
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
    } catch {
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
        } catch {
            Write-Error "Error in event processing loop: $($_.Exception.Message)"
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
}

# Get event statistics
function Get-EventStatistics {
    return @{
        TotalEventsLogged = $script:EventLog.Count
        RegisteredHandlers = $script:EventHandlers.Keys.Count
        QueuedEvents = $script:EventQueue.Count
        EventTypes = $script:EventLog | Group-Object type | ForEach-Object { @{ Type = $_.Name; Count = $_.Count } }
        RecentEvents = $script:EventLog | Select-Object -Last 10
    }
}

# Export functions for external use
Export-ModuleMember -Function @(
    'Initialize-EventSystem',
    'Register-GameEvent',
    'Send-GameEvent',
    'Process-JavaScriptCommands',
    'Start-EventProcessing',
    'Get-EventStatistics'
)
