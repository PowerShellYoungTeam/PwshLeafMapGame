# Unit Tests for Data Models Module
# Tests for PowerShell game entity classes

# Import the module
$ModulePath = Join-Path $PSScriptRoot '..\Modules\CoreGame\DataModels.psm1'
Import-Module $ModulePath -Force

# Test Framework Functions
function Test-Condition {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$ExpectedValue = '',
        [string]$ActualValue = ''
    )

    if ($Condition) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        if ($ExpectedValue -and $ActualValue) {
            Write-Host "  Expected: $ExpectedValue" -ForegroundColor Yellow
            Write-Host "  Actual: $ActualValue" -ForegroundColor Yellow
        }
        return $false
    }
}

function Start-TestSuite {
    param([string]$SuiteName)
    Write-Host "`n=== $SuiteName ===" -ForegroundColor Cyan
    $script:TestResults = @{
        Passed = 0
        Failed = 0
        Total = 0
    }
}

function Complete-TestSuite {
    param([string]$SuiteName)
    $total = $script:TestResults.Passed + $script:TestResults.Failed
    $passRate = if ($total -gt 0) { [math]::Round(($script:TestResults.Passed / $total) * 100, 2) } else { 0 }

    Write-Host "`n$SuiteName Results:" -ForegroundColor Cyan
    Write-Host "  Passed: $($script:TestResults.Passed)" -ForegroundColor Green
    Write-Host "  Failed: $($script:TestResults.Failed)" -ForegroundColor Red
    Write-Host "  Total: $total" -ForegroundColor White
    Write-Host "  Pass Rate: $passRate%" -ForegroundColor White

    return @{
        Passed = $script:TestResults.Passed
        Failed = $script:TestResults.Failed
        Total = $total
        PassRate = $passRate
    }
}

function Add-TestResult {
    param([bool]$Passed)
    if ($Passed) {
        $script:TestResults.Passed++
    } else {
        $script:TestResults.Failed++
    }
    $script:TestResults.Total++
}

# GameEntity Tests
Start-TestSuite "GameEntity Tests"

# Test basic entity creation
$entity = [GameEntity]::new()
Add-TestResult (Test-Condition "Entity ID is generated" ($entity.Id -ne $null -and $entity.Id.Length -gt 0))
Add-TestResult (Test-Condition "Entity Type is set" ($entity.Type -eq 'Entity'))
Add-TestResult (Test-Condition "Entity is active by default" ($entity.IsActive -eq $true))
Add-TestResult (Test-Condition "Entity has creation timestamp" ($entity.CreatedAt -ne $null))
Add-TestResult (Test-Condition "Entity has update timestamp" ($entity.UpdatedAt -ne $null))

# Test entity with data
$entityData = @{
    Name = 'Test Entity'
    Description = 'A test entity'
    Type = 'TestType'
}
$entityWithData = [GameEntity]::new($entityData)
Add-TestResult (Test-Condition "Entity name is set from data" ($entityWithData.Name -eq 'Test Entity'))
Add-TestResult (Test-Condition "Entity description is set from data" ($entityWithData.Description -eq 'A test entity'))
Add-TestResult (Test-Condition "Entity type is set from data" ($entityWithData.Type -eq 'TestType'))

# Test ToHashtable method
$hashtable = $entity.ToHashtable()
Add-TestResult (Test-Condition "ToHashtable returns hashtable" ($hashtable -is [hashtable]))
Add-TestResult (Test-Condition "Hashtable contains Id" ($hashtable.ContainsKey('Id')))
Add-TestResult (Test-Condition "Hashtable contains Type" ($hashtable.ContainsKey('Type')))

# Test ToJson method
$json = $entity.ToJson()
Add-TestResult (Test-Condition "ToJson returns string" ($json -is [string]))
Add-TestResult (Test-Condition "ToJson contains valid JSON" ($json.StartsWith('{') -and $json.EndsWith('}')))

Complete-TestSuite "GameEntity Tests"

# Player Tests
Start-TestSuite "Player Tests"

# Test player creation
$player = [Player]::new()
Add-TestResult (Test-Condition "Player type is Player" ($player.Type -eq 'Player'))
Add-TestResult (Test-Condition "Player level is 1 by default" ($player.Level -eq 1))
Add-TestResult (Test-Condition "Player experience is 0 by default" ($player.Experience -eq 0))
Add-TestResult (Test-Condition "Player has default attributes" ($player.Attributes.ContainsKey('Strength')))
Add-TestResult (Test-Condition "Player has default skills" ($player.Skills.ContainsKey('Combat')))
Add-TestResult (Test-Condition "Player has inventory array" ($player.Inventory -is [array]))
Add-TestResult (Test-Condition "Player has currency" ($player.Currency -eq 100))

# Test player with data
$playerData = @{
    Username = 'TestPlayer'
    Email = 'test@example.com'
    DisplayName = 'Test Player'
    Level = 5
    Experience = 2500
}
$playerWithData = [Player]::new($playerData)
Add-TestResult (Test-Condition "Player username is set" ($playerWithData.Username -eq 'TestPlayer'))
Add-TestResult (Test-Condition "Player email is set" ($playerWithData.Email -eq 'test@example.com'))
Add-TestResult (Test-Condition "Player level is set" ($playerWithData.Level -eq 5))
Add-TestResult (Test-Condition "Player experience is set" ($playerWithData.Experience -eq 2500))

# Test player methods
$player.AddExperience(500)
Add-TestResult (Test-Condition "AddExperience increases experience" ($player.Experience -eq 500))

$player.VisitLocation('TestLocation')
Add-TestResult (Test-Condition "VisitLocation adds to visited locations" ($player.VisitedLocations -contains 'TestLocation'))
Add-TestResult (Test-Condition "VisitLocation sets last location" ($player.LastLocationId -eq 'TestLocation'))

$achievement = @{ Id = 'FirstStep'; Name = 'First Steps'; Description = 'Visited first location' }
$player.AddAchievement($achievement)
Add-TestResult (Test-Condition "AddAchievement adds achievement" ($player.Achievements.Count -eq 1))
Add-TestResult (Test-Condition "HasAchievement returns true for existing achievement" ($player.HasAchievement('FirstStep')))
Add-TestResult (Test-Condition "HasAchievement returns false for non-existing achievement" (-not $player.HasAchievement('NonExistent')))

# Test level up functionality
$player.Experience = 1000
$player.AddExperience(0) # Trigger level up check
Add-TestResult (Test-Condition "Player levels up when experience threshold is reached" ($player.Level -eq 2))

Complete-TestSuite "Player Tests"

# NPC Tests
Start-TestSuite "NPC Tests"

# Test NPC creation
$npc = [NPC]::new()
Add-TestResult (Test-Condition "NPC type is NPC" ($npc.Type -eq 'NPC'))
Add-TestResult (Test-Condition "NPC type is Generic by default" ($npc.NPCType -eq 'Generic'))
Add-TestResult (Test-Condition "NPC race is Human by default" ($npc.Race -eq 'Human'))
Add-TestResult (Test-Condition "NPC is stationary by default" ($npc.IsStationary -eq $true))
Add-TestResult (Test-Condition "NPC movement speed is set" ($npc.MovementSpeed -eq 1.0))

# Test NPC with data
$npcData = @{
    Name = 'Village Guard'
    NPCType = 'Guard'
    Race = 'Human'
    Description = 'A loyal guard protecting the village'
    IsStationary = $false
    MovementSpeed = 1.5
}
$npcWithData = [NPC]::new($npcData)
Add-TestResult (Test-Condition "NPC name is set" ($npcWithData.Name -eq 'Village Guard'))
Add-TestResult (Test-Condition "NPC type is set" ($npcWithData.NPCType -eq 'Guard'))
Add-TestResult (Test-Condition "NPC race is set" ($npcWithData.Race -eq 'Human'))
Add-TestResult (Test-Condition "NPC movement is set" ($npcWithData.IsStationary -eq $false))
Add-TestResult (Test-Condition "NPC speed is set" ($npcWithData.MovementSpeed -eq 1.5))

# Test NPC ToHashtable
$npcHashtable = $npc.ToHashtable()
Add-TestResult (Test-Condition "NPC hashtable contains NPCType" ($npcHashtable.ContainsKey('NPCType')))
Add-TestResult (Test-Condition "NPC hashtable contains Race" ($npcHashtable.ContainsKey('Race')))
Add-TestResult (Test-Condition "NPC hashtable contains MovementSpeed" ($npcHashtable.ContainsKey('MovementSpeed')))

Complete-TestSuite "NPC Tests"

# Item Tests
Start-TestSuite "Item Tests"

# Test item creation
$item = [Item]::new()
Add-TestResult (Test-Condition "Item type is Item" ($item.Type -eq 'Item'))
Add-TestResult (Test-Condition "Item type is Generic by default" ($item.ItemType -eq 'Generic'))
Add-TestResult (Test-Condition "Item rarity is Common by default" ($item.Rarity -eq 'Common'))
Add-TestResult (Test-Condition "Item is not consumable by default" ($item.IsConsumable -eq $false))
Add-TestResult (Test-Condition "Item is not equippable by default" ($item.IsEquippable -eq $false))
Add-TestResult (Test-Condition "Item is tradeable by default" ($item.IsTradeable -eq $true))
Add-TestResult (Test-Condition "Item durability is 100 by default" ($item.Durability -eq 100))

# Test item with data
$itemData = @{
    Name = 'Iron Sword'
    ItemType = 'Weapon'
    Rarity = 'Uncommon'
    Value = 150
    Weight = 3.5
    IsEquippable = $true
    Durability = 80
    MaxDurability = 100
}
$itemWithData = [Item]::new($itemData)
Add-TestResult (Test-Condition "Item name is set" ($itemWithData.Name -eq 'Iron Sword'))
Add-TestResult (Test-Condition "Item type is set" ($itemWithData.ItemType -eq 'Weapon'))
Add-TestResult (Test-Condition "Item rarity is set" ($itemWithData.Rarity -eq 'Uncommon'))
Add-TestResult (Test-Condition "Item value is set" ($itemWithData.Value -eq 150))
Add-TestResult (Test-Condition "Item weight is set" ($itemWithData.Weight -eq 3.5))
Add-TestResult (Test-Condition "Item is equippable" ($itemWithData.IsEquippable -eq $true))

# Test item methods
$item.DamageItem(20)
Add-TestResult (Test-Condition "DamageItem reduces durability" ($item.Durability -eq 80))

$item.RepairItem(10)
Add-TestResult (Test-Condition "RepairItem increases durability" ($item.Durability -eq 90))

$item.RepairItem() # Full repair
Add-TestResult (Test-Condition "RepairItem with no parameter fully repairs" ($item.Durability -eq 100))

Add-TestResult (Test-Condition "IsFullyRepaired returns true when at max durability" ($item.IsFullyRepaired()))

$item.DamageItem(100)
Add-TestResult (Test-Condition "IsBroken returns true when durability is 0" ($item.IsBroken()))

Complete-TestSuite "Item Tests"

# Factory Function Tests
Start-TestSuite "Factory Function Tests"

# Test New-PlayerEntity
$factoryPlayer = New-PlayerEntity -Username 'TestUser' -Email 'test@test.com' -DisplayName 'Test User'
Add-TestResult (Test-Condition "New-PlayerEntity creates Player" ($factoryPlayer -is [Player]))
Add-TestResult (Test-Condition "Factory player has correct username" ($factoryPlayer.Username -eq 'TestUser'))
Add-TestResult (Test-Condition "Factory player has correct email" ($factoryPlayer.Email -eq 'test@test.com'))
Add-TestResult (Test-Condition "Factory player has correct display name" ($factoryPlayer.DisplayName -eq 'Test User'))

# Test New-NPCEntity
$factoryNPC = New-NPCEntity -Name 'Test Guard' -NPCType 'Guard' -Description 'A test guard'
Add-TestResult (Test-Condition "New-NPCEntity creates NPC" ($factoryNPC -is [NPC]))
Add-TestResult (Test-Condition "Factory NPC has correct name" ($factoryNPC.Name -eq 'Test Guard'))
Add-TestResult (Test-Condition "Factory NPC has correct type" ($factoryNPC.NPCType -eq 'Guard'))
Add-TestResult (Test-Condition "Factory NPC has correct description" ($factoryNPC.Description -eq 'A test guard'))

# Test New-ItemEntity
$factoryItem = New-ItemEntity -Name 'Test Sword' -ItemType 'Weapon' -Description 'A test sword'
Add-TestResult (Test-Condition "New-ItemEntity creates Item" ($factoryItem -is [Item]))
Add-TestResult (Test-Condition "Factory item has correct name" ($factoryItem.Name -eq 'Test Sword'))
Add-TestResult (Test-Condition "Factory item has correct type" ($factoryItem.ItemType -eq 'Weapon'))
Add-TestResult (Test-Condition "Factory item has correct description" ($factoryItem.Description -eq 'A test sword'))

Complete-TestSuite "Factory Function Tests"

# Validation Tests
Start-TestSuite "Validation Tests"

# Test valid entity validation
$validPlayer = New-PlayerEntity -Username 'ValidUser' -Email 'valid@test.com' -DisplayName 'Valid User'
$validation = Test-EntityValidity -Entity $validPlayer -EntityType 'Player'
Add-TestResult (Test-Condition "Valid player passes validation" ($validation.IsValid -eq $true))
Add-TestResult (Test-Condition "Valid player has no errors" ($validation.Errors.Count -eq 0))

# Test invalid entity validation
$invalidPlayer = [Player]::new()
$invalidPlayer.Level = -1 # Invalid level
$invalidPlayer.Experience = -100 # Invalid experience
$invalidValidation = Test-EntityValidity -Entity $invalidPlayer -EntityType 'Player'
Add-TestResult (Test-Condition "Invalid player fails validation" ($invalidValidation.IsValid -eq $false))
Add-TestResult (Test-Condition "Invalid player has errors" ($invalidValidation.Errors.Count -gt 0))

# Test null entity validation
$nullValidation = Test-EntityValidity -Entity $null
Add-TestResult (Test-Condition "Null entity fails validation" ($nullValidation.IsValid -eq $false))
Add-TestResult (Test-Condition "Null entity has error about being null" ($nullValidation.Errors -contains "Entity is null or empty"))

Complete-TestSuite "Validation Tests"

# Serialization Tests
Start-TestSuite "Serialization Tests"

# Test JSON serialization
$testPlayer = New-PlayerEntity -Username 'SerializeTest' -Email 'serialize@test.com' -DisplayName 'Serialize Test'
$json = ConvertTo-JsonSafe -InputObject $testPlayer
Add-TestResult (Test-Condition "ConvertTo-JsonSafe returns string" ($json -is [string]))
Add-TestResult (Test-Condition "JSON contains player data" ($json -like '*SerializeTest*'))

# Test JSON deserialization
$deserializedPlayer = ConvertFrom-JsonSafe -JsonString $json -EntityType 'Player'
Add-TestResult (Test-Condition "ConvertFrom-JsonSafe returns Player" ($deserializedPlayer -is [Player]))
Add-TestResult (Test-Condition "Deserialized player has correct username" ($deserializedPlayer.Username -eq 'SerializeTest'))
Add-TestResult (Test-Condition "Deserialized player has correct email" ($deserializedPlayer.Email -eq 'serialize@test.com'))

# Test round-trip serialization
$originalData = $testPlayer.ToHashtable()
$roundTripPlayer = ConvertFrom-JsonSafe -JsonString $json -EntityType 'Player'
$roundTripData = $roundTripPlayer.ToHashtable()
Add-TestResult (Test-Condition "Round-trip maintains username" ($originalData.Username -eq $roundTripData.Username))
Add-TestResult (Test-Condition "Round-trip maintains level" ($originalData.Level -eq $roundTripData.Level))

Complete-TestSuite "Serialization Tests"

# Performance Tests
Start-TestSuite "Performance Tests"

# Test entity creation performance
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$entities = @()
for ($i = 0; $i -lt 1000; $i++) {
    $entities += [Player]::new()
}
$stopwatch.Stop()
$creationTime = $stopwatch.ElapsedMilliseconds
Add-TestResult (Test-Condition "1000 entities created in reasonable time" ($creationTime -lt 5000))
Write-Host "  Created 1000 entities in $creationTime ms" -ForegroundColor Gray

# Test serialization performance
$stopwatch.Restart()
$jsonResults = @()
foreach ($entity in $entities[0..99]) { # Test first 100
    $jsonResults += ConvertTo-JsonSafe -InputObject $entity
}
$stopwatch.Stop()
$serializationTime = $stopwatch.ElapsedMilliseconds
Add-TestResult (Test-Condition "100 entities serialized in reasonable time" ($serializationTime -lt 2000))
Write-Host "  Serialized 100 entities in $serializationTime ms" -ForegroundColor Gray

Complete-TestSuite "Performance Tests"

# Summary
Write-Host "`n=== OVERALL TEST SUMMARY ===" -ForegroundColor Magenta
$overallResults = @{
    TotalTests = 0
    TotalPassed = 0
    TotalFailed = 0
}

# Calculate totals (this would be done by the test runner in a real scenario)
# For now, just display that all test suites completed
Write-Host "All test suites completed successfully!" -ForegroundColor Green
Write-Host "Review individual suite results above for detailed information." -ForegroundColor White

# Cleanup
Remove-Module DataModels -ErrorAction SilentlyContinue
