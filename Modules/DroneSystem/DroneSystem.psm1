# PowerShell Leafmap Game - Drone System Module
# Example implementation showing command registration with the Communication Bridge

using namespace System.Collections.Generic

# Import required modules
Import-Module (Join-Path $PSScriptRoot "..\CoreGame\CommandRegistry.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\CoreGame\EventSystem.psm1") -Force

# Module configuration
$script:DroneSystemConfig = @{
    MaxDrones = 10
    DefaultSpeed = 50
    MaxRange = 1000
    EnergyConsumptionRate = 5
    ScanRadius = 100
}

# Module state
$script:DroneSystemState = @{
    ActiveDrones = @{}
    DroneCounter = 0
    TotalFlightTime = 0
    MissionsCompleted = 0
}

# Drone class definition
class Drone {
    [string]$Id
    [string]$Name
    [hashtable]$Position
    [string]$Status
    [int]$Energy
    [int]$Speed
    [string]$Mission
    [datetime]$DeployedAt
    [hashtable]$Metadata

    Drone([string]$Name) {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Name = $Name
        $this.Position = @{ X = 0; Y = 0; Z = 100 }
        $this.Status = "Idle"
        $this.Energy = 100
        $this.Speed = $script:DroneSystemConfig.DefaultSpeed
        $this.Mission = "None"
        $this.DeployedAt = Get-Date
        $this.Metadata = @{}
    }

    [void] MoveTo([hashtable]$NewPosition) {
        $distance = [Math]::Sqrt(
            [Math]::Pow($NewPosition.X - $this.Position.X, 2) +
            [Math]::Pow($NewPosition.Y - $this.Position.Y, 2)
        )

        $energyCost = [Math]::Ceiling($distance / 100 * $script:DroneSystemConfig.EnergyConsumptionRate)

        if ($this.Energy -ge $energyCost) {
            $this.Position = $NewPosition
            $this.Energy -= $energyCost
            $this.Status = "Moving"

            Publish-GameEvent -EventType "drone.moved" -Data @{
                DroneId = $this.Id
                DroneName = $this.Name
                NewPosition = $this.Position
                EnergyRemaining = $this.Energy
                Distance = $distance
            }
        } else {
            throw "Insufficient energy for movement. Required: $energyCost, Available: $($this.Energy)"
        }
    }

    [hashtable] Scan() {
        if ($this.Energy -lt 10) {
            throw "Insufficient energy for scanning. Required: 10, Available: $($this.Energy)"
        }

        $this.Energy -= 10
        $this.Status = "Scanning"

        # Simulate scan results
        $scanResults = @{
            Timestamp = Get-Date
            Position = $this.Position
            Radius = $script:DroneSystemConfig.ScanRadius
            Discoveries = @()
        }

        # Random discoveries for demo
        $discoveryTypes = @("Resource", "Enemy", "Structure", "Anomaly")
        $discoveryCount = Get-Random -Minimum 0 -Maximum 4

        for ($i = 0; $i -lt $discoveryCount; $i++) {
            $scanResults.Discoveries += @{
                Type = $discoveryTypes[(Get-Random -Minimum 0 -Maximum $discoveryTypes.Length)]
                Distance = Get-Random -Minimum 10 -Maximum $script:DroneSystemConfig.ScanRadius
                Confidence = Get-Random -Minimum 60 -Maximum 100
            }
        }

        Publish-GameEvent -EventType "drone.scan_completed" -Data @{
            DroneId = $this.Id
            DroneName = $this.Name
            ScanResults = $scanResults
            EnergyRemaining = $this.Energy
        }

        return $scanResults
    }

    [void] SetMission([string]$MissionType, [hashtable]$MissionData = @{}) {
        $this.Mission = $MissionType
        $this.Status = "On Mission"
        $this.Metadata.MissionData = $MissionData

        Publish-GameEvent -EventType "drone.mission_assigned" -Data @{
            DroneId = $this.Id
            DroneName = $this.Name
            Mission = $MissionType
            MissionData = $MissionData
        }
    }

    [hashtable] GetStatus() {
        return @{
            Id = $this.Id
            Name = $this.Name
            Position = $this.Position
            Status = $this.Status
            Energy = $this.Energy
            Speed = $this.Speed
            Mission = $this.Mission
            DeployedAt = $this.DeployedAt
            Uptime = ((Get-Date) - $this.DeployedAt).TotalMinutes
            Metadata = $this.Metadata
        }
    }
}

# Register drone system commands
function Register-DroneSystemCommands {
    if (-not $script:GlobalCommandRegistry) {
        Write-Warning "Command Registry not available. Drone commands will not be registered."
        return
    }

    Write-Host "Registering Drone System commands..." -ForegroundColor Cyan

    # Launch Drone Command
    $launchDroneCmd = New-CommandDefinition -Name "launch" -Module "drone" -Handler {
        param($Parameters, $Context)

        $droneName = if ($Parameters.Name) { $Parameters.Name } else { "Drone-$($script:DroneSystemState.DroneCounter + 1)" }

        if ($script:DroneSystemState.ActiveDrones.Count -ge $script:DroneSystemConfig.MaxDrones) {
            throw "Maximum drone limit reached ($($script:DroneSystemConfig.MaxDrones))"
        }

        $drone = [Drone]::new($droneName)

        if ($Parameters.Position) {
            $drone.Position = $Parameters.Position
        }

        if ($Parameters.Speed) {
            $drone.Speed = [Math]::Min($Parameters.Speed, 200)  # Max speed limit
        }

        $script:DroneSystemState.ActiveDrones[$drone.Id] = $drone
        $script:DroneSystemState.DroneCounter++

        Publish-GameEvent -EventType "drone.launched" -Data @{
            DroneId = $drone.Id
            DroneName = $drone.Name
            Position = $drone.Position
            TotalDrones = $script:DroneSystemState.ActiveDrones.Count
        }

        return $drone.GetStatus()
    } -Description "Launch a new drone" -Category "Deployment"

    $launchDroneCmd.AddParameter((New-CommandParameter -Name "Name" -Type ([ParameterType]::String) -Description "Custom name for the drone"))
    $launchDroneCmd.AddParameter((New-CommandParameter -Name "Position" -Type ([ParameterType]::Object) -Description "Initial position {X, Y, Z}"))
    $launchDroneCmd.AddParameter((New-CommandParameter -Name "Speed" -Type ([ParameterType]::Integer) -Description "Drone speed (1-200)").AddConstraint(
        (New-ParameterConstraint -Type ([ConstraintType]::MinValue) -Value 1 -ErrorMessage "Speed must be at least 1")
    ).AddConstraint(
        (New-ParameterConstraint -Type ([ConstraintType]::MaxValue) -Value 200 -ErrorMessage "Speed cannot exceed 200")
    ))

    $launchDroneCmd.AddExample("BasicLaunch", @{
        Description = "Launch a basic drone"
        Parameters = @{}
        ExpectedResult = "Drone status object"
    })

    $launchDroneCmd.AddExample("CustomLaunch", @{
        Description = "Launch a drone with custom settings"
        Parameters = @{
            Name = "Scout-Alpha"
            Position = @{ X = 100; Y = 50; Z = 120 }
            Speed = 75
        }
        ExpectedResult = "Drone status object with custom settings"
    })

    Register-GameCommand -Command $launchDroneCmd

    # Move Drone Command
    $moveDroneCmd = New-CommandDefinition -Name "move" -Module "drone" -Handler {
        param($Parameters, $Context)

        if (-not $Parameters.DroneId) {
            throw "DroneId parameter is required"
        }

        if (-not $Parameters.Position) {
            throw "Position parameter is required"
        }

        $drone = $script:DroneSystemState.ActiveDrones[$Parameters.DroneId]
        if (-not $drone) {
            throw "Drone not found: $($Parameters.DroneId)"
        }

        $drone.MoveTo($Parameters.Position)

        return @{
            Success = $true
            DroneId = $drone.Id
            NewPosition = $drone.Position
            EnergyRemaining = $drone.Energy
        }
    } -Description "Move a drone to a new position" -Category "Navigation"

    $moveDroneCmd.AddParameter((New-CommandParameter -Name "DroneId" -Type ([ParameterType]::String) -Required $true -Description "ID of the drone to move"))
    $moveDroneCmd.AddParameter((New-CommandParameter -Name "Position" -Type ([ParameterType]::Object) -Required $true -Description "Target position {X, Y, Z}"))

    $moveDroneCmd.AddExample("MoveToLocation", @{
        Description = "Move drone to specific coordinates"
        Parameters = @{
            DroneId = "drone-id-here"
            Position = @{ X = 200; Y = 150; Z = 100 }
        }
        ExpectedResult = "Movement confirmation with energy usage"
    })

    Register-GameCommand -Command $moveDroneCmd

    # Scan Area Command
    $scanCmd = New-CommandDefinition -Name "scan" -Module "drone" -Handler {
        param($Parameters, $Context)

        if (-not $Parameters.DroneId) {
            throw "DroneId parameter is required"
        }

        $drone = $script:DroneSystemState.ActiveDrones[$Parameters.DroneId]
        if (-not $drone) {
            throw "Drone not found: $($Parameters.DroneId)"
        }

        return $drone.Scan()
    } -Description "Perform area scan with a drone" -Category "Reconnaissance"

    $scanCmd.AddParameter((New-CommandParameter -Name "DroneId" -Type ([ParameterType]::String) -Required $true -Description "ID of the drone to perform scan"))

    Register-GameCommand -Command $scanCmd

    # List Drones Command
    $listDronesCmd = New-CommandDefinition -Name "list" -Module "drone" -Handler {
        param($Parameters, $Context)

        $droneList = @()
        foreach ($drone in $script:DroneSystemState.ActiveDrones.Values) {
            $status = $drone.GetStatus()
            if ($Parameters.Status -and $status.Status -ne $Parameters.Status) {
                continue
            }
            $droneList += $status
        }

        return @{
            Drones = $droneList
            TotalCount = $droneList.Count
            SystemStats = @{
                MaxDrones = $script:DroneSystemConfig.MaxDrones
                ActiveDrones = $script:DroneSystemState.ActiveDrones.Count
                TotalLaunched = $script:DroneSystemState.DroneCounter
                MissionsCompleted = $script:DroneSystemState.MissionsCompleted
            }
        }
    } -Description "List all active drones" -Category "Management"

    $listDronesCmd.AddParameter((New-CommandParameter -Name "Status" -Type ([ParameterType]::String) -Description "Filter by drone status"))

    Register-GameCommand -Command $listDronesCmd

    # Recall Drone Command
    $recallCmd = New-CommandDefinition -Name "recall" -Module "drone" -Handler {
        param($Parameters, $Context)

        if (-not $Parameters.DroneId) {
            throw "DroneId parameter is required"
        }

        $drone = $script:DroneSystemState.ActiveDrones[$Parameters.DroneId]
        if (-not $drone) {
            throw "Drone not found: $($Parameters.DroneId)"
        }

        # Remove drone from active list
        $script:DroneSystemState.ActiveDrones.Remove($Parameters.DroneId)

        if ($drone.Mission -ne "None") {
            $script:DroneSystemState.MissionsCompleted++
        }

        Publish-GameEvent -EventType "drone.recalled" -Data @{
            DroneId = $drone.Id
            DroneName = $drone.Name
            FlightTime = ((Get-Date) - $drone.DeployedAt).TotalMinutes
            RemainingEnergy = $drone.Energy
            TotalDrones = $script:DroneSystemState.ActiveDrones.Count
        }

        return @{
            Success = $true
            DroneId = $drone.Id
            FlightTime = ((Get-Date) - $drone.DeployedAt).TotalMinutes
            RemainingEnergy = $drone.Energy
        }
    } -Description "Recall a drone back to base" -Category "Management"

    $recallCmd.AddParameter((New-CommandParameter -Name "DroneId" -Type ([ParameterType]::String) -Required $true -Description "ID of the drone to recall"))

    Register-GameCommand -Command $recallCmd

    # Set Mission Command
    $setMissionCmd = New-CommandDefinition -Name "setMission" -Module "drone" -Handler {
        param($Parameters, $Context)

        if (-not $Parameters.DroneId) {
            throw "DroneId parameter is required"
        }

        if (-not $Parameters.Mission) {
            throw "Mission parameter is required"
        }

        $drone = $script:DroneSystemState.ActiveDrones[$Parameters.DroneId]
        if (-not $drone) {
            throw "Drone not found: $($Parameters.DroneId)"
        }

        $drone.SetMission($Parameters.Mission, $Parameters.MissionData)

        return @{
            Success = $true
            DroneId = $drone.Id
            Mission = $Parameters.Mission
            Status = $drone.Status
        }
    } -Description "Assign a mission to a drone" -Category "Operations"

    $setMissionCmd.AddParameter((New-CommandParameter -Name "DroneId" -Type ([ParameterType]::String) -Required $true -Description "ID of the drone"))
    $setMissionCmd.AddParameter((New-CommandParameter -Name "Mission" -Type ([ParameterType]::String) -Required $true -Description "Mission type").AddConstraint(
        (New-ParameterConstraint -Type ([ConstraintType]::Enum) -Value @("Patrol", "Reconnaissance", "Escort", "Search", "Surveillance") -ErrorMessage "Invalid mission type")
    ))
    $setMissionCmd.AddParameter((New-CommandParameter -Name "MissionData" -Type ([ParameterType]::Object) -Description "Additional mission parameters"))

    Register-GameCommand -Command $setMissionCmd

    # Get System Status Command
    $getSystemStatusCmd = New-CommandDefinition -Name "getSystemStatus" -Module "drone" -Handler {
        param($Parameters, $Context)

        return @{
            Configuration = $script:DroneSystemConfig
            Statistics = $script:DroneSystemState
            ActiveDrones = $script:DroneSystemState.ActiveDrones.Count
            SystemHealth = @{
                Status = "Operational"
                Uptime = "Available"
                LastMaintenance = Get-Date -Format "yyyy-MM-dd"
            }
        }
    } -Description "Get drone system status and statistics" -Category "Diagnostics"

    Register-GameCommand -Command $getSystemStatusCmd

    Write-Host "✅ Drone System commands registered successfully!" -ForegroundColor Green
    Write-Host "Available commands: drone.launch, drone.move, drone.scan, drone.list, drone.recall, drone.setMission, drone.getSystemStatus" -ForegroundColor White
}

# Initialize the drone system
function Initialize-DroneSystem {
    param([hashtable]$Configuration = @{})

    try {
        # Merge configuration
        foreach ($key in $Configuration.Keys) {
            $script:DroneSystemConfig[$key] = $Configuration[$key]
        }

        # Register commands
        Register-DroneSystemCommands

        Write-Host "Drone System initialized successfully" -ForegroundColor Green

        return @{
            Success = $true
            Message = "Drone System initialized"
            Configuration = $script:DroneSystemConfig
            CommandsRegistered = 8
        }
    }
    catch {
        Write-Error "Failed to initialize Drone System: $($_.Exception.Message)"
        throw
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-DroneSystem',
    'Register-DroneSystemCommands'
)

# Module initialization message
Write-Host "DroneSystem module loaded. Call Initialize-DroneSystem to register commands." -ForegroundColor Cyan
