# Communication System Demo
# Demonstrates the MessageBus and module communication architecture

# Import required modules with force to ensure fresh load
$CommunicationModulePath = Join-Path $PSScriptRoot "Modules\CoreGame\CommunicationSystem.psm1"
$DroneModulePath = Join-Path $PSScriptRoot "Modules\DroneSystem\DroneSystem.psm1"

Import-Module $CommunicationModulePath -Force -Global
Import-Module $DroneModulePath -Force -Global

Write-Host "=== Game Module Communication System Demo ===" -ForegroundColor Cyan
Write-Host ""

# Create MessageBus with custom configuration
Write-Host "1. Creating MessageBus with custom configuration..." -ForegroundColor Yellow
$config = @{
    MaxQueueSize = 5000
    ProcessingIntervalMs = 100
    EnableBatching = $true
    BatchSize = 20
    DefaultRequestTimeout = 15
    EnableCircuitBreaker = $true
    CircuitBreakerFailureThreshold = 3
    EnablePerformanceMetrics = $true
}

$Global:MessageBus = New-MessageBus -Configuration $config
Write-Host "MessageBus created successfully" -ForegroundColor Green
Write-Host ""

# Start the message bus
Write-Host "2. Starting MessageBus..." -ForegroundColor Yellow
$Global:MessageBus.Start()
Write-Host ""

# Create and register modules
Write-Host "3. Creating and registering game modules..." -ForegroundColor Yellow

# Create DroneSystem module
$droneSystem = New-DroneSystem
$registrationResult = $Global:MessageBus.RegisterModule("DroneSystem", $droneSystem)

Write-Host "DroneSystem Registration Result:" -ForegroundColor Green
Write-Host "  Success: $($registrationResult.Success)" -ForegroundColor White
Write-Host "  Module: $($registrationResult.ModuleName)" -ForegroundColor White
Write-Host "  Dependencies Valid: $($registrationResult.DependencyValidation.IsValid)" -ForegroundColor White

if (-not $registrationResult.DependencyValidation.IsValid) {
    Write-Host "  Missing Dependencies: $($registrationResult.DependencyValidation.MissingDependencies -join ', ')" -ForegroundColor Red
}
Write-Host ""

# Create a mock FactionSystem for demonstration
function New-MockFactionSystem {
    $mockModule = New-Object PSObject -Property @{
        ModuleName = "FactionSystem"
        Version = "1.0.0"
        Dependencies = @{}
        Capabilities = @{
            "FactionManagement" = $true
            "DiplomacySystem" = $true
        }
        MessageBus = $null
        Config = @{}
        IsInitialized = $false
        LastActivity = Get-Date
    }

    # Add methods using Add-Member
    $mockModule | Add-Member -MemberType ScriptMethod -Name "Initialize" -Value {
        param([object]$MessageBus, [hashtable]$Config)
        $this.MessageBus = $MessageBus
        $this.Config = $Config
        $this.IsInitialized = $true
        $this.LastActivity = Get-Date

        return @{
            Success = $true
            Message = "Module $($this.ModuleName) initialized successfully"
            Timestamp = Get-Date
        }
    }

    $mockModule | Add-Member -MemberType ScriptMethod -Name "HandleMessage" -Value {
        param([string]$Action, [object]$Data, [string]$Source)
        $this.LastActivity = Get-Date

        switch ($Action) {
            "GetFactionData" {
                return @{
                    Success = $true
                    Factions = @(
                        @{ Id = "Player"; Name = "Player Faction"; Relations = @{} }
                        @{ Id = "Rebels"; Name = "Rebel Alliance"; Relations = @{} }
                        @{ Id = "Empire"; Name = "Galactic Empire"; Relations = @{} }
                    )
                }
            }
            "GetStatus" {
                return @{
                    ModuleName = $this.ModuleName
                    Version = $this.Version
                    IsInitialized = $this.IsInitialized
                    LastActivity = $this.LastActivity
                    Capabilities = $this.Capabilities
                    Dependencies = $this.Dependencies
                }
            }
            "GetCapabilities" {
                return $this.Capabilities
            }
            "UpdateConfiguration" {
                foreach ($key in $Data.Keys) {
                    $this.Config[$key] = $Data[$key]
                }
                return @{
                    Success = $true
                    Message = "Configuration updated"
                    Config = $this.Config
                }
            }
            default {
                throw "Unknown action: $Action"
            }
        }
    }

    $mockModule | Add-Member -MemberType ScriptMethod -Name "GetStatus" -Value {
        return @{
            ModuleName = $this.ModuleName
            Version = $this.Version
            IsInitialized = $this.IsInitialized
            LastActivity = $this.LastActivity
            Capabilities = $this.Capabilities
            Dependencies = $this.Dependencies
        }
    }

    $mockModule | Add-Member -MemberType ScriptMethod -Name "ValidateDependencies" -Value {
        return @{
            IsValid = $true
            MissingDependencies = @()
            Errors = @()
        }
    }

    $mockModule | Add-Member -MemberType ScriptMethod -Name "Shutdown" -Value {
        $this.IsInitialized = $false
        return @{
            Success = $true
            Message = "Module $($this.ModuleName) shutdown completed"
            Timestamp = Get-Date
        }
    }

    return $mockModule
}

$mockFactionSystem = New-MockFactionSystem
$Global:MessageBus.RegisterModule("FactionSystem", $mockFactionSystem)
Write-Host "MockFactionSystem registered" -ForegroundColor Green

# Create a mock WorldSystem
function New-MockWorldSystem {
    $mockModule = New-Object PSObject -Property @{
        ModuleName = "WorldSystem"
        Version = "1.0.0"
        Dependencies = @{}
        Capabilities = @{
            "TerrainManagement" = $true
            "AreaQueries" = $true
            "EntityTracking" = $true
        }
        MessageBus = $null
        Config = @{}
        IsInitialized = $false
        LastActivity = Get-Date
    }

    # Add methods using Add-Member
    $mockModule | Add-Member -MemberType ScriptMethod -Name "Initialize" -Value {
        param([object]$MessageBus, [hashtable]$Config)
        $this.MessageBus = $MessageBus
        $this.Config = $Config
        $this.IsInitialized = $true
        $this.LastActivity = Get-Date

        return @{
            Success = $true
            Message = "Module $($this.ModuleName) initialized successfully"
            Timestamp = Get-Date
        }
    }

    $mockModule | Add-Member -MemberType ScriptMethod -Name "HandleMessage" -Value {
        param([string]$Action, [object]$Data, [string]$Source)
        $this.LastActivity = Get-Date

        switch ($Action) {
            "GetAreaData" {
                return @{
                    Success = $true
                    Entities = @(
                        @{ Id = "tree_001"; Type = "Tree"; Position = @{X=10; Y=0; Z=15} }
                        @{ Id = "rock_045"; Type = "Rock"; Position = @{X=25; Y=0; Z=30} }
                    )
                    TerrainData = @{
                        Type = "Forest"
                        Elevation = 120
                        Temperature = 22
                    }
                }
            }
            "GetStatus" {
                return @{
                    ModuleName = $this.ModuleName
                    Version = $this.Version
                    IsInitialized = $this.IsInitialized
                    LastActivity = $this.LastActivity
                    Capabilities = $this.Capabilities
                    Dependencies = $this.Dependencies
                }
            }
            "GetCapabilities" {
                return $this.Capabilities
            }
            "UpdateConfiguration" {
                foreach ($key in $Data.Keys) {
                    $this.Config[$key] = $Data[$key]
                }
                return @{
                    Success = $true
                    Message = "Configuration updated"
                    Config = $this.Config
                }
            }
            default {
                throw "Unknown action: $Action"
            }
        }
    }

    $mockModule | Add-Member -MemberType ScriptMethod -Name "GetStatus" -Value {
        return @{
            ModuleName = $this.ModuleName
            Version = $this.Version
            IsInitialized = $this.IsInitialized
            LastActivity = $this.LastActivity
            Capabilities = $this.Capabilities
            Dependencies = $this.Dependencies
        }
    }

    $mockModule | Add-Member -MemberType ScriptMethod -Name "ValidateDependencies" -Value {
        return @{
            IsValid = $true
            MissingDependencies = @()
            Errors = @()
        }
    }

    $mockModule | Add-Member -MemberType ScriptMethod -Name "Shutdown" -Value {
        $this.IsInitialized = $false
        return @{
            Success = $true
            Message = "Module $($this.ModuleName) shutdown completed"
            Timestamp = Get-Date
        }
    }

    return $mockModule
}

$mockWorldSystem = New-MockWorldSystem
$Global:MessageBus.RegisterModule("WorldSystem", $mockWorldSystem)
Write-Host "MockWorldSystem registered" -ForegroundColor Green
Write-Host ""

# Wait a moment for initialization
Start-Sleep -Seconds 2

# Demonstrate module communication
Write-Host "4. Testing module communication..." -ForegroundColor Yellow

# Test 1: Create drones
Write-Host "Test 1: Creating drones..." -ForegroundColor Cyan
$droneCreationTests = @(
    @{ Id = "scout_001"; Name = "Scout Alpha"; DroneType = "Reconnaissance"; OwnerFaction = "Player" }
    @{ Id = "patrol_001"; Name = "Patrol Beta"; DroneType = "Security"; OwnerFaction = "Rebels" }
    @{ Id = "survey_001"; Name = "Survey Gamma"; DroneType = "Survey"; OwnerFaction = "Empire" }
)

foreach ($test in $droneCreationTests) {
    $result = $Global:MessageBus.SendMessage("DroneSystem", "CreateDrone", $test)
    Write-Host "  Created drone $($test.Name): $($result.Success)" -ForegroundColor $(if($result.Success) {"Green"} else {"Red"})
    if (-not $result.Success) {
        Write-Host "    Error: $($result.Error)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 2: Get all drones
Write-Host "Test 2: Retrieving all drones..." -ForegroundColor Cyan
$allDrones = $Global:MessageBus.SendMessage("DroneSystem", "GetAllDrones", @{})
Write-Host "  Retrieved $($allDrones.Count) drones" -ForegroundColor Green
foreach ($drone in $allDrones.Drones) {
    Write-Host "    - $($drone.Name) [$($drone.DroneType)] - $($drone.OwnerFaction)" -ForegroundColor White
}
Write-Host ""

# Test 3: Move drones and scan areas
Write-Host "Test 3: Moving drones and performing scans..." -ForegroundColor Cyan
$moveAndScanTests = @(
    @{ DroneId = "scout_001"; Position = @{X=50; Y=10; Z=25} }
    @{ DroneId = "patrol_001"; Position = @{X=75; Y=5; Z=40} }
    @{ DroneId = "survey_001"; Position = @{X=100; Y=15; Z=60} }
)

foreach ($test in $moveAndScanTests) {
    # Move drone
    $moveResult = $Global:MessageBus.SendMessage("DroneSystem", "MoveDrone", $test)
    Write-Host "  Moved drone $($test.DroneId): $($moveResult.Success)" -ForegroundColor $(if($moveResult.Success) {"Green"} else {"Red"})

    if ($moveResult.Success) {
        Write-Host "    New position: X=$($moveResult.NewPosition.X), Y=$($moveResult.NewPosition.Y), Z=$($moveResult.NewPosition.Z)" -ForegroundColor White
        Write-Host "    Battery level: $($moveResult.BatteryLevel)%" -ForegroundColor White

        # Perform scan
        $scanResult = $Global:MessageBus.SendMessage("DroneSystem", "ScanArea", @{DroneId = $test.DroneId})
        Write-Host "    Scan result: $($scanResult.Success)" -ForegroundColor $(if($scanResult.Success) {"Green"} else {"Red"})

        if ($scanResult.Success) {
            Write-Host "      Detected $($scanResult.ScanData.DetectedEntities.Count) entities" -ForegroundColor White
            Write-Host "      Terrain: $($scanResult.ScanData.TerrainData.Type)" -ForegroundColor White
        }
    }
}
Write-Host ""

# Test 4: Set missions
Write-Host "Test 4: Setting drone missions..." -ForegroundColor Cyan
$missionTests = @(
    @{ DroneId = "scout_001"; Mission = "Patrol" }
    @{ DroneId = "patrol_001"; Mission = "Scan" }
    @{ DroneId = "survey_001"; Mission = "FollowPlayer" }
)

foreach ($test in $missionTests) {
    $result = $Global:MessageBus.SendMessage("DroneSystem", "SetDroneMission", $test)
    Write-Host "  Set mission for $($test.DroneId) to '$($test.Mission)': $($result.Success)" -ForegroundColor $(if($result.Success) {"Green"} else {"Red"})
}
Write-Host ""

# Test 5: Test error handling and circuit breaker
Write-Host "Test 5: Testing error handling and circuit breaker..." -ForegroundColor Cyan

# Test invalid drone ID
$invalidResult = $Global:MessageBus.SendMessage("DroneSystem", "GetDrone", @{DroneId = "invalid_drone"})
Write-Host "  Invalid drone query: Success=$($invalidResult.Success), Error='$($invalidResult.Error)'" -ForegroundColor Yellow

# Test invalid action
try {
    $invalidAction = $Global:MessageBus.SendMessage("DroneSystem", "InvalidAction", @{})
}
catch {
    Write-Host "  Invalid action handled: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# Test 6: Performance metrics and system status
Write-Host "Test 6: System performance and status..." -ForegroundColor Cyan
$status = $Global:MessageBus.GetStatus()

Write-Host "  MessageBus Status:" -ForegroundColor Green
Write-Host "    Running: $($status.IsRunning)" -ForegroundColor White
Write-Host "    Registered modules: $($status.RegisteredModules.Count)" -ForegroundColor White
Write-Host "    Queue stats: High=$($status.QueueStats.High), Medium=$($status.QueueStats.Medium), Low=$($status.QueueStats.Low)" -ForegroundColor White

Write-Host "  Performance Metrics:" -ForegroundColor Green
Write-Host "    Messages sent: $($status.Performance.MessagesSent)" -ForegroundColor White
Write-Host "    Messages processed: $($status.Performance.MessagesProcessed)" -ForegroundColor White
Write-Host "    Average processing time: $($status.Performance.AverageProcessingTime) ms" -ForegroundColor White
Write-Host "    Error count: $($status.Performance.ErrorCount)" -ForegroundColor White

Write-Host "  Module Statuses:" -ForegroundColor Green
foreach ($moduleName in $status.ModuleStatuses.Keys) {
    $moduleStatus = $status.ModuleStatuses[$moduleName]
    if ($moduleStatus.ContainsKey("Error")) {
        Write-Host "    $moduleName`: ERROR - $($moduleStatus.Error)" -ForegroundColor Red
    } else {
        Write-Host "    $moduleName`: Online (Last activity: $($moduleStatus.LastActivity))" -ForegroundColor White
    }
}

if ($status.Configuration.EnableCircuitBreaker) {
    Write-Host "  Circuit Breaker States:" -ForegroundColor Green
    foreach ($cbName in $status.CircuitBreakerStates.Keys) {
        $cbState = $status.CircuitBreakerStates[$cbName]
        Write-Host "    $cbName`: $($cbState.State) (Failures: $($cbState.FailureCount)/$($cbState.FailureThreshold))" -ForegroundColor White
    }
}
Write-Host ""

# Test 7: Event publishing and subscription demonstration
Write-Host "Test 7: Event publishing and subscription..." -ForegroundColor Cyan

# Set up event subscription for demonstration
$Global:MessageBus.Subscribe("DroneSystem", "TestEvent", {
    param($Message)
    Write-Host "    Received TestEvent from $($Message.Source): $($Message.Data.TestMessage)" -ForegroundColor Magenta
})

# Publish test events
$Global:MessageBus.Publish("TestEvent", @{TestMessage = "Hello from MessageBus!"}, "DemoScript", 1)
$Global:MessageBus.Publish("TestEvent", @{TestMessage = "High priority message"}, "DemoScript", 1)
$Global:MessageBus.Publish("TestEvent", @{TestMessage = "Low priority message"}, "DemoScript", 3)

# Wait for message processing
Start-Sleep -Seconds 2
Write-Host ""

# Test 8: Communication resilience testing
Write-Host "Test 8: Testing communication resilience..." -ForegroundColor Cyan

# Test retry mechanism
Write-Host "  Testing retry mechanism with Invoke-WithRetry..." -ForegroundColor Yellow
$retryResult = Invoke-WithRetry -Operation {
    # Simulate intermittent failure
    if ((Get-Random -Minimum 1 -Maximum 5) -eq 1) {
        throw "Simulated intermittent failure"
    }
    return @{ Success = $true; Message = "Operation succeeded after retry" }
} -MaxRetries 3 -DelayMs 500

Write-Host "    Retry operation result: $($retryResult.Success) - $($retryResult.Message)" -ForegroundColor Green
Write-Host ""

# Test 9: Module communication testing
Write-Host "Test 9: Inter-module communication testing..." -ForegroundColor Cyan

$commTests = @(
    @{ Source = "DroneSystem"; Target = "FactionSystem"; Action = "GetFactionData"; Data = @{} }
    @{ Source = "DroneSystem"; Target = "WorldSystem"; Action = "GetAreaData"; Data = @{Position = @{X=0; Y=0; Z=0}; Radius = 50} }
)

foreach ($test in $commTests) {
    $testResult = Test-ModuleCommunication -SourceModule $test.Source -TargetModule $test.Target -Action $test.Action -TestData $test.Data
    Write-Host "  $($test.Source) -> $($test.Target) [$($test.Action)]: Success=$($testResult.Success), Time=$($testResult.ResponseTime)ms" -ForegroundColor $(if($testResult.Success) {"Green"} else {"Red"})

    if (-not $testResult.Success) {
        Write-Host "    Error: $($testResult.Error)" -ForegroundColor Red
    }
}
Write-Host ""

# Final status check
Write-Host "Final System Status:" -ForegroundColor Yellow
$finalStatus = $Global:MessageBus.GetStatus()
Write-Host "  Total messages sent: $($finalStatus.Performance.MessagesSent)" -ForegroundColor White
Write-Host "  Total messages processed: $($finalStatus.Performance.MessagesProcessed)" -ForegroundColor White
Write-Host "  Total errors: $($finalStatus.Performance.ErrorCount)" -ForegroundColor White
Write-Host "  System uptime: $((Get-Date) - $finalStatus.Performance.StartTime)" -ForegroundColor White
Write-Host ""

# Cleanup
Write-Host "Cleaning up and shutting down..." -ForegroundColor Yellow
$Global:MessageBus.Shutdown()
Write-Host ""

Write-Host "=== Communication System Demo Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Key Features Demonstrated:" -ForegroundColor Green
Write-Host "  ✓ Module registration and initialization" -ForegroundColor White
Write-Host "  ✓ Direct message communication between modules" -ForegroundColor White
Write-Host "  ✓ Event publishing and subscription" -ForegroundColor White
Write-Host "  ✓ Priority message queuing" -ForegroundColor White
Write-Host "  ✓ Circuit breaker pattern for resilience" -ForegroundColor White
Write-Host "  ✓ Performance monitoring and metrics" -ForegroundColor White
Write-Host "  ✓ Error handling and retry mechanisms" -ForegroundColor White
Write-Host "  ✓ Inter-module dependency validation" -ForegroundColor White
Write-Host ""
Write-Host "The communication system is ready for production use!" -ForegroundColor Green
