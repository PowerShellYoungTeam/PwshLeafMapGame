# PowerShell Event System Demo Script
# Demonstrates the event system integration between PowerShell and JavaScript

param(
    [string]$Action = "demo",
    [string]$PlayerName = "DemoPlayer"
)

# Import the event system module
Import-Module ".\Modules\CoreGame\EventSystem.psm1" -Force

# Import game manager functions
. ".\scripts\Game-Manager.ps1"

function Start-EventSystemDemo {
    param([string]$PlayerName)

    Write-Host "🎮 PowerShell Event System Demo" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green

    # Initialize the event system
    Initialize-EventSystem

    # Register demo event handlers
    Register-DemoEventHandlers

    # Simulate game events
    Write-Host "`n📡 Simulating game events..." -ForegroundColor Yellow

    # 1. System startup
    Send-GameEvent -EventType "system.startup" -Data @{
        version = "1.0.0"
        mode = "demo"
    }

    # 2. Player creation
    Send-GameEvent -EventType "player.created" -Data @{
        playerName = $PlayerName
        startingLocation = "new_york_center"
    }

    # 3. Location discovery and visit
    $demoLocations = @(
        @{
            id = "central_park"
            name = "Central Park"
            type = "landmark"
            points = 50
            items = @("map_fragment", "health_potion")
        },
        @{
            id = "times_square"
            name = "Times Square"
            type = "quest"
            points = 100
            items = @("quest_item", "golden_coin")
        },
        @{
            id = "brooklyn_bridge"
            name = "Brooklyn Bridge"
            type = "treasure"
            points = 150
            items = @("ancient_artifact", "treasure_map")
        }
    )

    foreach ($location in $demoLocations) {
        Start-Sleep -Seconds 1

        # Location discovered
        Send-GameEvent -EventType "location.discovered" -Data @{
            location = $location
            playerId = $PlayerName
        }

        Start-Sleep -Seconds 1

        # Location visited
        Send-GameEvent -EventType "location.visited" -Data @{
            location = $location
            playerId = $PlayerName
        }
    }

    # 4. Quest completion
    Send-GameEvent -EventType "quest.completed" -Data @{
        questId = "first_adventure"
        playerId = $PlayerName
        reward = @{
            experience = 200
            items = @("hero_badge")
            points = 300
        }
    }

    # 5. Level up
    Send-GameEvent -EventType "player.levelUp" -Data @{
        playerId = $PlayerName
        oldLevel = 1
        newLevel = 2
        totalExperience = 500
    }

    Write-Host "`n📊 Event Statistics:" -ForegroundColor Cyan
    $stats = Get-EventStatistics
    Write-Host "Total Events Logged: $($stats.TotalEventsLogged)" -ForegroundColor White
    Write-Host "Registered Handlers: $($stats.RegisteredHandlers)" -ForegroundColor White
    Write-Host "Queued Events for JavaScript: $($stats.QueuedEvents)" -ForegroundColor White

    Write-Host "`n📁 Generated Files:" -ForegroundColor Cyan
    if (Test-Path "events.json") {
        Write-Host "✓ events.json - Events for JavaScript consumption" -ForegroundColor Green
    }
    if (Test-Path "event_log.json") {
        Write-Host "✓ event_log.json - Complete event audit log" -ForegroundColor Green
    }
    if (Test-Path "visit_log.json") {
        Write-Host "✓ visit_log.json - Location visit history" -ForegroundColor Green
    }
    if (Test-Path "player_$PlayerName.json") {
        Write-Host "✓ player_$PlayerName.json - Player data file" -ForegroundColor Green
    }

    Write-Host "`n💡 Integration Notes:" -ForegroundColor Yellow
    Write-Host "1. JavaScript should poll 'events.json' for new events" -ForegroundColor Gray
    Write-Host "2. JavaScript can write commands to 'commands.json'" -ForegroundColor Gray
    Write-Host "3. PowerShell processes commands and generates response events" -ForegroundColor Gray
    Write-Host "4. All events are logged for debugging and auditing" -ForegroundColor Gray
}

function Register-DemoEventHandlers {
    Write-Host "📝 Registering demo event handlers..." -ForegroundColor Cyan

    # Location discovery handler
    Register-GameEvent -EventType "location.discovered" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🗺️  New location discovered: $($Data.location.name)" -ForegroundColor Magenta

        # Could trigger map update in JavaScript
        Send-GameEvent -EventType "ui.updateMap" -Data @{
            action = "addLocation"
            location = $Data.location
        }
    }

    # Quest completion handler
    Register-GameEvent -EventType "quest.completed" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🏆 Quest completed: $($Data.questId)" -ForegroundColor Yellow

        # Award experience and items
        $reward = $Data.reward
        Write-Host "   Reward: $($reward.experience) XP, $($reward.points) points, Items: $($reward.items -join ', ')" -ForegroundColor Green

        # Trigger UI update
        Send-GameEvent -EventType "ui.showQuestComplete" -Data $Data
    }

    # Level up handler
    Register-GameEvent -EventType "player.levelUp" -ScriptBlock {
        param($Data, $Event)
        Write-Host "⭐ Player leveled up! Level $($Data.oldLevel) → $($Data.newLevel)" -ForegroundColor Green

        # Unlock new abilities or areas
        if ($Data.newLevel -eq 2) {
            Send-GameEvent -EventType "feature.unlocked" -Data @{
                featureId = "advanced_quests"
                title = "Advanced Quests Unlocked!"
                description = "You can now take on more challenging quests"
            }
        }
    }

    # Achievement unlocked handler
    Register-GameEvent -EventType "achievement.unlocked" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🎖️  Achievement Unlocked: $($Data.title)" -ForegroundColor Cyan
        Write-Host "   $($Data.description) (+$($Data.points) points)" -ForegroundColor Gray

        # Update player achievements
        $playerFile = "player_$($Data.playerId).json"
        if (Test-Path $playerFile) {
            $playerData = Get-Content $playerFile -Raw | ConvertFrom-Json
            $achievement = @{
                id = $Data.achievementId
                title = $Data.title
                description = $Data.description
                points = $Data.points
                unlockedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
            }
            $playerData.achievements += $achievement
            $playerData | ConvertTo-Json -Depth 5 | Set-Content $playerFile
        }
    }

    # UI update handlers (these would trigger frontend updates)
    Register-GameEvent -EventType "ui.updateMap" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🗺️  UI Map Update: $($Data.action)" -ForegroundColor Blue
    }

    Register-GameEvent -EventType "ui.showQuestComplete" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🎉 UI Quest Complete Notification" -ForegroundColor Blue
    }

    Register-GameEvent -EventType "feature.unlocked" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🔓 Feature Unlocked: $($Data.title)" -ForegroundColor Cyan
    }
}

function Test-JavaScriptIntegration {
    Write-Host "`n🔄 Testing JavaScript Integration..." -ForegroundColor Yellow

    # Simulate JavaScript commands
    $testCommands = @(
        @{
            id = "cmd_001"
            type = "powershell.generateLocations"
            data = @{
                city = "New York"
                count = 5
            }
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        },
        @{
            id = "cmd_002"
            type = "powershell.saveProgress"
            data = @{
                playerName = $PlayerName
                progress = @{
                    level = 2
                    score = 450
                    visitedLocations = @("central_park", "times_square")
                }
            }
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        }
    )

    # Save test commands to file
    $testCommands | ConvertTo-Json -Depth 10 | Set-Content "commands.json"
    Write-Host "📝 Created test commands.json file" -ForegroundColor Green

    # Process the commands
    Process-JavaScriptCommands

    Write-Host "✅ JavaScript integration test completed" -ForegroundColor Green
}

function Show-EventSystemHelp {
    Write-Host "`n📖 PowerShell Event System Help" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Yellow

    Write-Host "`nAvailable Actions:" -ForegroundColor White
    Write-Host "  demo         - Run the complete event system demonstration" -ForegroundColor Cyan
    Write-Host "  test         - Test JavaScript integration" -ForegroundColor Cyan
    Write-Host "  stats        - Show event system statistics" -ForegroundColor Cyan
    Write-Host "  clean        - Clean up demo files" -ForegroundColor Cyan
    Write-Host "  help         - Show this help message" -ForegroundColor Cyan

    Write-Host "`nEvent Types:" -ForegroundColor White
    Write-Host "  Player Events: player.created, player.levelUp, player.died" -ForegroundColor Gray
    Write-Host "  Location Events: location.discovered, location.visited" -ForegroundColor Gray
    Write-Host "  Quest Events: quest.started, quest.completed, quest.failed" -ForegroundColor Gray
    Write-Host "  System Events: system.startup, system.error, system.dataLoaded" -ForegroundColor Gray
    Write-Host "  UI Events: ui.updateMap, ui.showNotification, ui.playSound" -ForegroundColor Gray

    Write-Host "`nIntegration Files:" -ForegroundColor White
    Write-Host "  events.json      - Events from PowerShell to JavaScript" -ForegroundColor Gray
    Write-Host "  commands.json    - Commands from JavaScript to PowerShell" -ForegroundColor Gray
    Write-Host "  event_log.json   - Complete event audit log" -ForegroundColor Gray
    Write-Host "  visit_log.json   - Location visit history" -ForegroundColor Gray
}

function Show-EventStatistics {
    Write-Host "`n📊 Event System Statistics" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan

    if (-not (Get-Module EventSystem)) {
        Initialize-EventSystem
    }

    $stats = Get-EventStatistics

    Write-Host "Total Events Logged: $($stats.TotalEventsLogged)" -ForegroundColor White
    Write-Host "Registered Handlers: $($stats.RegisteredHandlers)" -ForegroundColor White
    Write-Host "Queued Events: $($stats.QueuedEvents)" -ForegroundColor White

    if ($stats.EventTypes.Count -gt 0) {
        Write-Host "`nEvent Types Distribution:" -ForegroundColor Yellow
        foreach ($eventType in $stats.EventTypes) {
            Write-Host "  $($eventType.Type): $($eventType.Count)" -ForegroundColor Gray
        }
    }

    if ($stats.RecentEvents.Count -gt 0) {
        Write-Host "`nRecent Events:" -ForegroundColor Yellow
        foreach ($event in $stats.RecentEvents) {
            Write-Host "  [$($event.timestamp)] $($event.type)" -ForegroundColor Gray
        }
    }
}

function Clear-DemoFiles {
    Write-Host "`n🧹 Cleaning up demo files..." -ForegroundColor Yellow

    $filesToClean = @(
        "events.json",
        "commands.json",
        "event_log.json",
        "visit_log.json",
        "player_$PlayerName.json"
    )

    foreach ($file in $filesToClean) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Host "🗑️  Removed: $file" -ForegroundColor Red
        }
    }

    Write-Host "✅ Cleanup completed" -ForegroundColor Green
}

# Main execution logic
switch ($Action.ToLower()) {
    "demo" {
        Start-EventSystemDemo -PlayerName $PlayerName
    }

    "test" {
        Initialize-EventSystem
        Test-JavaScriptIntegration
    }

    "stats" {
        Show-EventStatistics
    }

    "clean" {
        Clear-DemoFiles
    }

    "help" {
        Show-EventSystemHelp
    }

    default {
        Write-Warning "Unknown action: $Action"
        Show-EventSystemHelp
    }
}
