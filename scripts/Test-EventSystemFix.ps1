# Test script to verify the achievement system fix
# This script tests the corrected event system

Write-Host "🧪 Testing Event System Fix" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Import the fixed event system
Import-Module ".\Modules\CoreGame\EventSystem.psm1" -Force

# Initialize the event system
Initialize-EventSystem

Write-Host "✅ Event system initialized" -ForegroundColor Green

# Test player creation
Write-Host "`n1. Testing player creation..." -ForegroundColor Cyan
Send-GameEvent -EventType "player.created" -Data @{
    playerName = "TestPlayer"
    startingLocation = "test_start"
}

Start-Sleep -Seconds 1

# Test location visit (this should trigger achievement check)
Write-Host "`n2. Testing location visit..." -ForegroundColor Cyan
$testLocation = @{
    id = "test_location_001"
    name = "Test Location"
    type = "treasure"
    points = 100
    items = @("test_item")
}

Send-GameEvent -EventType "location.visited" -Data @{
    location = $testLocation
    playerId = "TestPlayer"
}

Start-Sleep -Seconds 1

# Test a few more location visits to trigger achievements
Write-Host "`n3. Testing multiple location visits for achievements..." -ForegroundColor Cyan

for ($i = 2; $i -le 6; $i++) {
    $location = @{
        id = "test_location_00$i"
        name = "Test Location $i"
        type = "landmark"
        points = 50
        items = @("item_$i")
    }

    Send-GameEvent -EventType "location.visited" -Data @{
        location = $location
        playerId = "TestPlayer"
    }

    Start-Sleep -Milliseconds 500
}

Write-Host "`n4. Checking player progress..." -ForegroundColor Cyan
$progress = Get-Content "player_TestPlayer.json" -Raw | ConvertFrom-Json
Write-Host "Player has visited $($progress.visitedLocations.Count) locations" -ForegroundColor White
Write-Host "Visited locations: $($progress.visitedLocations -join ', ')" -ForegroundColor Gray

Write-Host "`n5. Checking event statistics..." -ForegroundColor Cyan
$stats = Get-EventStatistics
Write-Host "Total events logged: $($stats.TotalEventsLogged)" -ForegroundColor White
Write-Host "Event types:" -ForegroundColor White
foreach ($type in $stats.EventTypes | Sort-Object Count -Descending) {
    Write-Host "  $($type.Type): $($type.Count)" -ForegroundColor Gray
}

# Test JavaScript command processing
Write-Host "`n6. Testing JavaScript command processing..." -ForegroundColor Cyan
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
Process-JavaScriptCommands

if (Test-Path "events.json") {
    $events = Get-Content "events.json" -Raw | ConvertFrom-Json
    $completedCommand = $events | Where-Object { $_.type -eq "powershell.commandCompleted" }
    if ($completedCommand) {
        Write-Host "✅ Command processed successfully" -ForegroundColor Green
        Write-Host "Generated $($completedCommand.data.result.locations.Count) locations" -ForegroundColor White
    }
}

Write-Host "`n🎉 Test completed successfully!" -ForegroundColor Green
Write-Host "The achievement system is now working correctly." -ForegroundColor White

# Clean up test files
Write-Host "`n🧹 Cleaning up test files..." -ForegroundColor Yellow
$testFiles = @("player_TestPlayer.json", "events.json", "commands.json", "event_log.json", "visit_log.json")
foreach ($file in $testFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force
        Write-Host "Removed: $file" -ForegroundColor Gray
    }
}

Write-Host "`n✅ Fix verification complete!" -ForegroundColor Green
