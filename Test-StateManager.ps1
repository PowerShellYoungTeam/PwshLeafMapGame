# PowerShell State Management Demo
# Demonstrates comprehensive state management, save/load, and browser synchronization

# Import required modules
$ModulePath = Join-Path $PSScriptRoot "Modules\CoreGame"
Import-Module (Join-Path $ModulePath "StateManager.psm1") -Force
Import-Module (Join-Path $ModulePath "DataModels.psm1") -Force

Write-Host "=== PowerShell Leafmap Game - State Management Demo ===" -ForegroundColor Cyan
Write-Host ""

try {
    # Initialize State Manager
    Write-Host "🚀 Initializing State Manager..." -ForegroundColor Green
    $initResult = Initialize-StateManager -Configuration @{
        AutoSaveInterval = 60  # 1 minute for demo
        CompressionEnabled = $true
        StateValidation = $true
        ConflictResolution = "LastWriteWins"
    }

    if ($initResult.Success) {
        Write-Host "✅ State Manager initialized successfully" -ForegroundColor Green
    }

    # Create demo game entities
    Write-Host ""
    Write-Host "🎮 Creating demo game entities..." -ForegroundColor Yellow

    # Create player entities
    $player1 = @{
        Username = "DemoPlayer1"
        Email = "player1@demo.com"
        DisplayName = "Demo Player One"
        Level = 5
        Experience = 2500
        Location = @{ Name = "Starter Town"; Id = "town_001" }
        Inventory = @("Health Potion", "Iron Sword", "Magic Ring")
        Currency = 150
        Achievements = @(
            @{ Id = "first_kill"; Name = "First Kill"; Earned = (Get-Date).AddDays(-2) }
            @{ Id = "level_5"; Name = "Level 5 Hero"; Earned = (Get-Date).AddHours(-3) }
        )
    }

    $player2 = @{
        Username = "DemoPlayer2"
        Email = "player2@demo.com"
        DisplayName = "Demo Player Two"
        Level = 3
        Experience = 1200
        Location = @{ Name = "Forest Grove"; Id = "forest_001" }
        Inventory = @("Health Potion", "Wooden Staff")
        Currency = 75
        Achievements = @(
            @{ Id = "first_spell"; Name = "First Spell Cast"; Earned = (Get-Date).AddDays(-1) }
        )
    }

    # Register entities with state manager
    Register-GameEntity -EntityId "player_001" -EntityType "Player" -InitialState $player1
    Register-GameEntity -EntityId "player_002" -EntityType "Player" -InitialState $player2

    # Create NPC entities
    $npc1 = @{
        Name = "Village Elder"
        NPCType = "Questgiver"
        Location = @{ Name = "Starter Town"; Id = "town_001" }
        Dialogue = @("Welcome, young adventurer!", "I have a quest for you.")
        QuestOffered = "gather_herbs"
        IsAvailable = $true
    }

    $npc2 = @{
        Name = "Weapon Merchant"
        NPCType = "Vendor"
        Location = @{ Name = "Starter Town"; Id = "town_001" }
        Inventory = @("Iron Sword", "Steel Armor", "Magic Bow")
        Currency = 500
        IsAvailable = $true
    }

    Register-GameEntity -EntityId "npc_001" -EntityType "NPC" -InitialState $npc1
    Register-GameEntity -EntityId "npc_002" -EntityType "NPC" -InitialState $npc2

    Write-Host "✅ Created 4 demo entities (2 players, 2 NPCs)" -ForegroundColor Green

    # Demonstrate state updates
    Write-Host ""
    Write-Host "🔄 Demonstrating state updates..." -ForegroundColor Yellow

    # Player 1 gains experience and levels up
    Update-GameEntityState -EntityId "player_001" -Property "Experience" -Value 3000
    Update-GameEntityState -EntityId "player_001" -Property "Level" -Value 6
    Update-GameEntityState -EntityId "player_001" -Property "Currency" -Value 200

    # Player 1 visits new location
    $newLocation = @{ Name = "Dragon's Lair"; Id = "dungeon_001" }
    Update-GameEntityState -EntityId "player_001" -Property "Location" -Value $newLocation

    # Player 2 gets new item
    $updatedInventory = @("Health Potion", "Wooden Staff", "Magic Scroll")
    Update-GameEntityState -EntityId "player_002" -Property "Inventory" -Value $updatedInventory

    # NPC becomes unavailable
    Update-GameEntityState -EntityId "npc_001" -Property "IsAvailable" -Value $false

    Write-Host "✅ Applied 6 state updates across entities" -ForegroundColor Green

    # Save game state
    Write-Host ""
    Write-Host "💾 Saving game state..." -ForegroundColor Yellow

    $saveResult = Save-GameState -SaveName "demo_save" -AdditionalData @{
        GameMode = "Adventure"
        Difficulty = "Normal"
        SessionId = [System.Guid]::NewGuid().ToString()
    }

    if ($saveResult.Success) {
        Write-Host "✅ Game saved successfully:" -ForegroundColor Green
        Write-Host "   📁 File: $($saveResult.SaveFile)" -ForegroundColor Cyan
        Write-Host "   📊 Size: $($saveResult.SaveSize) bytes" -ForegroundColor Cyan
        Write-Host "   ⏱️ Time: $($saveResult.SaveTime) ms" -ForegroundColor Cyan
        Write-Host "   🎯 Entities: $($saveResult.Entities)" -ForegroundColor Cyan
    }

    # Create a second save with different name
    Write-Host ""
    Write-Host "💾 Creating checkpoint save..." -ForegroundColor Yellow

    # Make more changes first
    Update-GameEntityState -EntityId "player_001" -Property "Experience" -Value 3500
    Update-GameEntityState -EntityId "player_002" -Property "Level" -Value 4

    $checkpointResult = Save-GameState -SaveName "checkpoint_1" -AdditionalData @{
        GameMode = "Adventure"
        Difficulty = "Normal"
        CheckpointType = "Manual"
    }

    if ($checkpointResult.Success) {
        Write-Host "✅ Checkpoint saved successfully" -ForegroundColor Green
    }

    # List all save files
    Write-Host ""
    Write-Host "📋 Available save files:" -ForegroundColor Yellow
    $saveFiles = Get-SaveFiles
    foreach ($save in $saveFiles) {
        Write-Host "   📄 $($save.Name) - $($save.Size) bytes - $($save.Modified)" -ForegroundColor Cyan
    }

    # Demonstrate state loading
    Write-Host ""
    Write-Host "📥 Loading previous save state..." -ForegroundColor Yellow

    $loadResult = Load-GameState -SaveName "demo_save"

    if ($loadResult.Success) {
        Write-Host "✅ Save loaded successfully:" -ForegroundColor Green
        Write-Host "   ⏱️ Time: $($loadResult.LoadTime) ms" -ForegroundColor Cyan
        Write-Host "   🎯 Entities: $($loadResult.Entities)" -ForegroundColor Cyan

        # Verify loaded state
        $loadedPlayer1 = $Global:StateManager.GetEntityState("player_001")
        Write-Host "   🎮 Player 1 Level: $($loadedPlayer1.Level) (Experience: $($loadedPlayer1.Experience))" -ForegroundColor Cyan
        Write-Host "   📍 Player 1 Location: $($loadedPlayer1.Location.Name)" -ForegroundColor Cyan
    }

    # Demonstrate browser export/import
    Write-Host ""
    Write-Host "🌐 Demonstrating browser synchronization..." -ForegroundColor Yellow

    # Export state for browser
    $browserExport = Export-StateForBrowser -Format "JSON"
    $exportSize = [System.Text.Encoding]::UTF8.GetByteCount($browserExport)
    Write-Host "✅ Exported state for browser: $exportSize bytes" -ForegroundColor Green

    # Simulate browser state changes
    $browserData = $browserExport | ConvertFrom-Json -AsHashtable

    # Modify browser state (simulate player actions in browser)
    $browserData.Entities["player_001"].State.Currency = 250
    $browserData.Entities["player_001"].State.Experience = 4000
    $browserData.Entities["player_002"].State.Currency = 100

    # Add a new entity from browser
    $browserData.Entities["item_001"] = @{
        EntityType = "Item"
        State = @{
            Name = "Dragon Scale"
            ItemType = "Crafting Material"
            Value = 50
            Rarity = "Rare"
        }
        LastModified = (Get-Date)
        IsDirty = $true
    }

    $modifiedBrowserData = $browserData | ConvertTo-Json -Depth 20

    # Import modified state from browser
    Write-Host ""
    Write-Host "📥 Importing modified state from browser..." -ForegroundColor Yellow

    $importResult = Import-StateFromBrowser -BrowserData $modifiedBrowserData -Format "JSON"

    if ($importResult.Success) {
        Write-Host "✅ Browser state imported successfully:" -ForegroundColor Green
        Write-Host "   🎯 Imported entities: $($importResult.ImportedEntities)" -ForegroundColor Cyan

        # Verify imported changes
        $updatedPlayer1 = $Global:StateManager.GetEntityState("player_001")
        Write-Host "   💰 Player 1 Currency: $($updatedPlayer1.Currency)" -ForegroundColor Cyan
        Write-Host "   ⭐ Player 1 Experience: $($updatedPlayer1.Experience)" -ForegroundColor Cyan

        # Check if new item was added
        if ($Global:StateManager.Trackers.ContainsKey("item_001")) {
            $newItem = $Global:StateManager.GetEntityState("item_001")
            Write-Host "   🎁 New item added: $($newItem.Name) ($($newItem.ItemType))" -ForegroundColor Cyan
        }
    }

    # Display comprehensive statistics
    Write-Host ""
    Write-Host "📊 State Management Statistics:" -ForegroundColor Yellow
    $stats = Get-StateStatistics

    Write-Host "   🎯 Tracked Entities: $($stats.TrackedEntities)" -ForegroundColor Cyan
    Write-Host "   🔄 Dirty Entities: $($stats.DirtyEntities)" -ForegroundColor Cyan
    Write-Host "   📝 Total Changes: $($stats.TotalChanges)" -ForegroundColor Cyan
    Write-Host "   💾 Save Count: $($stats.Performance.SaveCount)" -ForegroundColor Cyan
    Write-Host "   📥 Load Count: $($stats.Performance.LoadCount)" -ForegroundColor Cyan
    Write-Host "   📡 Sync Count: $($stats.Performance.SyncCount)" -ForegroundColor Cyan
    Write-Host "   ⏱️ Avg Save Time: $([math]::Round($stats.Performance.AverageSaveTime, 2)) ms" -ForegroundColor Cyan
    Write-Host "   ⏱️ Avg Load Time: $([math]::Round($stats.Performance.AverageLoadTime, 2)) ms" -ForegroundColor Cyan
    Write-Host "   📈 Total Data Size: $($stats.Performance.TotalDataSize) bytes" -ForegroundColor Cyan
    Write-Host "   ❌ Error Count: $($stats.Performance.ErrorCount)" -ForegroundColor Cyan

    # Demonstrate conflict resolution
    Write-Host ""
    Write-Host "⚔️ Demonstrating conflict resolution..." -ForegroundColor Yellow

    # Create conflicting browser state
    $conflictBrowserState = @{
        Version = "1.0.0"
        Entities = @{
            "player_001" = @{
                EntityType = "Player"
                State = @{
                    Currency = 300  # Different from current state
                    Level = 7       # Different from current state
                    Experience = 5000
                }
                LastModified = (Get-Date).AddMinutes(5)  # Newer timestamp
                IsDirty = $true
            }
        }
        GameState = @{}
        Metadata = @{
            ExportedAt = Get-Date
            Platform = "JavaScript"
        }
    }

    $conflictData = $conflictBrowserState | ConvertTo-Json -Depth 20

    # Sync with conflict resolution
    $syncResult = Sync-StateWithBrowser -BrowserState $conflictBrowserState -SyncMode "Merge"

    if ($syncResult.Success) {
        Write-Host "✅ Conflict resolution completed:" -ForegroundColor Green
        Write-Host "   ⚡ Conflicts detected: $($syncResult.ConflictCount)" -ForegroundColor Cyan
        Write-Host "   🔄 Updated entities: $($syncResult.UpdatedEntities.Count)" -ForegroundColor Cyan

        # Verify conflict resolution
        $resolvedPlayer1 = $Global:StateManager.GetEntityState("player_001")
        Write-Host "   🎯 Resolved Player 1 Currency: $($resolvedPlayer1.Currency)" -ForegroundColor Cyan
        Write-Host "   📊 Resolved Player 1 Level: $($resolvedPlayer1.Level)" -ForegroundColor Cyan
    }

    # Final save after all operations
    Write-Host ""
    Write-Host "💾 Final save after all operations..." -ForegroundColor Yellow

    $finalSave = Save-GameState -SaveName "final_demo" -AdditionalData @{
        DemoCompleted = $true
        TotalOperations = 15
        CompletedAt = Get-Date
    }

    if ($finalSave.Success) {
        Write-Host "✅ Final save completed successfully" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "🎉 State Management Demo Completed Successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Demo Summary:" -ForegroundColor Cyan
    Write-Host "   ✅ State Manager initialized" -ForegroundColor White
    Write-Host "   ✅ Multiple entities created and tracked" -ForegroundColor White
    Write-Host "   ✅ State updates and change tracking" -ForegroundColor White
    Write-Host "   ✅ Save and load operations" -ForegroundColor White
    Write-Host "   ✅ Browser export/import simulation" -ForegroundColor White
    Write-Host "   ✅ Conflict resolution demonstration" -ForegroundColor White
    Write-Host "   ✅ Performance metrics collection" -ForegroundColor White
    Write-Host "   ✅ Comprehensive state validation" -ForegroundColor White

    Write-Host ""
    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Integrate with your game modules" -ForegroundColor White
    Write-Host "   2. Set up browser-PowerShell communication" -ForegroundColor White
    Write-Host "   3. Configure auto-save intervals" -ForegroundColor White
    Write-Host "   4. Implement encryption if needed" -ForegroundColor White
    Write-Host "   5. Set up cloud synchronization" -ForegroundColor White

}
catch {
    Write-Error "Demo failed: $($_.Exception.Message)"
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
finally {
    # Cleanup
    if ($Global:StateManager) {
        Write-Host ""
        Write-Host "🧹 Cleaning up State Manager..." -ForegroundColor Yellow
        $Global:StateManager.Cleanup()
        Write-Host "✅ Cleanup completed" -ForegroundColor Green
    }
}
