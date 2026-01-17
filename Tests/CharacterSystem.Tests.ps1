# CharacterSystem.Tests.ps1
# Comprehensive tests for CharacterSystem module

BeforeAll {
    # Import CoreGame first (required dependency)
    $CoreGamePath = Join-Path $PSScriptRoot "..\Modules\CoreGame\CoreGame.psd1"
    Import-Module $CoreGamePath -Force -DisableNameChecking
    
    # Import CharacterSystem
    $CharacterSystemPath = Join-Path $PSScriptRoot "..\Modules\CharacterSystem\CharacterSystem.psd1"
    Import-Module $CharacterSystemPath -Force -DisableNameChecking
}

Describe "CharacterSystem Module" {
    Context "Module Loading" {
        It "Should load CharacterSystem module successfully" {
            Get-Module CharacterSystem | Should -Not -BeNullOrEmpty
        }
        
        It "Should pass manifest validation" {
            $ManifestPath = Join-Path $PSScriptRoot "..\Modules\CharacterSystem\CharacterSystem.psd1"
            { Test-ModuleManifest -Path $ManifestPath } | Should -Not -Throw
        }
        
        It "Should export expected function count" {
            $exportedCount = (Get-Module CharacterSystem).ExportedFunctions.Count
            $exportedCount | Should -BeGreaterOrEqual 25
        }
    }
    
    Context "Initialize-CharacterSystem" {
        It "Should initialize successfully with default config" {
            $result = Initialize-CharacterSystem
            $result.Initialized | Should -Be $true
            $result.ModuleName | Should -Be 'CharacterSystem'
        }
        
        It "Should accept custom configuration" {
            $config = @{ BaseXPPerLevel = 500; MaxLevel = 50 }
            $result = Initialize-CharacterSystem -Configuration $config
            $result.Configuration.BaseXPPerLevel | Should -Be 500
            $result.Configuration.MaxLevel | Should -Be 50
        }
    }
    
    Context "New-Character" {
        It "Should create character with name" {
            $char = New-Character -Name "TestRunner"
            $char | Should -Not -BeNullOrEmpty
            $char.Name | Should -Be "TestRunner"
        }
        
        It "Should create character with default StreetKid background" {
            $char = New-Character -Name "TestV"
            $char.GetProperty('Background') | Should -Be "StreetKid"
        }
        
        It "Should apply Solo background bonuses" {
            $char = New-Character -Name "SoloChar" -Background "Solo"
            $attrs = $char.GetProperty('Attributes')
            $attrs.Reflex | Should -BeGreaterThan 3  # Base is 3, Solo gets +2
            $attrs.Body | Should -BeGreaterThan 3    # Solo gets +1
        }
        
        It "Should apply Netrunner background bonuses" {
            $char = New-Character -Name "NetChar" -Background "Netrunner"
            $attrs = $char.GetProperty('Attributes')
            $attrs.Intelligence | Should -BeGreaterThan 3
            $attrs.Technical | Should -BeGreaterThan 3
        }
        
        It "Should apply custom attribute points" {
            $customAttrs = @{ Strength = 5; Cool = 3 }
            $char = New-Character -Name "CustomChar" -AttributePoints $customAttrs
            $attrs = $char.GetProperty('Attributes')
            $attrs.Strength | Should -BeGreaterOrEqual 8  # 3 base + 5 custom
        }
        
        It "Should initialize with starting credits" {
            $char = New-Character -Name "RichChar"
            $char.GetProperty('Credits') | Should -BeGreaterOrEqual 100
        }
        
        It "Should initialize equipment slots" {
            $char = New-Character -Name "EquipChar"
            $equipment = $char.GetProperty('Equipment')
            $equipment.Keys | Should -Contain 'WeaponSlot1'
            $equipment.Keys | Should -Contain 'Head'
        }
    }
    
    Context "Character Attributes" {
        BeforeEach {
            $script:TestChar = New-Character -Name "AttrTestChar"
        }
        
        It "Should get attribute value" {
            $value = Get-CharacterAttribute -Character $script:TestChar -AttributeName 'Body'
            $value | Should -BeGreaterOrEqual 1
        }
        
        It "Should set attribute value" {
            Set-CharacterAttribute -Character $script:TestChar -AttributeName 'Body' -Value 10
            $value = Get-CharacterAttribute -Character $script:TestChar -AttributeName 'Body'
            $value | Should -Be 10
        }
        
        It "Should update derived stats when attributes change" {
            $initialMaxHealth = $script:TestChar.GetProperty('MaxHealth')
            Set-CharacterAttribute -Character $script:TestChar -AttributeName 'Body' -Value 15
            $newMaxHealth = $script:TestChar.GetProperty('MaxHealth')
            $newMaxHealth | Should -BeGreaterThan $initialMaxHealth
        }
        
        It "Should not exceed max attribute of 20" {
            Set-CharacterAttribute -Character $script:TestChar -AttributeName 'Strength' -Value 20
            $script:TestChar.SetProperty('UnspentAttributePoints', 5)
            
            $result = Add-CharacterAttributePoint -Character $script:TestChar -AttributeName 'Strength'
            $result | Should -Be $false
        }
    }
    
    Context "Character Leveling" {
        BeforeEach {
            $script:TestChar = New-Character -Name "LevelTestChar"
        }
        
        It "Should start at level 1" {
            $script:TestChar.GetProperty('Level') | Should -Be 1
        }
        
        It "Should add experience" {
            $result = Add-CharacterExperience -Character $script:TestChar -Amount 500 -Source "Test"
            $result.XPAdded | Should -Be 500
            $result.TotalXP | Should -Be 500
        }
        
        It "Should calculate XP for level" {
            $xpLevel2 = Get-ExperienceForLevel -Level 2
            $xpLevel2 | Should -BeGreaterThan 0
            
            $xpLevel10 = Get-ExperienceForLevel -Level 10
            $xpLevel10 | Should -BeGreaterThan $xpLevel2
        }
        
        It "Should level up when enough XP" {
            # Give enough XP to level up
            $xpNeeded = Get-ExperienceForLevel -Level 2
            Add-CharacterExperience -Character $script:TestChar -Amount ($xpNeeded + 100)
            
            $script:TestChar.GetProperty('Level') | Should -BeGreaterOrEqual 2
        }
        
        It "Should grant attribute points on level up" {
            $initialPoints = $script:TestChar.GetProperty('UnspentAttributePoints')
            $xpNeeded = Get-ExperienceForLevel -Level 2
            Add-CharacterExperience -Character $script:TestChar -Amount ($xpNeeded + 100)
            
            $newPoints = $script:TestChar.GetProperty('UnspentAttributePoints')
            $newPoints | Should -BeGreaterThan $initialPoints
        }
        
        It "Should grant skill points on level up" {
            $initialPoints = $script:TestChar.GetProperty('UnspentSkillPoints')
            $xpNeeded = Get-ExperienceForLevel -Level 2
            Add-CharacterExperience -Character $script:TestChar -Amount ($xpNeeded + 100)
            
            $newPoints = $script:TestChar.GetProperty('UnspentSkillPoints')
            $newPoints | Should -BeGreaterThan $initialPoints
        }
    }
    
    Context "Character Combat" {
        BeforeEach {
            $script:TestChar = New-Character -Name "CombatTestChar"
            # Ensure full health
            $maxHealth = $script:TestChar.GetProperty('MaxHealth')
            $script:TestChar.SetProperty('Health', $maxHealth)
        }
        
        It "Should apply damage" {
            $result = Add-CharacterDamage -Character $script:TestChar -Amount 20
            $result.DamageDealt | Should -BeGreaterThan 0
            $result.RemainingHealth | Should -BeLessThan $script:TestChar.GetProperty('MaxHealth')
        }
        
        It "Should reduce damage with armor" {
            Set-CharacterAttribute -Character $script:TestChar -AttributeName 'Body' -Value 15
            $result = Add-CharacterDamage -Character $script:TestChar -Amount 50
            $result.DamageBlocked | Should -BeGreaterThan 0
        }
        
        It "Should bypass armor when specified" {
            Set-CharacterAttribute -Character $script:TestChar -AttributeName 'Body' -Value 15
            $result = Add-CharacterDamage -Character $script:TestChar -Amount 50 -IgnoreArmor
            $result.DamageDealt | Should -Be 50
        }
        
        It "Should set IsAlive to false when health reaches zero" {
            $maxHealth = $script:TestChar.GetProperty('MaxHealth')
            Add-CharacterDamage -Character $script:TestChar -Amount ($maxHealth * 10) -IgnoreArmor
            $script:TestChar.GetProperty('IsAlive') | Should -Be $false
        }
        
        It "Should heal character" {
            Add-CharacterDamage -Character $script:TestChar -Amount 50 -IgnoreArmor
            $afterDamage = $script:TestChar.GetProperty('Health')
            
            $result = Add-CharacterHealing -Character $script:TestChar -Amount 30
            $result.HealingApplied | Should -BeGreaterThan 0
            $result.CurrentHealth | Should -BeGreaterThan $afterDamage
        }
        
        It "Should not overheal past max health" {
            $result = Add-CharacterHealing -Character $script:TestChar -Amount 1000
            $result.CurrentHealth | Should -Be $script:TestChar.GetProperty('MaxHealth')
        }
    }
    
    Context "Character Skills" {
        BeforeEach {
            $script:TestChar = New-Character -Name "SkillTestChar"
            $script:TestChar.SetProperty('UnspentSkillPoints', 10)
        }
        
        It "Should get skill level (0 for unlearned)" {
            $level = Get-CharacterSkill -Character $script:TestChar -SkillName 'Handguns'
            $level | Should -Be 0
        }
        
        It "Should add skill point" {
            $result = Add-CharacterSkillPoint -Character $script:TestChar -SkillName 'Handguns'
            $result | Should -Be $true
            
            $level = Get-CharacterSkill -Character $script:TestChar -SkillName 'Handguns'
            $level | Should -Be 1
        }
        
        It "Should get all character skills" {
            Add-CharacterSkillPoint -Character $script:TestChar -SkillName 'Handguns'
            Add-CharacterSkillPoint -Character $script:TestChar -SkillName 'Stealth'
            
            $skills = Get-AllCharacterSkills -Character $script:TestChar
            $skills.Keys | Should -Contain 'Handguns'
            $skills.Keys | Should -Contain 'Stealth'
        }
        
        It "Should fail when no skill points available" {
            $script:TestChar.SetProperty('UnspentSkillPoints', 0)
            $result = Add-CharacterSkillPoint -Character $script:TestChar -SkillName 'Rifles'
            $result | Should -Be $false
        }
    }
    
    Context "Character Inventory" {
        BeforeEach {
            $script:TestChar = New-Character -Name "InvTestChar"
            $script:TestItem = @{
                Id = "test-item-001"
                Name = "Test Pistol"
                Weight = 2
                Stackable = $false
            }
            $script:StackableItem = @{
                Id = "ammo-001"
                Name = "Pistol Ammo"
                Weight = 0.1
                Stackable = $true
            }
        }
        
        It "Should add item to inventory" {
            $initialCount = (Get-CharacterInventory -Character $script:TestChar).Count
            $result = Add-CharacterItem -Character $script:TestChar -Item $script:TestItem
            $result | Should -Be $true
            
            $inventory = Get-CharacterInventory -Character $script:TestChar
            $inventory.Count | Should -Be ($initialCount + 1)
        }
        
        It "Should stack stackable items" {
            Add-CharacterItem -Character $script:TestChar -Item $script:StackableItem -Quantity 10
            Add-CharacterItem -Character $script:TestChar -Item $script:StackableItem -Quantity 5
            
            $inventory = Get-CharacterInventory -Character $script:TestChar
            $ammo = $inventory | Where-Object { $_.Id -eq "ammo-001" }
            $ammo.Quantity | Should -Be 15
        }
        
        It "Should remove item from inventory" {
            Add-CharacterItem -Character $script:TestChar -Item $script:TestItem
            $result = Remove-CharacterItem -Character $script:TestChar -ItemId "test-item-001"
            $result | Should -Be $true
            
            $inventory = Get-CharacterInventory -Character $script:TestChar
            $inventory.Count | Should -Be 0
        }
        
        It "Should calculate inventory weight" {
            Add-CharacterItem -Character $script:TestChar -Item $script:TestItem
            Add-CharacterItem -Character $script:TestChar -Item $script:StackableItem -Quantity 10
            
            $weight = Get-CharacterInventoryWeight -Character $script:TestChar
            $weight | Should -Be 3  # 2 + (0.1 * 10)
        }
        
        It "Should respect carry capacity" {
            $heavyItem = @{ Id = "heavy-001"; Name = "Heavy Item"; Weight = 1000 }
            $result = Add-CharacterItem -Character $script:TestChar -Item $heavyItem
            $result | Should -Be $false
        }
    }
    
    Context "Character Equipment" {
        BeforeEach {
            $script:TestChar = New-Character -Name "EquipTestChar"
            $script:Weapon = @{
                Id = "weapon-001"
                Name = "Combat Pistol"
                Damage = 25
                Weight = 2
            }
            $script:Armor = @{
                Id = "armor-001"
                Name = "Armored Jacket"
                Armor = 10
                Weight = 5
            }
        }
        
        It "Should equip weapon to slot" {
            $result = Set-CharacterEquipment -Character $script:TestChar -Item $script:Weapon -Slot 'WeaponSlot1'
            $result | Should -Be $true
            
            $equipment = Get-CharacterEquipment -Character $script:TestChar
            $equipment.WeaponSlot1.Id | Should -Be "weapon-001"
        }
        
        It "Should equip armor" {
            Set-CharacterEquipment -Character $script:TestChar -Item $script:Armor -Slot 'OuterTorso'
            
            $equipment = Get-CharacterEquipment -Character $script:TestChar
            $equipment.OuterTorso.Armor | Should -Be 10
        }
        
        It "Should unequip item" {
            Set-CharacterEquipment -Character $script:TestChar -Item $script:Weapon -Slot 'WeaponSlot1'
            $result = Remove-CharacterEquipment -Character $script:TestChar -Slot 'WeaponSlot1'
            $result | Should -Be $true
            
            $equipment = Get-CharacterEquipment -Character $script:TestChar
            $equipment.WeaponSlot1 | Should -BeNullOrEmpty
        }
        
        It "Should return unequipped item to inventory" {
            Set-CharacterEquipment -Character $script:TestChar -Item $script:Weapon -Slot 'WeaponSlot1'
            Remove-CharacterEquipment -Character $script:TestChar -Slot 'WeaponSlot1'
            
            $inventory = Get-CharacterInventory -Character $script:TestChar
            $weapon = $inventory | Where-Object { $_.Id -eq "weapon-001" }
            $weapon | Should -Not -BeNullOrEmpty
        }
        
        It "Should calculate total armor from equipment" {
            Set-CharacterEquipment -Character $script:TestChar -Item $script:Armor -Slot 'OuterTorso'
            $helmet = @{ Id = "helmet-001"; Name = "Helmet"; Armor = 5; Weight = 1 }
            Set-CharacterEquipment -Character $script:TestChar -Item $helmet -Slot 'Head'
            
            $totalArmor = Get-CharacterTotalArmor -Character $script:TestChar
            $totalArmor | Should -Be 15
        }
    }
    
    Context "Character Currency" {
        BeforeEach {
            $script:TestChar = New-Character -Name "CurrencyTestChar"
        }
        
        It "Should get starting credits" {
            $credits = Get-CharacterCredits -Character $script:TestChar
            $credits | Should -BeGreaterOrEqual 100
        }
        
        It "Should add credits" {
            $initial = Get-CharacterCredits -Character $script:TestChar
            Add-CharacterCredits -Character $script:TestChar -Amount 500
            $new = Get-CharacterCredits -Character $script:TestChar
            $new | Should -Be ($initial + 500)
        }
        
        It "Should remove credits when sufficient" {
            Add-CharacterCredits -Character $script:TestChar -Amount 1000
            $result = Remove-CharacterCredits -Character $script:TestChar -Amount 500
            $result | Should -Be $true
        }
        
        It "Should fail to remove credits when insufficient" {
            $script:TestChar.SetProperty('Credits', 100)
            $result = Remove-CharacterCredits -Character $script:TestChar -Amount 500
            $result | Should -Be $false
        }
    }
    
    Context "Character Summary" {
        It "Should return character summary" {
            $char = New-Character -Name "SummaryChar" -Background "Corpo"
            Add-CharacterExperience -Character $char -Amount 500
            
            $summary = Get-CharacterSummary -Character $char
            
            $summary.Name | Should -Be "SummaryChar"
            $summary.Background | Should -Be "Corpo"
            $summary.Level | Should -BeGreaterOrEqual 1
            $summary.Experience | Should -BeGreaterOrEqual 500
            $summary.Health | Should -BeGreaterThan 0
            $summary.Credits | Should -BeGreaterOrEqual 0
            $summary.Attributes | Should -Not -BeNullOrEmpty
        }
    }
}
