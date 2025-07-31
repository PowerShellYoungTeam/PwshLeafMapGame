# Simple StateManager Test
# Quick test to verify StateManager entity integration works

Write-Host "🔧 Simple StateManager Integration Test" -ForegroundColor Cyan

# Import modules
try {
    Import-Module ".\Modules\CoreGame\DataModels.psm1" -Force
    Import-Module ".\Modules\CoreGame\StateManager.psm1" -Force
    Import-Module ".\Modules\CoreGame\EventSystem.psm1" -Force
    Write-Host "✅ Modules imported" -ForegroundColor Green

    # List available commands from DataModels
    Write-Host "Available DataModels commands:" -ForegroundColor Yellow
    Get-Command -Module DataModels | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Gray }
} catch {
    Write-Host "❌ Module import failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Initialize StateManager
try {
    Initialize-StateManager -SavesDirectory ".\Data\Test\Saves" -BackupsDirectory ".\Data\Test\Backups" -EnableAutoSave $false
    Write-Host "✅ StateManager initialized" -ForegroundColor Green
} catch {
    Write-Host "❌ StateManager init failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test entity creation
try {
    Write-Host "Creating test entities..." -ForegroundColor Yellow

    # Use the exported New-*Entity functions
    $player = & (Get-Command "New-PlayerEntity") -Name "TestPlayer" -Level 5
    $npc = & (Get-Command "New-NPCEntity") -Name "TestNPC" -DialogueTree @("Hello")
    $item = & (Get-Command "New-ItemEntity") -Name "TestItem" -Type "Weapon" -Value 100

    Write-Host "✅ Player: $($player.GetProperty('Name')) (Level $($player.GetProperty('Level')))" -ForegroundColor Green
    Write-Host "✅ NPC: $($npc.GetProperty('Name'))" -ForegroundColor Green
    Write-Host "✅ Item: $($item.GetProperty('Name')) (Value: $($item.GetProperty('Value')))" -ForegroundColor Green
} catch {
    Write-Host "❌ Entity creation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test entity registration
try {
    Write-Host "Registering entities..." -ForegroundColor Yellow
    $playerReg = Register-Entity -Entity $player -TrackChanges $true
    $npcReg = Register-Entity -Entity $npc -TrackChanges $true
    $itemReg = Register-Entity -Entity $item -TrackChanges $true

    Write-Host "✅ Player registered: $($playerReg.Success)" -ForegroundColor Green
    Write-Host "✅ NPC registered: $($npcReg.Success)" -ForegroundColor Green
    Write-Host "✅ Item registered: $($itemReg.Success)" -ForegroundColor Green
} catch {
    Write-Host "❌ Entity registration failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test entity collection save
try {
    Write-Host "Saving entity collection..." -ForegroundColor Yellow
    $entities = @{
        'Player' = @($player)
        'NPC' = @($npc)
        'Item' = @($item)
    }

    $saveResult = Save-EntityCollection -Entities $entities -SaveName "simple_test"
    Write-Host "✅ Save result: $($saveResult.Success)" -ForegroundColor Green
} catch {
    Write-Host "❌ Entity save failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test entity collection load
try {
    Write-Host "Loading entity collection..." -ForegroundColor Yellow
    $loadResult = Load-EntityCollection -SaveName "simple_test"

    if ($loadResult.Success) {
        Write-Host "✅ Load successful" -ForegroundColor Green
        Write-Host "  Loaded $($loadResult.Entities.Player.Count) Players" -ForegroundColor Green
        Write-Host "  Loaded $($loadResult.Entities.NPC.Count) NPCs" -ForegroundColor Green
        Write-Host "  Loaded $($loadResult.Entities.Item.Count) Items" -ForegroundColor Green

        $loadedPlayer = $loadResult.Entities.Player[0]
        Write-Host "  Player Name: $($loadedPlayer.GetProperty('Name'))" -ForegroundColor Green
        Write-Host "  Player Level: $($loadedPlayer.GetProperty('Level'))" -ForegroundColor Green
    } else {
        Write-Host "❌ Load failed: $($loadResult.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Entity load failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Simple StateManager test completed successfully!" -ForegroundColor Green
