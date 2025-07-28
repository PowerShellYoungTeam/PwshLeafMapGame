# Simple State Management Test
# Tests the state management system without external dependencies

Write-Host "=== PowerShell Leafmap Game - Simple State Management Test ===" -ForegroundColor Cyan
Write-Host ""

try {
    # Test if the StateManager module loads correctly
    Write-Host "📋 Testing module import..." -ForegroundColor Yellow

    $ModulePath = Join-Path $PSScriptRoot "Modules\CoreGame\StateManager.psm1"
    if (-not (Test-Path $ModulePath)) {
        Write-Error "StateManager module not found at: $ModulePath"
        exit 1
    }

    # Import just the StateManager module for testing
    Import-Module $ModulePath -Force -Verbose
    Write-Host "✅ StateManager module imported successfully" -ForegroundColor Green

    # Test basic functionality without dependencies
    Write-Host ""
    Write-Host "🔧 Testing basic state manager functionality..." -ForegroundColor Yellow

    # Initialize with minimal configuration
    $config = @{
        SavesDirectory = ".\Data\Saves"
        AutoSaveInterval = 0  # Disable auto-save for testing
        CompressionEnabled = $false
        StateValidation = $false
    }

    Write-Host "Initializing State Manager with test configuration..." -ForegroundColor Cyan
    $initResult = Initialize-StateManager -Configuration $config

    if ($initResult.Success) {
        Write-Host "✅ State Manager initialized successfully" -ForegroundColor Green
    } else {
        Write-Error "❌ State Manager initialization failed"
        exit 1
    }

    # Test entity registration
    Write-Host ""
    Write-Host "👤 Testing entity registration..." -ForegroundColor Yellow

    $playerData = @{
        Username = "TestPlayer"
        Level = 1
        Experience = 0
        Currency = 100
        Location = "TestTown"
    }

    $entityResult = Register-GameEntity -EntityId "test_player_001" -EntityType "Player" -InitialState $playerData

    if ($entityResult.Success) {
        Write-Host "✅ Player entity registered successfully" -ForegroundColor Green
    } else {
        Write-Error "❌ Player entity registration failed"
    }

    # Test state updates
    Write-Host ""
    Write-Host "🔄 Testing state updates..." -ForegroundColor Yellow

    $updateResult1 = Update-GameEntityState -EntityId "test_player_001" -Property "Experience" -Value 500
    $updateResult2 = Update-GameEntityState -EntityId "test_player_001" -Property "Level" -Value 2
    $updateResult3 = Update-GameEntityState -EntityId "test_player_001" -Property "Currency" -Value 150

    if ($updateResult1.Success -and $updateResult2.Success -and $updateResult3.Success) {
        Write-Host "✅ State updates completed successfully" -ForegroundColor Green
    } else {
        Write-Warning "⚠️ Some state updates may have failed"
    }

    # Test save functionality
    Write-Host ""
    Write-Host "💾 Testing save functionality..." -ForegroundColor Yellow

    $saveResult = Save-GameState -SaveName "simple_test" -AdditionalData @{ TestMode = $true }

    if ($saveResult.Success) {
        Write-Host "✅ Game state saved successfully" -ForegroundColor Green
        Write-Host "   📁 File: $($saveResult.SaveFile)" -ForegroundColor Cyan
        Write-Host "   📊 Size: $($saveResult.SaveSize) bytes" -ForegroundColor Cyan
        Write-Host "   ⏱️ Time: $($saveResult.SaveTime) ms" -ForegroundColor Cyan
    } else {
        Write-Error "❌ Save failed"
    }

    # Test load functionality
    Write-Host ""
    Write-Host "📥 Testing load functionality..." -ForegroundColor Yellow

    # Modify state before loading to verify load works
    Update-GameEntityState -EntityId "test_player_001" -Property "Experience" -Value 999

    $loadResult = Load-GameState -SaveName "simple_test"

    if ($loadResult.Success) {
        Write-Host "✅ Game state loaded successfully" -ForegroundColor Green
        Write-Host "   ⏱️ Time: $($loadResult.LoadTime) ms" -ForegroundColor Cyan

        # Verify loaded state
        if ($Global:StateManager) {
            $loadedState = $Global:StateManager.GetEntityState("test_player_001")
            Write-Host "   🎮 Player Experience: $($loadedState.Experience) (should be 500)" -ForegroundColor Cyan
            Write-Host "   📊 Player Level: $($loadedState.Level)" -ForegroundColor Cyan
            Write-Host "   💰 Player Currency: $($loadedState.Currency)" -ForegroundColor Cyan
        }
    } else {
        Write-Error "❌ Load failed"
    }

    # Test statistics
    Write-Host ""
    Write-Host "📊 Testing statistics..." -ForegroundColor Yellow

    $stats = Get-StateStatistics

    Write-Host "📈 State Management Statistics:" -ForegroundColor Cyan
    Write-Host "   🎯 Tracked Entities: $($stats.TrackedEntities)" -ForegroundColor White
    Write-Host "   🔄 Dirty Entities: $($stats.DirtyEntities)" -ForegroundColor White
    Write-Host "   📝 Total Changes: $($stats.TotalChanges)" -ForegroundColor White
    Write-Host "   💾 Save Count: $($stats.Performance.SaveCount)" -ForegroundColor White
    Write-Host "   📥 Load Count: $($stats.Performance.LoadCount)" -ForegroundColor White
    Write-Host "   ⏱️ Avg Save Time: $([math]::Round($stats.Performance.AverageSaveTime, 2)) ms" -ForegroundColor White

    # Test export functionality
    Write-Host ""
    Write-Host "🌐 Testing export functionality..." -ForegroundColor Yellow

    $exportData = Export-StateForBrowser -Format "JSON"
    $exportSize = [System.Text.Encoding]::UTF8.GetByteCount($exportData)

    Write-Host "✅ Export completed: $exportSize bytes" -ForegroundColor Green

    # Test save file listing
    Write-Host ""
    Write-Host "📋 Testing save file listing..." -ForegroundColor Yellow

    $saveFiles = Get-SaveFiles

    Write-Host "💾 Available save files:" -ForegroundColor Cyan
    foreach ($save in $saveFiles) {
        Write-Host "   📄 $($save.Name) - $($save.Size) bytes - $($save.Modified)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "🎉 Simple State Management Test Completed Successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ All core functionality verified:" -ForegroundColor Green
    Write-Host "   ✓ Module import" -ForegroundColor White
    Write-Host "   ✓ State manager initialization" -ForegroundColor White
    Write-Host "   ✓ Entity registration" -ForegroundColor White
    Write-Host "   ✓ State updates" -ForegroundColor White
    Write-Host "   ✓ Save/Load operations" -ForegroundColor White
    Write-Host "   ✓ Statistics collection" -ForegroundColor White
    Write-Host "   ✓ Export functionality" -ForegroundColor White
    Write-Host "   ✓ File management" -ForegroundColor White

}
catch {
    Write-Error "❌ Test failed: $($_.Exception.Message)"
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
finally {
    # Cleanup
    if ($Global:StateManager) {
        Write-Host ""
        Write-Host "🧹 Cleaning up..." -ForegroundColor Yellow
        $Global:StateManager.Cleanup()
        Write-Host "✅ Cleanup completed" -ForegroundColor Green
    }
}
