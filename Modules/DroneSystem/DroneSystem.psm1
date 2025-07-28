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
        $this.LastUpdate = Get-Date
        $this.OwnerFaction = "Neutral"

        # Initialize drone-specific properties
        $this.Properties["MaxRange"] = 1000
        $this.Properties["ScanRadius"] = 50
        $this.Properties["MovementSpeed"] = 25
    }

    [void] UpdatePosition([double]$X, [double]$Y, [double]$Z) {
        $this.Position.X = $X
        $this.Position.Y = $Y
        $this.Position.Z = $Z
        $this.LastUpdate = Get-Date
    }

    [hashtable] PerformScan() {
        if ($this.BatteryLevel -lt 10) {
            return @{
                Success = $false
                Error = "Insufficient battery for scan operation"
                BatteryLevel = $this.BatteryLevel
            }
        }

        # Simulate battery drain for scan
        $this.BatteryLevel -= 5
        $this.LastUpdate = Get-Date

        # Simulate scan results
        return @{
            Success = $true
            ScanData = @{
                Position = $this.Position
                ScanRadius = $this.Properties["ScanRadius"]
                DetectedEntities = @()  # Would be populated with actual scan results
                Timestamp = Get-Date
            }
            BatteryLevel = $this.BatteryLevel
        }
    }

    [void] SetMission([string]$Mission) {
        $this.Mission = $Mission
        $this.LastUpdate = Get-Date
    }

    [void] ChargeBattery([double]$Amount = 25) {
        $this.BatteryLevel = [Math]::Min(100, $this.BatteryLevel + $Amount)
        $this.LastUpdate = Get-Date
    }
}

# DroneSystem module implementation using function-based approach
function New-DroneSystem {
    $droneSystem = New-Object PSObject -Property @{
        ModuleName = "DroneSystem"
        Version = "1.0.0"
        Dependencies = @{
            "FactionSystem" = "1.0.0"
            "WorldSystem" = "1.0.0"
        }
        Capabilities = @{
            "DroneManagement" = $true
            "AreaScanning" = $true
            "Reconnaissance" = $true
            "AutoPilot" = $true
        }
        MessageBus = $null
        Config = @{}
        IsInitialized = $false
        LastActivity = Get-Date
        Drones = @{}
        MissionQueue = @{}
        ScanResults = @{}
        UpdateTimer = $null
    }

    # Initialize method
    $droneSystem | Add-Member -MemberType ScriptMethod -Name "Initialize" -Value {
        param([object]$MessageBus, [hashtable]$Config)

        $this.MessageBus = $MessageBus
        $this.Config = $Config
        $this.IsInitialized = $true
        $this.LastActivity = Get-Date

        # Subscribe to relevant events
        $this.MessageBus.Subscribe($this.ModuleName, "PlayerPositionUpdate", {
            param($Message)
            $Global:DroneSystemInstance.HandlePlayerPositionUpdate($Message.Data)
        })

        $this.MessageBus.Subscribe($this.ModuleName, "FactionUpdate", {
            param($Message)
            $Global:DroneSystemInstance.HandleFactionUpdate($Message.Data)
        })

        $this.MessageBus.Subscribe($this.ModuleName, "WorldStateChange", {
            param($Message)
            $Global:DroneSystemInstance.HandleWorldStateChange($Message.Data)
        })

        # Start drone update timer
        $this.StartDroneUpdates()

        Write-Host "DroneSystem initialized with capabilities: $($this.Capabilities.Keys -join ', ')" -ForegroundColor Green

        return @{
            Success = $true
            Message = "Module $($this.ModuleName) initialized successfully"
            Timestamp = Get-Date
        }
    }

    # HandleMessage method
    $droneSystem | Add-Member -MemberType ScriptMethod -Name "HandleMessage" -Value {
        param([string]$Action, [object]$Data, [string]$Source)

        $this.LastActivity = Get-Date

        switch ($Action) {
            "CreateDrone" {
                return $this.CreateDrone($Data.Id, $Data.Name, $Data.DroneType, $Data.OwnerFaction)
            }
            "GetDrone" {
                return $this.GetDrone($Data.DroneId)
            }
            "GetAllDrones" {
                return $this.GetAllDrones($Data.FactionFilter)
            }
            "MoveDrone" {
                return $this.MoveDrone($Data.DroneId, $Data.Position)
            }
            "ScanArea" {
                return $this.ScanArea($Data.DroneId, $Data.TargetPosition)
            }
            "SetDroneMission" {
                return $this.SetDroneMission($Data.DroneId, $Data.Mission)
            }
            "GetScanResults" {
                return $this.GetScanResults($Data.DroneId)
            }
            "ChargeDrone" {
                return $this.ChargeDrone($Data.DroneId, $Data.Amount)
            }
            "GetDronesByFaction" {
                return $this.GetDronesByFaction($Data.Faction)
            }
            "GetStatus" {
                return $this.GetStatus()
            }
            "GetCapabilities" {
                return $this.GetCapabilities()
            }
            "UpdateConfiguration" {
                return $this.UpdateConfiguration($Data)
            }
            default {
                throw "Unknown action: $Action"
            }
        }
    }

    # GetStatus method
    $droneSystem | Add-Member -MemberType ScriptMethod -Name "GetStatus" -Value {
        return @{
            ModuleName = $this.ModuleName
            Version = $this.Version
            IsInitialized = $this.IsInitialized
            LastActivity = $this.LastActivity
            Capabilities = $this.Capabilities
            Dependencies = $this.Dependencies
            DroneCount = $this.Drones.Count
            ActiveMissions = $this.MissionQueue.Count
        }
    }

    # GetCapabilities method
    $droneSystem | Add-Member -MemberType ScriptMethod -Name "GetCapabilities" -Value {
        return $this.Capabilities
    }

    # UpdateConfiguration method
    $droneSystem | Add-Member -MemberType ScriptMethod -Name "UpdateConfiguration" -Value {
        param([hashtable]$NewConfig)

        foreach ($key in $NewConfig.Keys) {
            $this.Config[$key] = $NewConfig[$key]
        }

        return @{
            Success = $true
            Message = "Configuration updated"
            Config = $this.Config
        }
    }

    # ValidateDependencies method
    $droneSystem | Add-Member -MemberType ScriptMethod -Name "ValidateDependencies" -Value {
        $result = @{
            IsValid = $true
            MissingDependencies = @()
            Errors = @()
        }

        foreach ($dependency in $this.Dependencies.Keys) {
            if (-not $this.MessageBus.IsModuleRegistered($dependency)) {
                $result.IsValid = $false
                $result.MissingDependencies += $dependency
                $result.Errors += "Missing dependency: $dependency"
            }
        }

        return $result
    }

    # Shutdown method
    $droneSystem | Add-Member -MemberType ScriptMethod -Name "Shutdown" -Value {
        # Stop update timer
        if ($this.UpdateTimer) {
            $this.UpdateTimer.Stop()
            $this.UpdateTimer.Dispose()
        }

        # Land all drones
        foreach ($droneId in $this.Drones.Keys) {
            $drone = $this.Drones[$droneId]
            $drone.Mission = "Shutdown"
        }

        $this.IsInitialized = $false

        return @{
            Success = $true
            Message = "Module $($this.ModuleName) shutdown completed"
            Timestamp = Get-Date
        }
    }

    # CreateDrone method
    $droneSystem | Add-Member -MemberType ScriptMethod -Name "CreateDrone" -Value {
        param([string]$Id, [string]$Name, [string]$DroneType, [string]$OwnerFaction)

        if ($this.Drones.ContainsKey($Id)) {
            return @{
                Success = $false
                Error = "Drone with ID $Id already exists"
            }
        }

        try {
            $drone = [Drone]::new($Id, $Name, $DroneType)
            $drone.OwnerFaction = $OwnerFaction

            $this.Drones[$Id] = $drone

            # Notify other systems about new drone
            $this.MessageBus.Publish("DroneCreated", @{
                DroneId = $Id
                DroneType = $DroneType
                OwnerFaction = $OwnerFaction
                Position = $drone.Position
            }, $this.ModuleName, 2)

            return @{
                Success = $true
                Drone = $drone.ToHashtable()
                Message = "Drone $Name created successfully"
            }
        }
        catch {
            return @{
                Success = $false
                Error = "Failed to create drone: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] CreateDrone([string]$Id, [string]$Name, [string]$DroneType, [string]$OwnerFaction) {
        if ($this.Drones.ContainsKey($Id)) {
            return @{
                Success = $false
                Error = "Drone with ID $Id already exists"
            }
        }

        try {
            $drone = [Drone]::new($Id, $Name, $DroneType)
            $drone.OwnerFaction = $OwnerFaction

            $this.Drones[$Id] = $drone

            # Notify other systems about new drone
            $this.MessageBus.Publish("DroneCreated", @{
                DroneId = $Id
                DroneType = $DroneType
                OwnerFaction = $OwnerFaction
                Position = $drone.Position
            }, $this.ModuleName, 2)

            return @{
                Success = $true
                Drone = $drone.ToHashtable()
                Message = "Drone $Name created successfully"
            }
        }
        catch {
            return @{
                Success = $false
                Error = "Failed to create drone: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] GetDrone([string]$DroneId) {
        if ($this.Drones.ContainsKey($DroneId)) {
            return @{
                Success = $true
                Drone = $this.Drones[$DroneId].ToHashtable()
            }
        }

        return @{
            Success = $false
            Error = "Drone $DroneId not found"
        }
    }

    [hashtable] GetAllDrones([string]$FactionFilter = "") {
        $drones = @()

        foreach ($drone in $this.Drones.Values) {
            if ([string]::IsNullOrEmpty($FactionFilter) -or $drone.OwnerFaction -eq $FactionFilter) {
                $drones += $drone.ToHashtable()
            }
        }

        return @{
            Success = $true
            Drones = $drones
            Count = $drones.Count
        }
    }

    [hashtable] MoveDrone([string]$DroneId, [hashtable]$Position) {
        if (-not $this.Drones.ContainsKey($DroneId)) {
            return @{
                Success = $false
                Error = "Drone $DroneId not found"
            }
        }

        try {
            $drone = $this.Drones[$DroneId]

            # Check if drone has enough battery for movement
            $distance = $this.CalculateDistance($drone.Position, $Position)
            $energyRequired = $distance * 0.1  # Energy cost per unit distance

            if ($drone.BatteryLevel -lt $energyRequired) {
                return @{
                    Success = $false
                    Error = "Insufficient battery for movement"
                    RequiredEnergy = $energyRequired
                    CurrentBattery = $drone.BatteryLevel
                }
            }

            # Update drone position
            $drone.UpdatePosition($Position.X, $Position.Y, $Position.Z)
            $drone.BatteryLevel -= $energyRequired

            # Notify other systems about drone movement
            $this.MessageBus.Publish("DroneMoved", @{
                DroneId = $DroneId
                OldPosition = $drone.Position
                NewPosition = $Position
                BatteryLevel = $drone.BatteryLevel
            }, $this.ModuleName, 2)

            return @{
                Success = $true
                NewPosition = $drone.Position
                BatteryLevel = $drone.BatteryLevel
                DistanceTraveled = $distance
            }
        }
        catch {
            return @{
                Success = $false
                Error = "Failed to move drone: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] ScanArea([string]$DroneId, [hashtable]$TargetPosition = @{}) {
        if (-not $this.Drones.ContainsKey($DroneId)) {
            return @{
                Success = $false
                Error = "Drone $DroneId not found"
            }
        }

        try {
            $drone = $this.Drones[$DroneId]
            $scanResult = $drone.PerformScan()

            if ($scanResult.Success) {
                # Store scan results
                $scanId = [System.Guid]::NewGuid().ToString()
                $this.ScanResults[$scanId] = $scanResult.ScanData

                # Request world data for scan area
                $worldData = $this.MessageBus.SendMessage("WorldSystem", "GetAreaData", @{
                    Position = $drone.Position
                    Radius = $drone.Properties["ScanRadius"]
                })

                if ($worldData.Success) {
                    $scanResult.ScanData.DetectedEntities = $worldData.Entities
                    $scanResult.ScanData.TerrainData = $worldData.TerrainData
                }

                # Notify other systems about scan
                $this.MessageBus.Publish("AreaScanned", @{
                    DroneId = $DroneId
                    ScanId = $scanId
                    Position = $drone.Position
                    ScanData = $scanResult.ScanData
                }, $this.ModuleName, 1)  # High priority for scan results

                $scanResult.ScanId = $scanId
            }

            return $scanResult
        }
        catch {
            return @{
                Success = $false
                Error = "Failed to perform scan: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] SetDroneMission([string]$DroneId, [string]$Mission) {
        if (-not $this.Drones.ContainsKey($DroneId)) {
            return @{
                Success = $false
                Error = "Drone $DroneId not found"
            }
        }

        try {
            $drone = $this.Drones[$DroneId]
            $oldMission = $drone.Mission
            $drone.SetMission($Mission)

            # Add mission to queue for processing
            $this.MissionQueue[$DroneId] = @{
                Mission = $Mission
                StartTime = Get-Date
                Status = "Active"
            }

            # Notify other systems about mission change
            $this.MessageBus.Publish("DroneMissionChanged", @{
                DroneId = $DroneId
                OldMission = $oldMission
                NewMission = $Mission
                Timestamp = Get-Date
            }, $this.ModuleName, 2)

            return @{
                Success = $true
                Message = "Mission set to: $Mission"
                DroneStatus = $drone.Status
            }
        }
        catch {
            return @{
                Success = $false
                Error = "Failed to set mission: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] GetScanResults([string]$DroneId) {
        $results = @()

        foreach ($scanId in $this.ScanResults.Keys) {
            $scanData = $this.ScanResults[$scanId]
            if ($scanData.DroneId -eq $DroneId) {
                $results += @{
                    ScanId = $scanId
                    ScanData = $scanData
                }
            }
        }

        return @{
            Success = $true
            ScanResults = $results
            Count = $results.Count
        }
    }

    [hashtable] ChargeDrone([string]$DroneId, [double]$Amount = 25) {
        if (-not $this.Drones.ContainsKey($DroneId)) {
            return @{
                Success = $false
                Error = "Drone $DroneId not found"
            }
        }

        try {
            $drone = $this.Drones[$DroneId]
            $oldBattery = $drone.BatteryLevel
            $drone.ChargeBattery($Amount)

            return @{
                Success = $true
                OldBatteryLevel = $oldBattery
                NewBatteryLevel = $drone.BatteryLevel
                ChargeAmount = $Amount
            }
        }
        catch {
            return @{
                Success = $false
                Error = "Failed to charge drone: $($_.Exception.Message)"
            }
        }
    }

    [hashtable] GetDronesByFaction([string]$Faction) {
        return $this.GetAllDrones($Faction)
    }

    # Event handlers
    [void] HandlePlayerPositionUpdate([hashtable]$Data) {
        # Check if any drones should respond to player movement
        foreach ($drone in $this.Drones.Values) {
            if ($drone.Mission -eq "FollowPlayer" -or $drone.Mission -eq "PatrolPlayer") {
                $distance = $this.CalculateDistance($drone.Position, $Data.Position)

                if ($distance -gt 100) {  # If drone is too far from player
                    # Move drone closer to player
                    $this.MoveDrone($drone.Id, $Data.Position)
                }
            }
        }
    }

    [void] HandleFactionUpdate([hashtable]$Data) {
        # Update drone ownership if faction changes affect them
        if ($Data.Action -eq "FactionDestroyed") {
            foreach ($drone in $this.Drones.Values) {
                if ($drone.OwnerFaction -eq $Data.FactionId) {
                    $drone.OwnerFaction = "Neutral"
                    $drone.SetMission("Idle")
                }
            }
        }
    }

    [void] HandleWorldStateChange([hashtable]$Data) {
        # Respond to world changes that might affect drone operations
        if ($Data.ChangeType -eq "WeatherChange" -and $Data.Weather -eq "Storm") {
            # Ground all drones during storms
            foreach ($drone in $this.Drones.Values) {
                if ($drone.Mission -ne "Docked") {
                    $drone.SetMission("Emergency-Landing")
                }
            }
        }
    }

    # Utility methods
    [double] CalculateDistance([hashtable]$Position1, [hashtable]$Position2) {
        $dx = $Position2.X - $Position1.X
        $dy = $Position2.Y - $Position1.Y
        $dz = $Position2.Z - $Position1.Z

        return [Math]::Sqrt($dx * $dx + $dy * $dy + $dz * $dz)
    }

    [void] StartDroneUpdates() {
        # Create timer for periodic drone updates
        $this.UpdateTimer = New-Object System.Timers.Timer
        $this.UpdateTimer.Interval = 5000  # 5 seconds
        $this.UpdateTimer.AutoReset = $true

        Register-ObjectEvent -InputObject $this.UpdateTimer -EventName Elapsed -Action {
            try {
                $Global:DroneSystem.UpdateAllDrones()
            }
            catch {
                Write-Error "Error in drone update timer: $($_.Exception.Message)"
            }
        } | Out-Null

        $this.UpdateTimer.Start()
    }

    [void] UpdateAllDrones() {
        foreach ($drone in $this.Drones.Values) {
            # Update drone based on current mission
            switch ($drone.Mission) {
                "Patrol" {
                    # Simulate patrol behavior
                    if ($drone.BatteryLevel -gt 20) {
                        # Continue patrol
                        $drone.BatteryLevel -= 1
                    } else {
                        $drone.SetMission("ReturnToBase")
                    }
                }
                "Scan" {
                    # Perform periodic scans
                    if ($drone.BatteryLevel -gt 15) {
                        $this.ScanArea($drone.Id)
                    } else {
                        $drone.SetMission("ReturnToBase")
                    }
                }
                "ReturnToBase" {
                    # Simulate returning to base for charging
                    $drone.ChargeBattery(10)
                    if ($drone.BatteryLevel -ge 80) {
                        $drone.SetMission("Idle")
                    }
                }
            }
        }
    }

    [hashtable] Shutdown() {
        # Stop update timer
        if ($this.UpdateTimer) {
            $this.UpdateTimer.Stop()
            $this.UpdateTimer.Dispose()
        }

        # Land all drones
        foreach ($drone in $this.Drones.Values) {
            $drone.SetMission("Shutdown")
        }

        return ([IGameModule]$this).Shutdown()
    }
}

# Create and export module instance
function New-DroneSystem {
    return [DroneSystem]::new()
}

# Export module functions
Export-ModuleMember -Function @('New-DroneSystem') -Variable @('DroneSystem', 'Drone')
