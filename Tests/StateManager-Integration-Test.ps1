# StateManager Integration Test Script
# Tests integration between StateManager and Entity System
param(
    [string]$TestScope = "All", # All, Basic, Advanced, Performance
    [switch]$Verbose,
    [switch]$CreateTestData
)

# Set error action and verbose preference
$ErrorActionPreference = "Stop"
if ($Verbose) { $VerbosePreference = "Continue" }

Write-Host "🎮 StateManager Integration Test Suite" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Import required modules
try {
    $ModulePath = Split-Path $PSScriptRoot -Parent
    Import-Module "$ModulePath\Modules\CoreGame\DataModels.psm1" -Force
    Import-Module "$ModulePath\Modules\CoreGame\StateManager.psm1" -Force
    Import-Module "$ModulePath\Modules\CoreGame\EventSystem.psm1" -Force
    Write-Host "✅ Modules imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import modules: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test tracking variables
$TestResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Details = @()
}

function Test-Assert {
    param(
        [bool]$Condition,
        [string]$TestName,
        [string]$ErrorMessage = "Assertion failed"
    )

    if ($Condition) {
        Write-Host "✅ $TestName" -ForegroundColor Green
        $script:TestResults.Passed++
        $script:TestResults.Details += @{ Test = $TestName; Result = "PASS"; Message = "" }
        return $true
    } else {
        Write-Host "❌ $TestName - $ErrorMessage" -ForegroundColor Red
        $script:TestResults.Failed++
        $script:TestResults.Details += @{ Test = $TestName; Result = "FAIL"; Message = $ErrorMessage }
        return $false
    }
}

function Test-Skip {
    param([string]$TestName, [string]$Reason)
    Write-Host "⏭️  $TestName - Skipped: $Reason" -ForegroundColor Yellow
    $script:TestResults.Skipped++
    $script:TestResults.Details += @{ Test = $TestName; Result = "SKIP"; Message = $Reason }
}

# Initialize test environment
Write-Host "`n🔧 Setting up test environment..." -ForegroundColor Yellow
try {
    # Clean up any existing state
    if (Test-Path "$env:TEMP\StateManagerTest") {
        Remove-Item "$env:TEMP\StateManagerTest" -Recurse -Force
    }

    # Initialize StateManager with test configuration
    Initialize-StateManager -SavesDirectory "$env:TEMP\StateManagerTest\Saves" -BackupsDirectory "$env:TEMP\StateManagerTest\Backups" -EnableAutoSave $false
    Write-Host "✅ StateManager initialized with test directories" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to initialize test environment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 1: Basic Entity Registration
if ($TestScope -eq "All" -or $TestScope -eq "Basic") {
    Write-Host "`n📝 Test 1: Basic Entity Registration" -ForegroundColor Cyan

    try {
        $testPlayer = New-PlayerEntity -Name "TestPlayer" -Level 1
        $result = Register-Entity -Entity $testPlayer -TrackChanges $true

        Test-Assert -Condition ($result.Success -eq $true) -TestName "Entity registration returns success"
        Test-Assert -Condition ($result.EntityId -eq $testPlayer.Id) -TestName "Entity ID matches registration result"
        Test-Assert -Condition ($result.EntityType -eq "Player") -TestName "Entity type correctly identified"
    } catch {
        Test-Assert -Condition $false -TestName "Basic Entity Registration" -ErrorMessage $_.Exception.Message
    }
}

# Test 2: Automatic Change Tracking
if ($TestScope -eq "All" -or $TestScope -eq "Basic") {
    Write-Host "`n🔄 Test 2: Automatic Change Tracking" -ForegroundColor Cyan

    try {
        $testNPC = New-NPCEntity -Name "TestNPC" -DialogueTree @("Hello", "Goodbye")
        Register-Entity -Entity $testNPC -TrackChanges $true

        # Modify the entity
        $originalName = $testNPC.GetProperty("Name")
        $testNPC.SetProperty("Name", "ModifiedNPC")

        Test-Assert -Condition ($testNPC.HasChanges()) -TestName "Entity tracks property changes"
        Test-Assert -Condition ($testNPC.GetProperty("Name") -eq "ModifiedNPC") -TestName "Property modification successful"

        # Test change acceptance
        $testNPC.AcceptChanges()
        Test-Assert -Condition (-not $testNPC.HasChanges()) -TestName "Changes accepted successfully"
    } catch {
        Test-Assert -Condition $false -TestName "Automatic Change Tracking" -ErrorMessage $_.Exception.Message
    }
}

# Test 3: Entity Collection Save/Load
if ($TestScope -eq "All" -or $TestScope -eq "Basic") {
    Write-Host "`n💾 Test 3: Entity Collection Save/Load" -ForegroundColor Cyan

    try {
        # Create test entity collection
        $entities = @{
            'Player' = @(
                (New-PlayerEntity -Name "Player1" -Level 5),
                (New-PlayerEntity -Name "Player2" -Level 3)
            )
            'NPC' = @(
                (New-NPCEntity -Name "Merchant" -DialogueTree @("Welcome to my shop")),
                (New-NPCEntity -Name "Guard" -DialogueTree @("Halt! Who goes there?"))
            )
            'Item' = @(
                (New-ItemEntity -Name "Sword" -Type "Weapon" -Value 100),
                (New-ItemEntity -Name "Potion" -Type "Consumable" -Value 25)
            )
        }

        # Save the collection
        $saveResult = Save-EntityCollection -Entities $entities -SaveName "test_collection"
        Test-Assert -Condition ($saveResult.Success -eq $true) -TestName "Entity collection save successful"

        # Load the collection
        $loadResult = Load-EntityCollection -SaveName "test_collection"
        Test-Assert -Condition ($loadResult.Success -eq $true) -TestName "Entity collection load successful"
        Test-Assert -Condition ($loadResult.Entities.Keys.Count -eq 3) -TestName "All entity types loaded"
        Test-Assert -Condition ($loadResult.Entities.Player.Count -eq 2) -TestName "Player entities loaded correctly"
        Test-Assert -Condition ($loadResult.Entities.NPC.Count -eq 2) -TestName "NPC entities loaded correctly"
        Test-Assert -Condition ($loadResult.Entities.Item.Count -eq 2) -TestName "Item entities loaded correctly"

        # Verify entity data integrity
        $loadedPlayer = $loadResult.Entities.Player | Where-Object { $_.GetProperty("Name") -eq "Player1" }
        Test-Assert -Condition ($loadedPlayer -ne $null) -TestName "Specific player entity found after load"
        Test-Assert -Condition ($loadedPlayer.GetProperty("Level") -eq 5) -TestName "Player data integrity maintained"

    } catch {
        Test-Assert -Condition $false -TestName "Entity Collection Save/Load" -ErrorMessage $_.Exception.Message
    }
}

# Test 4: Player Data Save/Load
if ($TestScope -eq "All" -or $TestScope -eq "Basic") {
    Write-Host "`n👤 Test 4: Player Data Save/Load" -ForegroundColor Cyan

    try {
        $player = New-PlayerEntity -Name "TestPlayerSave" -Level 10
        $player.SetProperty("Experience", 2500)
        $player.SetProperty("Gold", 1000)

        # Save player data
        $saveResult = Save-PlayerData -Player $player -SaveSlot "test_player"
        Test-Assert -Condition ($saveResult.Success -eq $true) -TestName "Player data save successful"

        # Load player data
        $loadResult = Load-PlayerData -SaveSlot "test_player"
        Test-Assert -Condition ($loadResult.Success -eq $true) -TestName "Player data load successful"
        Test-Assert -Condition ($loadResult.Player.GetProperty("Name") -eq "TestPlayerSave") -TestName "Player name preserved"
        Test-Assert -Condition ($loadResult.Player.GetProperty("Level") -eq 10) -TestName "Player level preserved"
        Test-Assert -Condition ($loadResult.Player.GetProperty("Experience") -eq 2500) -TestName "Player experience preserved"
        Test-Assert -Condition ($loadResult.Player.GetProperty("Gold") -eq 1000) -TestName "Player gold preserved"

    } catch {
        Test-Assert -Condition $false -TestName "Player Data Save/Load" -ErrorMessage $_.Exception.Message
    }
}

# Test 5: Save Integrity Validation
if ($TestScope -eq "All" -or $TestScope -eq "Advanced") {
    Write-Host "`n🔍 Test 5: Save Integrity Validation" -ForegroundColor Cyan

    try {
        # Test existing save
        $validationResult = Test-SaveIntegrity -SaveName "test_collection"
        Test-Assert -Condition ($validationResult.Success -eq $true) -TestName "Save integrity test runs successfully"
        Test-Assert -Condition ($validationResult.Valid -eq $true) -TestName "Save data is valid"
        Test-Assert -Condition ($validationResult.EntityCount -gt 0) -TestName "Save contains entities"
        Test-Assert -Condition ($validationResult.InvalidEntities -eq 0) -TestName "No invalid entities found"

        # Test non-existent save
        $invalidResult = Test-SaveIntegrity -SaveName "nonexistent_save"
        Test-Assert -Condition ($invalidResult.Success -eq $false) -TestName "Non-existent save properly handled"

    } catch {
        Test-Assert -Condition $false -TestName "Save Integrity Validation" -ErrorMessage $_.Exception.Message
    }
}

# Test 6: Entity Statistics
if ($TestScope -eq "All" -or $TestScope -eq "Advanced") {
    Write-Host "`n📊 Test 6: Entity Statistics" -ForegroundColor Cyan

    try {
        # Create test entities with changes
        $statsEntities = @{
            'Player' = @(
                (New-PlayerEntity -Name "StatsPlayer1" -Level 1),
                (New-PlayerEntity -Name "StatsPlayer2" -Level 2)
            )
            'Item' = @(
                (New-ItemEntity -Name "StatsItem1" -Type "Weapon" -Value 50)
            )
        }

        # Make some changes
        $statsEntities.Player[0].SetProperty("Level", 5)

        $stats = Get-EntityStatistics -Entities $statsEntities

        Test-Assert -Condition ($stats.TotalEntities -eq 3) -TestName "Total entity count correct"
        Test-Assert -Condition ($stats.EntityTypes.Player -eq 2) -TestName "Player entity count correct"
        Test-Assert -Condition ($stats.EntityTypes.Item -eq 1) -TestName "Item entity count correct"
        Test-Assert -Condition ($stats.ChangedEntities -eq 1) -TestName "Changed entity count correct"
        Test-Assert -Condition ($stats.DataSize -gt 0) -TestName "Data size calculated"

    } catch {
        Test-Assert -Condition $false -TestName "Entity Statistics" -ErrorMessage $_.Exception.Message
    }
}

# Test 7: Backup System
if ($TestScope -eq "All" -or $TestScope -eq "Advanced") {
    Write-Host "`n💼 Test 7: Backup System" -ForegroundColor Cyan

    try {
        $backupResult = Backup-GameState -SaveName "test_collection" -BackupReason "Test backup"
        Test-Assert -Condition ($backupResult.Success -eq $true) -TestName "Backup creation successful"
        Test-Assert -Condition ($backupResult.BackupName -ne $null) -TestName "Backup name generated"
        Test-Assert -Condition (Test-Path $backupResult.BackupPath) -TestName "Backup file created"
        Test-Assert -Condition ($backupResult.Metadata.BackupReason -eq "Test backup") -TestName "Backup metadata preserved"

    } catch {
        Test-Assert -Condition $false -TestName "Backup System" -ErrorMessage $_.Exception.Message
    }
}

# Test 8: Complex Entity Relationships
if ($TestScope -eq "All" -or $TestScope -eq "Advanced") {
    Write-Host "`n🔗 Test 8: Complex Entity Relationships" -ForegroundColor Cyan

    try {
        # Create interconnected entities
        $player = New-PlayerEntity -Name "RelationshipPlayer" -Level 10
        $quest = New-QuestEntity -Title "Test Quest" -Description "A test quest" -RequiredLevel 5
        $item = New-ItemEntity -Name "Quest Reward" -Type "Reward" -Value 500
        $npc = New-NPCEntity -Name "Quest Giver" -DialogueTree @("I have a quest for you")

        # Establish relationships
        $player.AcceptQuest($quest.Id)
        $player.AddToInventory($item.Id, 1)
        $quest.SetProperty("QuestGiver", $npc.Id)
        $quest.SetProperty("Rewards", @($item.Id))

        # Save complex entity collection
        $complexEntities = @{
            'Player' = @($player)
            'Quest' = @($quest)
            'Item' = @($item)
            'NPC' = @($npc)
        }

        $saveResult = Save-EntityCollection -Entities $complexEntities -SaveName "complex_test"
        Test-Assert -Condition ($saveResult.Success -eq $true) -TestName "Complex entity save successful"

        # Load and verify relationships
        $loadResult = Load-EntityCollection -SaveName "complex_test"
        Test-Assert -Condition ($loadResult.Success -eq $true) -TestName "Complex entity load successful"

        $loadedPlayer = $loadResult.Entities.Player[0]
        $loadedQuest = $loadResult.Entities.Quest[0]

        Test-Assert -Condition ($loadedPlayer.GetActiveQuests().Count -eq 1) -TestName "Player quest relationship preserved"
        Test-Assert -Condition ($loadedPlayer.GetInventory().Keys.Count -eq 1) -TestName "Player inventory preserved"
        Test-Assert -Condition ($loadedQuest.GetProperty("QuestGiver") -eq $npc.Id) -TestName "Quest NPC relationship preserved"

    } catch {
        Test-Assert -Condition $false -TestName "Complex Entity Relationships" -ErrorMessage $_.Exception.Message
    }
}

# Performance Tests (if requested)
if ($TestScope -eq "All" -or $TestScope -eq "Performance") {
    Write-Host "`n⚡ Test 9: Performance Tests" -ForegroundColor Cyan

    try {
        # Large entity collection test
        $largeEntities = @{
            'Player' = @()
            'NPC' = @()
            'Item' = @()
        }

        # Create 100 entities of each type
        Write-Host "Creating large entity collection..." -ForegroundColor Yellow
        for ($i = 1; $i -le 100; $i++) {
            $largeEntities.Player += New-PlayerEntity -Name "Player$i" -Level (Get-Random -Minimum 1 -Maximum 50)
            $largeEntities.NPC += New-NPCEntity -Name "NPC$i" -DialogueTree @("Hello from NPC $i")
            $largeEntities.Item += New-ItemEntity -Name "Item$i" -Type "Generic" -Value (Get-Random -Minimum 1 -Maximum 1000)
        }

        # Performance test: Save large collection
        $saveStart = Get-Date
        $saveResult = Save-EntityCollection -Entities $largeEntities -SaveName "performance_test"
        $saveTime = (Get-Date) - $saveStart

        Test-Assert -Condition ($saveResult.Success -eq $true) -TestName "Large entity collection save successful"
        Test-Assert -Condition ($saveTime.TotalSeconds -lt 30) -TestName "Save performance acceptable (< 30 seconds)" -ErrorMessage "Save took $($saveTime.TotalSeconds) seconds"

        # Performance test: Load large collection
        $loadStart = Get-Date
        $loadResult = Load-EntityCollection -SaveName "performance_test"
        $loadTime = (Get-Date) - $loadStart

        Test-Assert -Condition ($loadResult.Success -eq $true) -TestName "Large entity collection load successful"
        Test-Assert -Condition ($loadTime.TotalSeconds -lt 30) -TestName "Load performance acceptable (< 30 seconds)" -ErrorMessage "Load took $($loadTime.TotalSeconds) seconds"
        Test-Assert -Condition ($loadResult.Entities.Player.Count -eq 100) -TestName "All players loaded correctly"
        Test-Assert -Condition ($loadResult.Entities.NPC.Count -eq 100) -TestName "All NPCs loaded correctly"
        Test-Assert -Condition ($loadResult.Entities.Item.Count -eq 100) -TestName "All items loaded correctly"

        Write-Host "Performance Results:" -ForegroundColor Green
        Write-Host "  Save Time: $($saveTime.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
        Write-Host "  Load Time: $($loadTime.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Gray
        Write-Host "  Total Entities: 300" -ForegroundColor Gray

    } catch {
        Test-Assert -Condition $false -TestName "Performance Tests" -ErrorMessage $_.Exception.Message
    }
}

# Test 10: Error Handling and Edge Cases
if ($TestScope -eq "All" -or $TestScope -eq "Advanced") {
    Write-Host "`n🚨 Test 10: Error Handling and Edge Cases" -ForegroundColor Cyan

    try {
        # Test invalid entity registration
        try {
            Register-Entity -Entity "Invalid Object"
            Test-Assert -Condition $false -TestName "Invalid entity rejection" -ErrorMessage "Should have thrown exception"
        } catch {
            Test-Assert -Condition $true -TestName "Invalid entity properly rejected"
        }

        # Test load non-existent save
        $invalidLoad = Load-EntityCollection -SaveName "does_not_exist"
        Test-Assert -Condition ($invalidLoad.Success -eq $false) -TestName "Non-existent save handled gracefully"

        # Test empty entity collection
        $emptyResult = Save-EntityCollection -Entities @{} -SaveName "empty_test"
        Test-Assert -Condition ($emptyResult.Success -eq $true) -TestName "Empty entity collection save handled"

        $emptyLoad = Load-EntityCollection -SaveName "empty_test"
        Test-Assert -Condition ($emptyLoad.Success -eq $true) -TestName "Empty entity collection load handled"

    } catch {
        Test-Assert -Condition $false -TestName "Error Handling and Edge Cases" -ErrorMessage $_.Exception.Message
    }
}

# Test Results Summary
Write-Host "`n📋 Test Results Summary" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host "✅ Passed: $($TestResults.Passed)" -ForegroundColor Green
Write-Host "❌ Failed: $($TestResults.Failed)" -ForegroundColor Red
Write-Host "⏭️  Skipped: $($TestResults.Skipped)" -ForegroundColor Yellow
Write-Host "Total Tests: $($TestResults.Passed + $TestResults.Failed + $TestResults.Skipped)" -ForegroundColor White

if ($TestResults.Failed -eq 0) {
    Write-Host "`n🎉 All tests passed! StateManager integration is working correctly." -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Some tests failed. Check the details above." -ForegroundColor Yellow
}

# Optional: Show detailed results
if ($Verbose) {
    Write-Host "`n📝 Detailed Test Results:" -ForegroundColor Cyan
    foreach ($detail in $TestResults.Details) {
        $color = switch ($detail.Result) {
            "PASS" { "Green" }
            "FAIL" { "Red" }
            "SKIP" { "Yellow" }
        }
        Write-Host "  [$($detail.Result)] $($detail.Test)" -ForegroundColor $color
        if ($detail.Message) {
            Write-Host "    $($detail.Message)" -ForegroundColor Gray
        }
    }
}

# Clean up test environment
Write-Host "`n🧹 Cleaning up test environment..." -ForegroundColor Yellow
try {
    if (Test-Path "$env:TEMP\StateManagerTest") {
        Remove-Item "$env:TEMP\StateManagerTest" -Recurse -Force
    }
    Write-Host "✅ Test environment cleaned up" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Warning: Could not clean up test environment: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n🎮 StateManager Integration Test Complete!" -ForegroundColor Cyan

# Return exit code based on test results
if ($TestResults.Failed -gt 0) {
    exit 1
} else {
    exit 0
}
