# PowerShell Leafmap Game - Command Registry Demo Script
# Comprehensive demonstration of the modular command registration system

param(
    [int]$DemoPort = 8082,
    [int]$DemoTime = 45,  # Demo duration in seconds
    [switch]$SkipWeb,
    [switch]$Verbose
)

if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Clear the console for a clean demo
Clear-Host

Write-Host @"
┌─────────────────────────────────────────────────────────┐
│              🎮 PowerShell Leafmap Game                │
│         Advanced Command Registry System Demo          │
│                                                         │
│  This demo showcases the modular command registration   │
│  system that allows game modules to integrate with     │
│  the Communication Bridge dynamically.                 │
└─────────────────────────────────────────────────────────┘
"@ -ForegroundColor Cyan

Write-Host "`n🚀 Starting Command Registry Demo..." -ForegroundColor Green

try {
    # Step 1: Import and initialize core modules
    Write-Host "`n📦 Loading Core Modules..." -ForegroundColor Yellow

    $ModulePath = Join-Path $PSScriptRoot "Modules\CoreGame"

    # Import core modules
    Import-Module (Join-Path $ModulePath "EventSystem.psm1") -Force
    Import-Module (Join-Path $ModulePath "DataModels.psm1") -Force
    Import-Module (Join-Path $ModulePath "StateManager.psm1") -Force
    Import-Module (Join-Path $ModulePath "CommandRegistry.psm1") -Force
    Import-Module (Join-Path $ModulePath "CommunicationBridge.psm1") -Force

    Write-Host "   ✅ Core modules loaded" -ForegroundColor Green

    # Step 2: Initialize Event System
    Write-Host "`n🎯 Initializing Event System..." -ForegroundColor Yellow
    $eventResult = Initialize-EventSystem
    if ($eventResult.Success) {
        Write-Host "   ✅ Event System initialized" -ForegroundColor Green
    } else {
        throw "Failed to initialize Event System"
    }

    # Step 3: Initialize State Manager
    Write-Host "`n💾 Initializing State Manager..." -ForegroundColor Yellow
    $stateResult = Initialize-StateManager
    if ($stateResult.Success) {
        Write-Host "   ✅ State Manager initialized" -ForegroundColor Green
    } else {
        throw "Failed to initialize State Manager"
    }

    # Step 4: Initialize Communication Bridge (which initializes Command Registry)
    Write-Host "`n🌉 Initializing Communication Bridge with Command Registry..." -ForegroundColor Yellow
    $bridgeConfig = @{
        HttpPort = $DemoPort
        HttpHost = "localhost"
        FileBasedEnabled = $true
        HttpServerEnabled = $true
        WebSocketEnabled = $false  # Simplified for demo
        LoggingEnabled = $true
        DebugMode = $true
    }

    $bridgeResult = Initialize-CommunicationBridge -Configuration $bridgeConfig
    if ($bridgeResult.Success) {
        Write-Host "   ✅ Communication Bridge initialized on port $DemoPort" -ForegroundColor Green
        Write-Host "   ✅ Command Registry is available: $($bridgeResult.CommandRegistryAvailable)" -ForegroundColor Green
    } else {
        throw "Failed to initialize Communication Bridge"
    }

    # Step 5: Load and initialize game modules
    Write-Host "`n🎮 Loading Game Modules..." -ForegroundColor Yellow

    # Import Drone System
    Import-Module (Join-Path $PSScriptRoot "Modules\DroneSystem\DroneSystem.psm1") -Force
    $droneResult = Initialize-DroneSystem -Configuration @{
        MaxDrones = 5
        DefaultSpeed = 75
    }

    if ($droneResult.Success) {
        Write-Host "   ✅ Drone System loaded with $($droneResult.CommandsRegistered) commands" -ForegroundColor Green
    }

    # Step 6: Start the Communication Bridge
    Write-Host "`n🌐 Starting Communication Bridge..." -ForegroundColor Yellow
    Start-CommunicationBridge
    Write-Host "   ✅ Bridge is running on http://localhost:$DemoPort" -ForegroundColor Green

    # Step 7: Demonstrate command discovery and execution
    Write-Host "`n🔍 Demonstrating Command Discovery..." -ForegroundColor Yellow

    # List all available commands
    Write-Host "`n📋 Available Commands:" -ForegroundColor Cyan
    $commandList = Invoke-GameCommand -CommandName "registry.listCommands"
    foreach ($command in $commandList.Data.Commands) {
        Write-Host "   • $command" -ForegroundColor White
    }

    Write-Host "`n📊 Registry Statistics:" -ForegroundColor Cyan
    $registryStats = Invoke-GameCommand -CommandName "registry.getStatistics"
    Write-Host "   • Total Commands: $($registryStats.Data.TotalCommands)" -ForegroundColor White
    Write-Host "   • Commands Executed: $($registryStats.Data.CommandsExecuted)" -ForegroundColor White
    Write-Host "   • Modules: $($registryStats.Data.ModuleStats.Keys -join ', ')" -ForegroundColor White

    # Step 8: Demonstrate drone system commands
    Write-Host "`n🚁 Demonstrating Drone System Commands..." -ForegroundColor Yellow

    # Launch a drone
    Write-Host "`n🚀 Launching drone..." -ForegroundColor Cyan
    $launchResult = Invoke-GameCommand -CommandName "drone.launch" -Parameters @{
        Name = "Demo-Drone-Alpha"
        Position = @{ X = 100; Y = 50; Z = 120 }
        Speed = 85
    }

    if ($launchResult.Success) {
        $droneId = $launchResult.Data.Id
        Write-Host "   ✅ Drone launched: $($launchResult.Data.Name) (ID: $droneId)" -ForegroundColor Green
        Write-Host "   📍 Position: X=$($launchResult.Data.Position.X), Y=$($launchResult.Data.Position.Y), Z=$($launchResult.Data.Position.Z)" -ForegroundColor White
        Write-Host "   🔋 Energy: $($launchResult.Data.Energy)" -ForegroundColor White

        # Move the drone
        Write-Host "`n📍 Moving drone to new position..." -ForegroundColor Cyan
        $moveResult = Invoke-GameCommand -CommandName "drone.move" -Parameters @{
            DroneId = $droneId
            Position = @{ X = 200; Y = 150; Z = 100 }
        }

        if ($moveResult.Success) {
            Write-Host "   ✅ Drone moved successfully" -ForegroundColor Green
            Write-Host "   📍 New position: X=$($moveResult.Data.NewPosition.X), Y=$($moveResult.Data.NewPosition.Y), Z=$($moveResult.Data.NewPosition.Z)" -ForegroundColor White
            Write-Host "   🔋 Energy remaining: $($moveResult.Data.EnergyRemaining)" -ForegroundColor White
        }

        # Perform a scan
        Write-Host "`n🔍 Performing area scan..." -ForegroundColor Cyan
        $scanResult = Invoke-GameCommand -CommandName "drone.scan" -Parameters @{
            DroneId = $droneId
        }

        if ($scanResult.Success) {
            Write-Host "   ✅ Scan completed" -ForegroundColor Green
            Write-Host "   📡 Discoveries found: $($scanResult.Data.Discoveries.Count)" -ForegroundColor White
            foreach ($discovery in $scanResult.Data.Discoveries) {
                Write-Host "      • $($discovery.Type) at distance $($discovery.Distance)m (confidence: $($discovery.Confidence)%)" -ForegroundColor Gray
            }
        }

        # Set a mission
        Write-Host "`n🎯 Assigning mission..." -ForegroundColor Cyan
        $missionResult = Invoke-GameCommand -CommandName "drone.setMission" -Parameters @{
            DroneId = $droneId
            Mission = "Reconnaissance"
            MissionData = @{
                TargetArea = "Sector-7"
                Priority = "High"
            }
        }

        if ($missionResult.Success) {
            Write-Host "   ✅ Mission assigned: $($missionResult.Data.Mission)" -ForegroundColor Green
        }

        # List all drones
        Write-Host "`n📊 Current drone status..." -ForegroundColor Cyan
        $listResult = Invoke-GameCommand -CommandName "drone.list"
        if ($listResult.Success) {
            Write-Host "   📈 Total drones: $($listResult.Data.TotalCount)" -ForegroundColor White
            Write-Host "   🏭 System capacity: $($listResult.Data.SystemStats.ActiveDrones)/$($listResult.Data.SystemStats.MaxDrones)" -ForegroundColor White
        }
    }

    # Step 9: Demonstrate command documentation
    Write-Host "`n📚 Command Documentation Examples..." -ForegroundColor Yellow

    $docResult = Invoke-GameCommand -CommandName "registry.getDocumentation" -Parameters @{
        CommandName = "drone.launch"
    }

    if ($docResult.Success) {
        $doc = $docResult.Data
        Write-Host "`n📖 Documentation for 'drone.launch':" -ForegroundColor Cyan
        Write-Host "   Description: $($doc.Description)" -ForegroundColor White
        Write-Host "   Module: $($doc.Module)" -ForegroundColor White
        Write-Host "   Category: $($doc.Category)" -ForegroundColor White
        Write-Host "   Parameters:" -ForegroundColor White
        foreach ($param in $doc.Parameters) {
            $required = if ($param.Required) { " (Required)" } else { "" }
            Write-Host "      • $($param.Name) [$($param.Type)]$required - $($param.Description)" -ForegroundColor Gray
        }
    }

    # Step 10: Demonstrate parameter validation
    Write-Host "`n✅ Demonstrating Parameter Validation..." -ForegroundColor Yellow

    Write-Host "`n❌ Testing invalid parameters..." -ForegroundColor Cyan
    try {
        $invalidResult = Invoke-GameCommand -CommandName "drone.move" -Parameters @{
            DroneId = "invalid-id"
            Position = @{ X = 50; Y = 25 }
        }
    } catch {
        Write-Host "   ✅ Validation caught error: $($_.Exception.Message)" -ForegroundColor Green
    }

    # Step 11: Demonstrate system statistics
    Write-Host "`n📊 System Statistics..." -ForegroundColor Yellow

    $bridgeStats = Invoke-GameCommand -CommandName "bridge.GetStatistics"
    if ($bridgeStats.Success) {
        Write-Host "`n📈 Communication Bridge Stats:" -ForegroundColor Cyan
        Write-Host "   • Commands Executed: $($bridgeStats.Data.Bridge.CommandsExecuted)" -ForegroundColor White
        Write-Host "   • Messages Processed: $($bridgeStats.Data.Bridge.MessagesProcessed)" -ForegroundColor White
        Write-Host "   • Average Response Time: $([Math]::Round($bridgeStats.Data.Bridge.AverageResponseTime, 2))ms" -ForegroundColor White
        Write-Host "   • Error Count: $($bridgeStats.Data.Bridge.ErrorCount)" -ForegroundColor White
    }

    # Step 12: Web interface demonstration
    if (-not $SkipWeb) {
        Write-Host "`n🌐 Web Interface Available..." -ForegroundColor Yellow
        Write-Host "   Open your browser to: http://localhost:$DemoPort/status" -ForegroundColor Cyan
        Write-Host "   Command discovery: http://localhost:$DemoPort/commands" -ForegroundColor Cyan
        Write-Host "   Documentation: http://localhost:$DemoPort/commands/docs" -ForegroundColor Cyan

        # Try to open the demo page if it exists
        $demoPage = Join-Path $PSScriptRoot "command-registry-demo.html"
        if (Test-Path $demoPage) {
            Write-Host "`n🎮 Opening interactive demo page..." -ForegroundColor Green
            Start-Process "http://localhost:$DemoPort/status"
        }
    }

    # Step 13: Live demonstration with simulated activity
    Write-Host "`n🎬 Running Live Demo for $DemoTime seconds..." -ForegroundColor Yellow
    Write-Host "   (Press Ctrl+C to stop early)" -ForegroundColor Gray

    $startTime = Get-Date
    $activityCounter = 0

    while (((Get-Date) - $startTime).TotalSeconds -lt $DemoTime) {
        Start-Sleep -Seconds 3
        $activityCounter++

        # Simulate periodic game activity
        switch ($activityCounter % 4) {
            0 {
                Write-Host "   🔄 Simulating game state update..." -ForegroundColor Gray
                try {
                    $updateResult = Invoke-GameCommand -CommandName "bridge.UpdateGameState" -Parameters @{
                        EntityId = "demo-entity-$activityCounter"
                        Property = "Health"
                        Value = (Get-Random -Minimum 80 -Maximum 100)
                    }
                    if ($updateResult.Success) {
                        Write-Host "      ✅ State updated" -ForegroundColor DarkGreen
                    }
                } catch {
                    # Ignore errors for demo
                }
            }
            1 {
                Write-Host "   📊 Checking system statistics..." -ForegroundColor Gray
                $stats = Get-CommandRegistryStatistics
                Write-Host "      📈 Total commands: $($stats.TotalCommands), Executed: $($stats.CommandsExecuted)" -ForegroundColor DarkGreen
            }
            2 {
                Write-Host "   🚁 Checking drone system..." -ForegroundColor Gray
                try {
                    $droneStatus = Invoke-GameCommand -CommandName "drone.getSystemStatus"
                    if ($droneStatus.Success) {
                        Write-Host "      🎯 Active drones: $($droneStatus.Data.ActiveDrones)" -ForegroundColor DarkGreen
                    }
                } catch {
                    # Ignore errors for demo
                }
            }
            3 {
                Write-Host "   💾 Saving game state..." -ForegroundColor Gray
                try {
                    $saveResult = Invoke-GameCommand -CommandName "bridge.SaveGame" -Parameters @{
                        SaveName = "auto-save-$activityCounter"
                    }
                    if ($saveResult.Success) {
                        Write-Host "      ✅ Game saved" -ForegroundColor DarkGreen
                    }
                } catch {
                    # Ignore errors for demo
                }
            }
        }

        # Show remaining time
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $remaining = $DemoTime - $elapsed
        Write-Host "   ⏱️ Demo time remaining: $([Math]::Round($remaining, 1))s" -ForegroundColor DarkCyan
    }

    # Final statistics
    Write-Host "`n📈 Final Demo Statistics:" -ForegroundColor Yellow
    $finalStats = Get-CommandRegistryStatistics
    Write-Host "   • Commands Registered: $($finalStats.TotalCommands)" -ForegroundColor White
    Write-Host "   • Commands Executed: $($finalStats.CommandsExecuted)" -ForegroundColor White
    Write-Host "   • Average Execution Time: $([Math]::Round($finalStats.AverageExecutionTime, 2))ms" -ForegroundColor White
    Write-Host "   • Success Rate: $([Math]::Round((($finalStats.CommandsExecuted - $finalStats.ExecutionErrors) / [Math]::Max($finalStats.CommandsExecuted, 1)) * 100, 1))%" -ForegroundColor White

    Write-Host "`n🎉 Command Registry Demo completed successfully!" -ForegroundColor Green
    Write-Host "   Bridge is still running on http://localhost:$DemoPort" -ForegroundColor Cyan
    Write-Host "   Use Stop-CommunicationBridge to stop the server" -ForegroundColor Gray

} catch {
    Write-Error "Demo failed: $($_.Exception.Message)"
    Write-Host "`nDemo error details:" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red

    # Try to stop the bridge if it was started
    try {
        Stop-CommunicationBridge
    } catch {
        # Ignore cleanup errors
    }

    exit 1
} finally {
    # Cleanup message
    Write-Host "`n🧹 To clean up, run: Stop-CommunicationBridge" -ForegroundColor Yellow
}
