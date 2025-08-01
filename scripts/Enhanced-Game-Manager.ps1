# Enhanced Game Manager with Event System Integration
# This script demonstrates the complete event-driven architecture

param(
    [string]$Action = "start",
    [string]$PlayerName = "Player1",
    [int]$ProcessingInterval = 2
)

# Import required modules
Import-Module ".\Modules\CoreGame\EventSystem.psm1" -Force

# Import existing game functions
. ".\scripts\Game-Manager.ps1"

function Start-EventDrivenGameManager {
    param(
        [string]$PlayerName,
        [int]$ProcessingInterval
    )

    Write-Host "🎮 Starting Event-Driven Game Manager" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "Player: $PlayerName" -ForegroundColor Cyan
    Write-Host "Processing Interval: $ProcessingInterval seconds" -ForegroundColor Cyan

    # Initialize event system
    Initialize-EventSystem

    # Register enhanced event handlers
    Register-EnhancedEventHandlers

    # Send startup event
    Send-GameEvent -EventType "system.startup" -Data @{
        playerName = $PlayerName
        version = "1.0.0"
        features = @("event_system", "real_time_sync", "achievement_tracking")
    }

    Write-Host "`n🔄 Starting continuous event processing..." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop the event manager" -ForegroundColor Yellow
    Write-Host "Monitor the 'events.json' file for real-time events" -ForegroundColor Gray

    # Start the event processing loop
    Start-EventProcessing -IntervalSeconds $ProcessingInterval
}

function Register-EnhancedEventHandlers {
    Write-Host "📝 Registering enhanced event handlers..." -ForegroundColor Cyan

    # Player progression handler
    Register-GameEvent -EventType "player.scoreChanged" -ScriptBlock {
        param($Data, $Event)
        $oldLevel = [math]::Floor($Data.oldScore / 100) + 1
        $newLevel = [math]::Floor($Data.newScore / 100) + 1

        if ($newLevel -gt $oldLevel) {
            Send-GameEvent -EventType "player.levelUp" -Data @{
                playerId = "player1"
                oldLevel = $oldLevel
                newLevel = $newLevel
                totalScore = $Data.newScore
            }
        }

        # Save progress
        $progress = @{
            score = $Data.newScore
            level = $newLevel
            lastUpdate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        }

        Save-PlayerProgress -PlayerName "player1" -Progress $progress
    }

    # Dynamic location generation handler
    Register-GameEvent -EventType "location.visited" -ScriptBlock {
        param($Data, $Event)
        $location = $Data.location

        # Generate nearby locations dynamically
        if ($location.type -eq "quest") {
            $nearbyLocation = @{
                id = "dynamic_$(Get-Random -Maximum 1000)"
                lat = $location.lat + (Get-Random -Minimum -0.01 -Maximum 0.01)
                lng = $location.lng + (Get-Random -Minimum -0.01 -Maximum 0.01)
                name = "Hidden Cache near $($location.name)"
                type = "treasure"
                description = "A hidden cache revealed by completing the quest"
                points = 75
                items = @("rare_gem", "bonus_coin")
                discovered = $false
                timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
            }

            Send-GameEvent -EventType "location.discovered" -Data @{
                location = $nearbyLocation
                trigger = "quest_completion"
                parentLocation = $location.id
            }
        }
    }

    # Weather system handler
    Register-GameEvent -EventType "system.weatherUpdate" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🌤️  Weather Update: $($Data.condition)" -ForegroundColor Blue

        # Weather affects certain locations
        if ($Data.condition -eq "rain") {
            Send-GameEvent -EventType "location.weatherEffect" -Data @{
                effect = "increased_treasure_chance"
                multiplier = 1.5
                duration = 300 # 5 minutes
            }
        }
    }

    # Real-time notifications handler
    Register-GameEvent -EventType "player.inventoryChanged" -ScriptBlock {
        param($Data, $Event)
        if ($Data.action -eq "added") {
            # Check for rare items
            $rareItems = @("ancient_artifact", "rare_gem", "legendary_sword")
            if ($Data.item -in $rareItems) {
                Send-GameEvent -EventType "ui.showSpecialNotification" -Data @{
                    type = "rare_item"
                    title = "RARE ITEM FOUND!"
                    message = "You found a $($Data.item)!"
                    duration = 5000
                    sound = "rare_item_sound"
                }
            }
        }
    }

    # Faction reputation handler
    Register-GameEvent -EventType "faction.reputationChanged" -ScriptBlock {
        param($Data, $Event)
        $faction = $Data.faction
        $change = $Data.change
        $newRep = $Data.newReputation

        Write-Host "🏛️  Faction Reputation: $faction $change ($newRep)" -ForegroundColor Purple

        # Unlock faction-specific locations
        if ($newRep -ge 100 -and $faction -eq "Explorers Guild") {
            $secretLocation = @{
                id = "explorers_guild_hq"
                lat = 40.7614
                lng = -73.9776
                name = "Explorers Guild Headquarters"
                type = "faction_hq"
                description = "The secret headquarters of the Explorers Guild"
                points = 500
                items = @("guild_badge", "master_map", "legendary_compass")
                accessRequirement = @{
                    faction = "Explorers Guild"
                    minReputation = 100
                }
            }

            Send-GameEvent -EventType "location.unlocked" -Data @{
                location = $secretLocation
                unlockedBy = "faction_reputation"
                faction = $faction
            }
        }
    }

    # AI companion handler
    Register-GameEvent -EventType "companion.messageReceived" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🤖 AI Companion: $($Data.message)" -ForegroundColor Green

        # Companion can suggest actions
        if ($Data.suggestion) {
            Send-GameEvent -EventType "ui.showSuggestion" -Data @{
                source = "ai_companion"
                suggestion = $Data.suggestion
                priority = $Data.priority
            }
        }
    }
}

function Start-WeatherSystem {
    Write-Host "🌤️  Starting weather system..." -ForegroundColor Blue

    $weatherConditions = @("sunny", "cloudy", "rain", "storm", "fog")

    # Generate weather updates every 5 minutes
    while ($true) {
        Start-Sleep -Seconds 300

        $weather = $weatherConditions | Get-Random
        Send-GameEvent -EventType "system.weatherUpdate" -Data @{
            condition = $weather
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
            effects = Get-WeatherEffects -Condition $weather
        }
    }
}

function Get-WeatherEffects {
    param([string]$Condition)

    switch ($Condition) {
        "rain" {
            return @{
                treasureChance = 1.5
                visibilityRange = 0.8
                movementSpeed = 0.9
            }
        }
        "storm" {
            return @{
                questDifficulty = 1.3
                experienceBonus = 1.2
                dangerLevel = 1.5
            }
        }
        "fog" {
            return @{
                discoveryRange = 0.6
                mysteryChance = 2.0
                hiddenLocationChance = 1.8
            }
        }
        "sunny" {
            return @{
                movementSpeed = 1.1
                energyRegen = 1.2
                visibility = 1.3
            }
        }
        default {
            return @{
                balanced = $true
            }
        }
    }
}

function Start-AICompanion {
    Write-Host "🤖 Starting AI companion..." -ForegroundColor Green

    # Simulate AI companion messages
    $companionMessages = @(
        @{
            message = "I've detected some interesting energy signatures to the north."
            suggestion = @{
                action = "explore_north"
                description = "Head north to investigate energy signatures"
                expectedReward = "rare_items"
            }
            priority = "medium"
        },
        @{
            message = "Your inventory is getting full. Consider visiting a shop."
            suggestion = @{
                action = "find_shop"
                description = "Locate the nearest shop to sell items"
                expectedBenefit = "inventory_space"
            }
            priority = "low"
        },
        @{
            message = "Weather conditions are perfect for treasure hunting!"
            suggestion = @{
                action = "treasure_hunt"
                description = "Search for treasures while weather is favorable"
                timeLimit = 600
            }
            priority = "high"
        }
    )

    while ($true) {
        Start-Sleep -Seconds (Get-Random -Minimum 30 -Maximum 120)

        $message = $companionMessages | Get-Random
        Send-GameEvent -EventType "companion.messageReceived" -Data $message
    }
}

function Show-EventManagerStatus {
    Write-Host "`n📊 Event Manager Status" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan

    $stats = Get-EventStatistics

    Write-Host "🔢 Total Events: $($stats.TotalEventsLogged)" -ForegroundColor White
    Write-Host "🎛️  Active Handlers: $($stats.RegisteredHandlers)" -ForegroundColor White
    Write-Host "📋 Queued Events: $($stats.QueuedEvents)" -ForegroundColor White

    if ($stats.EventTypes.Count -gt 0) {
        Write-Host "`n📈 Event Distribution:" -ForegroundColor Yellow
        foreach ($type in $stats.EventTypes | Sort-Object Count -Descending | Select-Object -First 10) {
            Write-Host "   $($type.Type): $($type.Count)" -ForegroundColor Gray
        }
    }

    # Show file status
    Write-Host "`n📁 Integration Files:" -ForegroundColor Yellow
    $files = @("events.json", "commands.json", "event_log.json")
    foreach ($file in $files) {
        if (Test-Path $file) {
            $size = [math]::Round((Get-Item $file).Length / 1KB, 2)
            Write-Host "   ✅ $file ($size KB)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $file (missing)" -ForegroundColor Red
        }
    }
}

function Test-FullIntegration {
    Write-Host "`n🧪 Testing Full Integration..." -ForegroundColor Yellow

    # Initialize
    Initialize-EventSystem
    Register-EnhancedEventHandlers

    # Test event chain
    Write-Host "1. Creating player..." -ForegroundColor Gray
    Send-GameEvent -EventType "player.created" -Data @{
        playerName = "TestPlayer"
        startingLocation = "central_park"
    }

    Start-Sleep -Seconds 1

    Write-Host "2. Visiting location..." -ForegroundColor Gray
    Send-GameEvent -EventType "location.visited" -Data @{
        location = @{
            id = "test_location"
            name = "Test Location"
            type = "quest"
            points = 150
            items = @("rare_gem")
        }
        playerId = "TestPlayer"
    }

    Start-Sleep -Seconds 1

    Write-Host "3. Changing score..." -ForegroundColor Gray
    Send-GameEvent -EventType "player.scoreChanged" -Data @{
        oldScore = 0
        newScore = 250
        pointsAdded = 250
    }

    Start-Sleep -Seconds 1

    Write-Host "4. Adding to inventory..." -ForegroundColor Gray
    Send-GameEvent -EventType "player.inventoryChanged" -Data @{
        action = "added"
        item = "ancient_artifact"
        inventory = @("rare_gem", "ancient_artifact")
    }

    Start-Sleep -Seconds 1

    Write-Host "5. Updating weather..." -ForegroundColor Gray
    Send-GameEvent -EventType "system.weatherUpdate" -Data @{
        condition = "rain"
        timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    }

    Write-Host "`n✅ Integration test completed!" -ForegroundColor Green
    Show-EventManagerStatus
}

# Main execution
switch ($Action.ToLower()) {
    "start" {
        Start-EventDrivenGameManager -PlayerName $PlayerName -ProcessingInterval $ProcessingInterval
    }

    "weather" {
        Initialize-EventSystem
        Start-WeatherSystem
    }

    "companion" {
        Initialize-EventSystem
        Start-AICompanion
    }

    "status" {
        Initialize-EventSystem
        Show-EventManagerStatus
    }

    "test" {
        Test-FullIntegration
    }

    "help" {
        Write-Host "`n📖 Event-Driven Game Manager Help" -ForegroundColor Yellow
        Write-Host "==================================" -ForegroundColor Yellow
        Write-Host "Actions:" -ForegroundColor White
        Write-Host "  start    - Start the main event manager" -ForegroundColor Cyan
        Write-Host "  weather  - Start weather system only" -ForegroundColor Cyan
        Write-Host "  companion- Start AI companion only" -ForegroundColor Cyan
        Write-Host "  status   - Show current status" -ForegroundColor Cyan
        Write-Host "  test     - Run integration test" -ForegroundColor Cyan
        Write-Host "  help     - Show this help" -ForegroundColor Cyan
        Write-Host "`nExample:" -ForegroundColor White
        Write-Host "  .\Enhanced-Game-Manager.ps1 -Action start -PlayerName 'Alice' -ProcessingInterval 1" -ForegroundColor Gray
    }

    default {
        Write-Warning "Unknown action: $Action"
        Write-Host "Use -Action help for available commands" -ForegroundColor Yellow
    }
}
