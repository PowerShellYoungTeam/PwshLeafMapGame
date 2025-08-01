# PowerShell Data Models Demonstration
# Shows the core game entities in action

# Import the data models module
Import-Module .\Modules\CoreGame\DataModels.psm1 -Force

Write-Host "`n=== PowerShell Leafmap Game - Data Models Demo ===" -ForegroundColor Green

# Create a player
Write-Host "`n1. Creating a new player..." -ForegroundColor Cyan
$player = New-PlayerEntity -Username 'DemoPlayer' -Email 'demo@example.com' -DisplayName 'Demo Player'
Write-Host "   Player created: $($player.DisplayName) (Level $($player.Level))" -ForegroundColor Green

# Add some experience
Write-Host "`n2. Adding experience..." -ForegroundColor Cyan
$player.AddExperience(1500)
Write-Host "   Player is now level $($player.Level) with $($player.Experience) experience" -ForegroundColor Green

# Visit some locations
Write-Host "`n3. Exploring locations..." -ForegroundColor Cyan
$player.VisitLocation('TownSquare')
$player.VisitLocation('Forest')
$player.VisitLocation('Cave')
Write-Host "   Visited $($player.VisitedLocations.Count) locations: $($player.VisitedLocations -join ', ')" -ForegroundColor Green

# Create an NPC
Write-Host "`n4. Creating an NPC..." -ForegroundColor Cyan
$npc = New-NPCEntity -Name 'Village Elder' -NPCType 'Wise' -Description 'A knowledgeable elder who offers guidance'
$npc.PersonalityType = 'Helpful'
$npc.AvailableServices = @('Information', 'Quests')
Write-Host "   NPC created: $($npc.Name) ($($npc.NPCType)) - Services: $($npc.AvailableServices -join ', ')" -ForegroundColor Green

# Create some items
Write-Host "`n5. Creating items..." -ForegroundColor Cyan
$sword = New-ItemEntity -Name 'Iron Sword' -ItemType 'Weapon' -Description 'A sturdy iron sword'
$sword.Value = 150
$sword.IsEquippable = $true
$sword.Rarity = 'Common'

$potion = New-ItemEntity -Name 'Health Potion' -ItemType 'Consumable' -Description 'Restores health when consumed'
$potion.Value = 50
$potion.IsConsumable = $true
$potion.StackSize = 5

Write-Host "   Created items:" -ForegroundColor Green
Write-Host "   - $($sword.Name): $($sword.Value) gold, $($sword.Rarity) $($sword.ItemType)" -ForegroundColor White
Write-Host "   - $($potion.Name): $($potion.Value) gold, Stack Size: $($potion.StackSize)" -ForegroundColor White

# Add items to player inventory
Write-Host "`n6. Adding items to inventory..." -ForegroundColor Cyan
$player.Inventory = @($player.Inventory) + $sword.ToHashtable()
$player.Inventory = @($player.Inventory) + $potion.ToHashtable()
Write-Host "   Player now has $($player.Inventory.Count) items in inventory" -ForegroundColor Green

# Test serialization
Write-Host "`n7. Testing serialization..." -ForegroundColor Cyan
$playerJson = ConvertTo-JsonSafe -InputObject $player
$deserializedPlayer = ConvertFrom-JsonSafe -JsonString $playerJson -EntityType 'Player'
Write-Host "   Serialized player to JSON ($($playerJson.Length) characters)" -ForegroundColor Green
Write-Host "   Deserialized player: $($deserializedPlayer.DisplayName) (Level $($deserializedPlayer.Level))" -ForegroundColor Green

# Test validation
Write-Host "`n8. Testing validation..." -ForegroundColor Cyan
$validation = Test-EntityValidity -Entity $player -EntityType 'Player'
if ($validation.IsValid) {
    Write-Host "   ✓ Player data is valid" -ForegroundColor Green
} else {
    Write-Host "   ✗ Player data has errors: $($validation.Errors -join ', ')" -ForegroundColor Red
}

$npcValidation = Test-EntityValidity -Entity $npc -EntityType 'NPC'
if ($npcValidation.IsValid) {
    Write-Host "   ✓ NPC data is valid" -ForegroundColor Green
} else {
    Write-Host "   ✗ NPC data has errors: $($npcValidation.Errors -join ', ')" -ForegroundColor Red
}

# Test item durability
Write-Host "`n9. Testing item durability..." -ForegroundColor Cyan
Write-Host "   Sword durability: $($sword.Durability)/$($sword.MaxDurability)" -ForegroundColor White
$sword.DamageItem(25)
Write-Host "   After damage: $($sword.Durability)/$($sword.MaxDurability)" -ForegroundColor White
$sword.RepairItem(10)
Write-Host "   After repair: $($sword.Durability)/$($sword.MaxDurability)" -ForegroundColor White

# Show player achievements
Write-Host "`n10. Adding achievements..." -ForegroundColor Cyan
$achievement = @{
    Id = 'FirstExplorer'
    Name = 'First Steps'
    Description = 'Visited your first location'
    DateEarned = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
}
$player.AddAchievement($achievement)
Write-Host "    Achievement earned: $($achievement.Name)" -ForegroundColor Green
Write-Host "    Player has $($player.Achievements.Count) achievements" -ForegroundColor Green

# Display final stats
Write-Host "`n=== Final Player Stats ===" -ForegroundColor Yellow
Write-Host "Name: $($player.DisplayName)" -ForegroundColor White
Write-Host "Level: $($player.Level)" -ForegroundColor White
Write-Host "Experience: $($player.Experience)" -ForegroundColor White
Write-Host "Currency: $($player.Currency)" -ForegroundColor White
Write-Host "Locations Visited: $($player.VisitedLocations.Count)" -ForegroundColor White
Write-Host "Items: $($player.Inventory.Count)" -ForegroundColor White
Write-Host "Achievements: $($player.Achievements.Count)" -ForegroundColor White

Write-Host "`n=== Demo Complete! ===" -ForegroundColor Green
Write-Host "All data models are working correctly." -ForegroundColor White
