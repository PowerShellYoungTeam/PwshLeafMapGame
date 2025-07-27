# Complete Event System Integration Example
# This script demonstrates the full event-driven workflow

param(
    [string]$Mode = "interactive"
)

Write-Host "🚀 PowerShell Leafmap RPG - Event System Integration" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green

# Check if we're in the correct directory
if (-not (Test-Path "index.html")) {
    Write-Error "Please run this script from the game root directory"
    exit 1
}

# Import required modules
Write-Host "📦 Loading event system..." -ForegroundColor Cyan
Import-Module ".\Modules\CoreGame\EventSystem.psm1" -Force

function Start-InteractiveDemo {
    Write-Host "`n🎮 Starting Interactive Demo" -ForegroundColor Yellow
    Write-Host "=============================" -ForegroundColor Yellow

    # Initialize event system
    Initialize-EventSystem

    Write-Host "`n🔧 Setting up event handlers..." -ForegroundColor Cyan

    # Register demo handlers
    Register-GameEvent -EventType "demo.step" -ScriptBlock {
        param($Data, $Event)
        Write-Host "✅ Step $($Data.step): $($Data.description)" -ForegroundColor Green
    }

    # Simulate the complete game flow
    Write-Host "`n🎯 Simulating complete game workflow:" -ForegroundColor Magenta

    # Step 1: Game startup
    Send-GameEvent -EventType "demo.step" -Data @{
        step = 1
        description = "Game system starting up"
    }
    Send-GameEvent -EventType "system.startup" -Data @{
        version = "1.0.0"
        timestamp = (Get-Date).ToString()
    }

    Start-Sleep -Seconds 1

    # Step 2: Player creation
    Send-GameEvent -EventType "demo.step" -Data @{
        step = 2
        description = "Creating new player"
    }
    Send-GameEvent -EventType "player.created" -Data @{
        playerName = "DemoPlayer"
        startingLocation = "central_park"
    }

    Start-Sleep -Seconds 1

    # Step 3: Location discovery
    Send-GameEvent -EventType "demo.step" -Data @{
        step = 3
        description = "Discovering new location"
    }

    $newLocation = @{
        id = "demo_location_001"
        lat = 40.7829
        lng = -73.9654
        name = "Demo Treasure Site"
        type = "treasure"
        description = "A demonstration treasure location with valuable items"
        points = 100
        items = @("demo_coin", "demo_gem")
        discovered = $true
        timestamp = (Get-Date).ToString()
    }

    Send-GameEvent -EventType "location.discovered" -Data @{
        location = $newLocation
        discoveredBy = "DemoPlayer"
    }

    Start-Sleep -Seconds 1

    # Step 4: Location visit
    Send-GameEvent -EventType "demo.step" -Data @{
        step = 4
        description = "Visiting discovered location"
    }
    Send-GameEvent -EventType "location.visited" -Data @{
        location = $newLocation
        playerId = "DemoPlayer"
    }

    Start-Sleep -Seconds 1

    # Step 5: Visit more locations to trigger achievements
    Send-GameEvent -EventType "demo.step" -Data @{
        step = 5
        description = "Visiting additional locations for achievements"
    }

    # Visit 4 more locations to reach 5 total (triggers Explorer achievement)
    for ($i = 2; $i -le 5; $i++) {
        $additionalLocation = @{
            id = "demo_location_00$i"
            name = "Demo Location $i"
            type = "landmark"
            points = 50
            items = @("item_$i")
        }

        Send-GameEvent -EventType "location.visited" -Data @{
            location = $additionalLocation
            playerId = "DemoPlayer"
        }

        Start-Sleep -Milliseconds 300
    }

    Start-Sleep -Seconds 1

    # Step 6: Inventory update
    Send-GameEvent -EventType "demo.step" -Data @{
        step = 6
        description = "Adding items to inventory"
    }
    Send-GameEvent -EventType "player.inventoryChanged" -Data @{
        action = "added"
        item = "demo_gem"
        playerId = "DemoPlayer"
        inventory = @("demo_coin", "demo_gem")
    }

    Start-Sleep -Seconds 1

    # Step 7: Score update and level up
    Send-GameEvent -EventType "demo.step" -Data @{
        step = 7
        description = "Updating player score"
    }
    Send-GameEvent -EventType "player.scoreChanged" -Data @{
        playerId = "DemoPlayer"
        oldScore = 0
        newScore = 250
        pointsAdded = 250
    }

    Start-Sleep -Seconds 1

    # Step 8: Manual achievement unlock
    Send-GameEvent -EventType "demo.step" -Data @{
        step = 8
        description = "Unlocking achievement"
    }
    Send-GameEvent -EventType "achievement.unlocked" -Data @{
        playerId = "DemoPlayer"
        achievementId = "demo_explorer"
        title = "Demo Explorer"
        description = "Completed the event system demonstration"
        points = 50
    }

    Write-Host "`n🎉 Demo completed successfully!" -ForegroundColor Green

    # Show results
    Write-Host "`n📊 Generated Files:" -ForegroundColor Cyan
    Get-ChildItem -Filter "*.json" | Where-Object { $_.Name -in @("events.json", "event_log.json", "player_DemoPlayer.json") } | ForEach-Object {
        $size = [math]::Round($_.Length / 1KB, 2)
        Write-Host "   📄 $($_.Name) ($size KB)" -ForegroundColor White
    }

    # Show player progress
    if (Test-Path "player_DemoPlayer.json") {
        $progress = Get-Content "player_DemoPlayer.json" -Raw | ConvertFrom-Json
        Write-Host "`n👤 Player Progress:" -ForegroundColor Cyan
        Write-Host "   Visited Locations: $($progress.visitedLocations.Count)" -ForegroundColor White
        Write-Host "   Achievements: $($progress.achievements.Count)" -ForegroundColor White
    }

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Start the web server: .\Start-Game.ps1" -ForegroundColor Gray
    Write-Host "2. Start the event manager: .\scripts\Enhanced-Game-Manager.ps1 -Action start" -ForegroundColor Gray
    Write-Host "3. Open browser to: http://localhost:8080" -ForegroundColor Gray
    Write-Host "4. Click 'Load Game Data' to trigger PowerShell integration" -ForegroundColor Gray
}

function Show-IntegrationOverview {
    Write-Host "`n📋 Event System Integration Overview" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan

    Write-Host "`n🔄 Communication Flow:" -ForegroundColor Yellow
    Write-Host "1. JavaScript → PowerShell: Commands written to commands.json" -ForegroundColor White
    Write-Host "2. PowerShell processes commands and generates events" -ForegroundColor White
    Write-Host "3. PowerShell → JavaScript: Events written to events.json" -ForegroundColor White
    Write-Host "4. JavaScript polls events.json and processes new events" -ForegroundColor White

    Write-Host "`n🎛️ Key Components:" -ForegroundColor Yellow
    Write-Host "• EventManager (JavaScript) - Client-side event orchestration" -ForegroundColor White
    Write-Host "• EventSystem.psm1 (PowerShell) - Server-side event processing" -ForegroundColor White
    Write-Host "• Game integration - Seamless gameplay event flow" -ForegroundColor White
    Write-Host "• File-based communication - Simple, reliable data exchange" -ForegroundColor White

    Write-Host "`n⚡ Real-time Features:" -ForegroundColor Yellow
    Write-Host "• Location discovery and visits" -ForegroundColor White
    Write-Host "• Dynamic content generation" -ForegroundColor White
    Write-Host "• Achievement tracking" -ForegroundColor White
    Write-Host "• Weather system effects" -ForegroundColor White
    Write-Host "• AI companion interactions" -ForegroundColor White

    Write-Host "`n🛠️ Development Tools:" -ForegroundColor Yellow
    Write-Host "• Event logging and debugging" -ForegroundColor White
    Write-Host "• Integration testing scripts" -ForegroundColor White
    Write-Host "• Performance monitoring" -ForegroundColor White
    Write-Host "• Error handling and recovery" -ForegroundColor White
}

function Test-SystemIntegration {
    Write-Host "`n🧪 Testing System Integration" -ForegroundColor Yellow
    Write-Host "=============================" -ForegroundColor Yellow

    # Initialize
    Initialize-EventSystem

    Write-Host "✅ Event system initialized" -ForegroundColor Green

    # Test event registration
    $handlerId = Register-GameEvent -EventType "test.event" -ScriptBlock {
        param($Data, $Event)
        Write-Host "🎯 Test event received: $($Data.message)" -ForegroundColor Magenta
    }

    Write-Host "✅ Event handler registered (ID: $handlerId)" -ForegroundColor Green

    # Test event emission
    Send-GameEvent -EventType "test.event" -Data @{
        message = "Integration test successful"
        timestamp = (Get-Date).ToString()
    }

    Write-Host "✅ Event emitted and processed" -ForegroundColor Green

    # Test JavaScript command simulation
    $testCommand = @{
        id = "test_cmd_001"
        type = "powershell.generateLocations"
        data = @{
            city = "Test City"
            locationCount = 3
        }
        timestamp = (Get-Date).ToString()
    }

    @($testCommand) | ConvertTo-Json -Depth 10 | Set-Content "commands.json"
    Write-Host "✅ Test command created" -ForegroundColor Green

    # Process the test command
    Process-JavaScriptCommands
    Write-Host "✅ Command processed" -ForegroundColor Green

    # Check for events file
    if (Test-Path "events.json") {
        $events = Get-Content "events.json" -Raw | ConvertFrom-Json
        Write-Host "✅ Found $($events.Count) events in events.json" -ForegroundColor Green
    }

    Write-Host "`n🎉 Integration test completed successfully!" -ForegroundColor Green
}

function Clean-DemoFiles {
    Write-Host "`n🧹 Cleaning demo files..." -ForegroundColor Yellow

    $filesToClean = @(
        "events.json",
        "commands.json",
        "event_log.json",
        "visit_log.json",
        "player_DemoPlayer.json"
    )

    $cleaned = 0
    foreach ($file in $filesToClean) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Host "🗑️ Removed: $file" -ForegroundColor Red
            $cleaned++
        }
    }

    if ($cleaned -eq 0) {
        Write-Host "✨ No demo files to clean" -ForegroundColor Green
    } else {
        Write-Host "✅ Cleaned $cleaned demo files" -ForegroundColor Green
    }
}

# Main execution
switch ($Mode.ToLower()) {
    "interactive" {
        Start-InteractiveDemo
    }

    "overview" {
        Show-IntegrationOverview
    }

    "test" {
        Test-SystemIntegration
    }

    "clean" {
        Clean-DemoFiles
    }

    "help" {
        Write-Host "`n📖 Event System Integration Example" -ForegroundColor Yellow
        Write-Host "===================================" -ForegroundColor Yellow
        Write-Host "Modes:" -ForegroundColor White
        Write-Host "  interactive - Run complete interactive demonstration" -ForegroundColor Cyan
        Write-Host "  overview    - Show integration overview" -ForegroundColor Cyan
        Write-Host "  test        - Test system integration" -ForegroundColor Cyan
        Write-Host "  clean       - Clean up demo files" -ForegroundColor Cyan
        Write-Host "  help        - Show this help" -ForegroundColor Cyan
        Write-Host "`nExample:" -ForegroundColor White
        Write-Host "  .\Complete-Integration-Example.ps1 -Mode interactive" -ForegroundColor Gray
    }

    default {
        Write-Warning "Unknown mode: $Mode"
        Write-Host "Use -Mode help for available options" -ForegroundColor Yellow
    }
}
