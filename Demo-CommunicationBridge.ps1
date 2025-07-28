# PowerShell Leafmap Game - Simple Communication Bridge Demo
# Quick demo script for testing the communication bridge

Import-Module (Join-Path $PSScriptRoot "Modules\CoreGame\StateManager.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Modules\CoreGame\CommunicationBridge.psm1") -Force

function Demo-CommunicationBridge {
    param(
        [int]$DemoTimeSeconds = 60
    )

    Write-Host "=== PowerShell Leafmap Game - Communication Bridge Demo ===" -ForegroundColor Cyan
    Write-Host ""

    try {
        # Step 1: Initialize components
        Write-Host "🔧 Step 1: Initializing components..." -ForegroundColor Yellow
        Initialize-StateManager
        Write-Host "   ✓ State Manager initialized" -ForegroundColor Green

        Initialize-CommunicationBridge -Configuration @{
            HttpPort = 8082
            DebugMode = $true
            LoggingEnabled = $true
        }
        Write-Host "   ✓ Communication Bridge initialized" -ForegroundColor Green

        # Step 2: Start the bridge
        Write-Host "🚀 Step 2: Starting Communication Bridge..." -ForegroundColor Yellow
        Start-CommunicationBridge
        Write-Host "   ✓ Bridge started successfully" -ForegroundColor Green

        # Step 3: Set up demo data
        Write-Host "🎮 Step 3: Setting up demo game data..." -ForegroundColor Yellow
        Register-GameEntity -EntityId "demo_player_001" -EntityType "Player" -InitialState @{
            Username = "DemoPlayer"
            Level = 5
            Experience = 1250
            Currency = 500
            Location = "DemoTown"
            Health = 100
            Mana = 50
        }

        Register-GameEntity -EntityId "demo_npc_001" -EntityType "NPC" -InitialState @{
            Name = "Village Elder"
            Type = "QuestGiver"
            Location = "DemoTown"
            IsAvailable = $true
            QuestCount = 3
        }
        Write-Host "   ✓ Demo entities created" -ForegroundColor Green

        # Step 4: Test bridge functionality
        Write-Host "🧪 Step 4: Testing bridge functionality..." -ForegroundColor Yellow

        # Test commands
        $testResults = @()

        $result = Send-BridgeCommand -Command "GetGameState"
        $testResults += "GetGameState: $($result.Success)"

        $result = Send-BridgeCommand -Command "UpdateGameState" -Parameters @{
            EntityId = "demo_player_001"
            Property = "Experience"
            Value = 1500
        }
        $testResults += "UpdateGameState: $($result.Success)"

        $result = Send-BridgeCommand -Command "SaveGame" -Parameters @{
            SaveName = "demo_bridge_save"
        }
        $testResults += "SaveGame: $($result.Success)"

        foreach ($test in $testResults) {
            Write-Host "   ✓ $test" -ForegroundColor Green
        }

        # Step 5: Generate some activity
        Write-Host "📡 Step 5: Generating demo activity..." -ForegroundColor Yellow

        $activityJob = Start-Job -ScriptBlock {
            param($DemoTime)

            for ($i = 1; $i -le $DemoTime; $i++) {
                # Simulate game activity
                if ($i % 5 -eq 0) {
                    # Experience gain every 5 seconds
                    Send-BridgeEvent -EventType "player.experienceGain" -EventData @{
                        PlayerId = "demo_player_001"
                        Amount = 25
                        Source = "Combat"
                        Timestamp = Get-Date
                    }
                }

                if ($i % 10 -eq 0) {
                    # Level up every 10 seconds
                    Send-BridgeEvent -EventType "player.levelUp" -EventData @{
                        PlayerId = "demo_player_001"
                        NewLevel = [math]::Floor($i / 10) + 5
                        Timestamp = Get-Date
                    }
                }

                if ($i % 15 -eq 0) {
                    # Currency change every 15 seconds
                    Send-BridgeEvent -EventType "player.currencyChange" -EventData @{
                        PlayerId = "demo_player_001"
                        Amount = 50
                        Reason = "Quest Reward"
                        Timestamp = Get-Date
                    }
                }

                Start-Sleep -Seconds 1
            }
        } -ArgumentList $DemoTimeSeconds

        Write-Host "   ✓ Background activity started" -ForegroundColor Green

        # Step 6: Display connection info
        Write-Host ""
        Write-Host "🌐 Bridge is now running! Connect with:" -ForegroundColor Cyan
        Write-Host "   HTTP API:     http://localhost:8082" -ForegroundColor White
        Write-Host "   Status:       http://localhost:8082/status" -ForegroundColor White
        Write-Host "   Events:       http://localhost:8082/events" -ForegroundColor White
        Write-Host "   Demo Page:    file:///$($PWD.Path)\communication-bridge-demo.html" -ForegroundColor White
        Write-Host ""
        Write-Host "📋 Available HTTP endpoints:" -ForegroundColor Yellow
        Write-Host "   GET  /status      - Bridge status and statistics" -ForegroundColor Gray
        Write-Host "   POST /command     - Execute PowerShell commands" -ForegroundColor Gray
        Write-Host "   GET  /events      - Server-sent events stream" -ForegroundColor Gray
        Write-Host ""
        Write-Host "🎯 Demo will run for $DemoTimeSeconds seconds with simulated activity..." -ForegroundColor Yellow
        Write-Host "   Press Ctrl+C to stop early" -ForegroundColor Gray
        Write-Host ""

        # Monitor and show statistics
        for ($i = 1; $i -le $DemoTimeSeconds; $i++) {
            Start-Sleep -Seconds 1

            if ($i % 10 -eq 0) {
                $stats = Get-BridgeStatistics
                Write-Host "📊 [$i/$DemoTimeSeconds] Stats: Commands: $($stats.Bridge.CommandsExecuted), Events: $($stats.Bridge.EventsBroadcast), Errors: $($stats.Bridge.ErrorCount)" -ForegroundColor Cyan
            }
        }

        # Clean up activity job
        Stop-Job $activityJob
        Remove-Job $activityJob

        Write-Host ""
        Write-Host "✅ Demo completed successfully!" -ForegroundColor Green

        # Final statistics
        $finalStats = Get-BridgeStatistics
        Write-Host ""
        Write-Host "📈 Final Statistics:" -ForegroundColor Cyan
        Write-Host "   Commands Executed: $($finalStats.Bridge.CommandsExecuted)" -ForegroundColor White
        Write-Host "   Events Broadcast:  $($finalStats.Bridge.EventsBroadcast)" -ForegroundColor White
        Write-Host "   Avg Response Time: $($finalStats.Bridge.AverageResponseTime)ms" -ForegroundColor White
        Write-Host "   Total Errors:      $($finalStats.Bridge.ErrorCount)" -ForegroundColor White

    }
    catch {
        Write-Error "Demo failed: $($_.Exception.Message)"
        Write-Host "Stack trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    finally {
        Write-Host ""
        Write-Host "🛑 Stopping Communication Bridge..." -ForegroundColor Yellow
        Stop-CommunicationBridge
        Write-Host "✅ Bridge stopped" -ForegroundColor Green
    }
}

# Run the demo
Demo-CommunicationBridge -DemoTimeSeconds 30
