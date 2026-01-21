# Full-System-Integration.Tests.ps1
# Phase 9: Comprehensive integration tests for all game modules
# Tests cross-module interactions, event propagation, and system-wide functionality

BeforeAll {
    # Get project root - Tests/Integration -> Tests -> ProjectRoot
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    
    # Import all modules in dependency order
    # GameLogging must be first as EventSystem depends on it
    $modules = @(
        'CoreGame\GameLogging.psm1',
        'CoreGame\EventSystem.psm1',
        'CoreGame\StateManager.psm1',
        'CharacterSystem\CharacterSystem.psm1',
        'WorldSystem\WorldSystem.psm1',
        'QuestSystem\QuestSystem.psm1',
        'FactionSystem\FactionSystem.psm1',
        'ShopSystem\ShopSystem.psm1',
        'TerminalSystem\TerminalSystem.psm1',
        'DroneSystem\DroneSystem.psm1'
    )
    
    foreach ($module in $modules) {
        $modulePath = Join-Path $projectRoot "Modules\$module"
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force -ErrorAction SilentlyContinue -DisableNameChecking -WarningAction SilentlyContinue
        }
    }
    
    # Initialize GameLogging first
    if (Get-Command Initialize-GameLogging -ErrorAction SilentlyContinue) {
        Initialize-GameLogging | Out-Null
    }
}

AfterAll {
    # Cleanup modules
    $moduleNames = @('EventSystem', 'StateManager', 'CharacterSystem', 'WorldSystem', 
                     'QuestSystem', 'FactionSystem', 'ShopSystem', 'TerminalSystem', 'DroneSystem', 'GameLogging')
    foreach ($name in $moduleNames) {
        Remove-Module $name -Force -ErrorAction SilentlyContinue
    }
}

Describe "Phase 9: Full System Integration Tests" {
    
    Describe "Module Initialization" {
        
        It "Should initialize all modules without errors" {
            # Initialize all modules
            $results = @{}
            
            if (Get-Command Initialize-CharacterSystem -ErrorAction SilentlyContinue) {
                $results.CharacterSystem = Initialize-CharacterSystem
                $results.CharacterSystem | Should -Not -BeNullOrEmpty
            }
            
            if (Get-Command Initialize-WorldSystem -ErrorAction SilentlyContinue) {
                $results.WorldSystem = Initialize-WorldSystem
                $results.WorldSystem.Initialized | Should -Be $true
            }
            
            if (Get-Command Initialize-QuestSystem -ErrorAction SilentlyContinue) {
                $results.QuestSystem = Initialize-QuestSystem
                $results.QuestSystem.Initialized | Should -Be $true
            }
            
            if (Get-Command Initialize-FactionSystem -ErrorAction SilentlyContinue) {
                $results.FactionSystem = Initialize-FactionSystem
                $results.FactionSystem.Initialized | Should -Be $true
            }
            
            if (Get-Command Initialize-ShopSystem -ErrorAction SilentlyContinue) {
                $results.ShopSystem = Initialize-ShopSystem
                $results.ShopSystem.Initialized | Should -Be $true
            }
            
            if (Get-Command Initialize-TerminalSystem -ErrorAction SilentlyContinue) {
                $results.TerminalSystem = Initialize-TerminalSystem
                $results.TerminalSystem.Initialized | Should -Be $true
            }
            
            if (Get-Command Initialize-DroneSystem -ErrorAction SilentlyContinue) {
                $results.DroneSystem = Initialize-DroneSystem
                $results.DroneSystem.Initialized | Should -Be $true
            }
            
            $results.Keys.Count | Should -BeGreaterOrEqual 7
        }
        
        It "Should have all expected export functions available" {
            # CharacterSystem
            Get-Command New-Character -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-CharacterSummary -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # WorldSystem
            Get-Command New-Location -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-Location -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # QuestSystem
            Get-Command New-QuestTemplate -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-Quest -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # FactionSystem
            Get-Command New-Faction -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-Faction -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # ShopSystem
            Get-Command New-Shop -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-Shop -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # TerminalSystem
            Get-Command New-Terminal -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-Terminal -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            
            # DroneSystem
            Get-Command New-Drone -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-Drone -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Describe "Character-Faction Integration" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
        }
        
        It "Should create faction and set reputation" {
            # Create a faction (Type must be: Corporation, Crew, Syndicate, YoungTeam, Underground, Independent, Player)
            $faction = New-Faction -FactionId 'netrunners' -Name 'Netrunners' -Type 'Crew'
            $faction | Should -Not -BeNullOrEmpty
            
            # Set faction reputation (uses Reputation not EntityId/Standing)
            $result = Set-Reputation -FactionId 'netrunners' -Reputation 50
            $result.Success | Should -Be $true
            
            # Verify reputation
            $repInfo = Get-Reputation -FactionId 'netrunners'
            $repInfo.Reputation | Should -Be 50
        }
        
        It "Should calculate reputation tier correctly" {
            New-Faction -FactionId 'corpo' -Name 'Arasaka' -Type 'Corporation' | Out-Null
            
            # Test hostile standing (negative reputation)
            Set-Reputation -FactionId 'corpo' -Reputation -60 | Out-Null
            $repInfo = Get-Reputation -FactionId 'corpo'
            $repInfo.Reputation | Should -BeLessThan 0
            
            # Standing should be Hostile for very negative reputation
            $repInfo.Standing | Should -Be 'Hostile'
        }
    }
    
    Describe "Quest System Operations" {
        BeforeEach {
            Initialize-QuestSystem | Out-Null
        }
        
        It "Should create and start quest" {
            # Create quest template (uses Name, Description, QuestType)
            $quest = New-QuestTemplate -TemplateId 'main_001' -Name 'The Heist' -QuestType 'MainStory' `
                -Description 'Pull off the big job'
            $quest | Should -Not -BeNullOrEmpty
            
            $result = Start-Quest -TemplateId 'main_001'
            $result.Success | Should -Be $true
        }
        
        It "Should complete quest successfully" {
            New-QuestTemplate -TemplateId 'side_001' -Name 'Side Job' -QuestType 'Side' `
                -Description 'A quick side job' -Rewards @{ XP = 100 } | Out-Null
            
            $startResult = Start-Quest -TemplateId 'side_001'
            $startResult.Success | Should -Be $true
            
            # Complete the quest using Quest.QuestId from start result
            $result = Complete-Quest -QuestId $startResult.Quest.QuestId
            $result.Success | Should -Be $true
        }
    }
    
    Describe "Shop System Operations" {
        BeforeEach {
            Initialize-ShopSystem | Out-Null
        }
        
        It "Should create shop and add items" {
            # Create shop (VendorType must be: BlackMarket, CorporateStore, StreetVendor, Fixer, ChopShop, MedClinic, TechShop)
            New-Shop -ShopId 'weapons_dealer' -Name 'Weapons R Us' -VendorType 'BlackMarket' | Out-Null
            
            # Create item first, then add to shop inventory
            New-Item -ItemId 'pistol_01' -Name 'Basic Pistol' -Category 'Weapons' `
                -BasePrice 500 -Rarity 'Common' | Out-Null
            Add-ShopInventory -ShopId 'weapons_dealer' -ItemId 'pistol_01' -Quantity 10 | Out-Null
            
            $shop = Get-Shop -ShopId 'weapons_dealer'
            $shop | Should -Not -BeNullOrEmpty
            $shop.ShopId | Should -Be 'weapons_dealer'
        }
        
        It "Should process purchase transaction" {
            New-Shop -ShopId 'test_shop' -Name 'Test Shop' -VendorType 'StreetVendor' | Out-Null
            
            # Create item and add to inventory (Category must be valid: Weapons, Armor, Cyberware, Consumables, Medical, Electronics, Tools, Intel, Contraband, Drugs, Junk, etc.)
            New-Item -ItemId 'item_01' -Name 'Test Item' -Category 'Junk' `
                -BasePrice 100 -Rarity 'Common' | Out-Null
            Add-ShopInventory -ShopId 'test_shop' -ItemId 'item_01' -Quantity 5 | Out-Null
            
            # Give player currency first
            Add-PlayerCurrency -Amount 500 | Out-Null
            
            $result = Invoke-Purchase -ShopId 'test_shop' -ItemId 'item_01' -Quantity 1
            
            $result.Success | Should -Be $true
        }
    }
    
    Describe "Drone System Operations" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
        }
        
        It "Should deploy drone from inventory" {
            Add-DroneToInventory -Type 'Scout' | Out-Null
            
            $result = Deploy-Drone -Type 'Scout' -Position @{ X = 100; Y = 100; Z = 50 }
            $result.Success | Should -Be $true
            $result.Drone.Type | Should -Be 'Scout'
        }
        
        It "Should execute drone actions" {
            Add-DroneToInventory -Type 'Scout' | Out-Null
            $deployed = Deploy-Drone -Type 'Scout'
            
            $scanResult = Invoke-DroneAction -DroneId $deployed.DroneId -Action 'Scan'
            $scanResult.Success | Should -Be $true
        }
        
        It "Should handle enemy drone override" {
            # Create enemy drone
            New-Drone -DroneId 'enemy_01' -Type 'Combat' -IsEnemy $true | Out-Null
            
            # Attempt override (may fail due to RNG, but should not error)
            $result = Invoke-DroneOverride -DroneId 'enemy_01' -HackerId 'player' `
                -Intelligence 15 -HackingSkill 5
            
            $result.Roll | Should -BeGreaterThan 0
            $result.RequiredRoll | Should -BeGreaterThan 0
        }
    }
    
    Describe "World-Location Integration" {
        BeforeEach {
            Initialize-WorldSystem | Out-Null
            Initialize-ShopSystem | Out-Null
            Initialize-TerminalSystem | Out-Null
        }
        
        It "Should create location with shop" {
            # Location Type must be: SafeHouse, Shop, Bar, Clinic, Workshop, MissionSite, Street, Hideout
            # Uses -Id not -LocationId
            $location = New-Location -Id 'market_district' -Name 'Market District' -Type 'Shop'
            $location | Should -Not -BeNullOrEmpty
            
            New-Shop -ShopId 'market_shop' -Name 'Market Vendor' -VendorType 'StreetVendor' `
                -LocationId 'market_district' | Out-Null
            
            $shop = Get-Shop -ShopId 'market_shop'
            $shop.LocationId | Should -Be 'market_district'
        }
        
        It "Should create location with terminal" {
            New-Location -Id 'tech_hub' -Name 'Tech Hub' -Type 'Workshop' | Out-Null
            
            New-Terminal -TerminalId 'hub_terminal' -Name 'Hub Access Point' `
                -Type 'PublicTerminal' -LocationId 'tech_hub' | Out-Null
            
            $terminal = Get-Terminal -TerminalId 'hub_terminal'
            $terminal.LocationId | Should -Be 'tech_hub'
        }
    }
    
    Describe "Terminal-Hacking Integration" {
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
        }
        
        It "Should allow terminal hack attempts" {
            New-Terminal -TerminalId 'secure_01' -Name 'Secure Terminal' -Type 'CorporateTerminal' `
                -SecurityLevel 3 | Out-Null
            
            # Use Start-Hack instead of Invoke-TerminalHack
            $result = Start-Hack -TerminalId 'secure_01' -HackerId 'netrunner1' `
                -Intelligence 15 -HackingSkill 5
            
            $result | Should -Not -BeNullOrEmpty
            $result.TerminalId | Should -Be 'secure_01'
        }
        
        It "Should support terminal programs via Add-HackingProgram" {
            New-Terminal -TerminalId 'prog_term' -Name 'Program Terminal' -Type 'PublicTerminal' | Out-Null
            
            # Add a predefined hacking program (must be: BasicDecrypt, Probe, Mask, Sledgehammer, Ghost, ICEBreaker, DataVault, Worm)
            $result = Add-HackingProgram -ProgramName 'Probe'
            $result.Success | Should -Be $true
            
            # Programs are used during Start-Hack
            $hackResult = Start-Hack -TerminalId 'prog_term' -Programs @('Probe')
            $hackResult | Should -Not -BeNullOrEmpty
        }
    }
    
    Describe "Quest-Faction Integration" {
        BeforeEach {
            Initialize-QuestSystem | Out-Null
            Initialize-FactionSystem | Out-Null
        }
        
        It "Should create faction-related quest" {
            # Type must be: Corporation, Crew, Syndicate, YoungTeam, Underground, Independent, Player
            New-Faction -FactionId 'fixers' -Name 'Fixers Network' -Type 'Independent' | Out-Null
            
            New-QuestTemplate -TemplateId 'fixer_job' -Name 'Fixer Job' -QuestType 'Faction' `
                -Description 'A job for the fixers' -FactionId 'fixers' | Out-Null
            
            $startResult = Start-Quest -TemplateId 'fixer_job'
            $startResult.Success | Should -Be $true
            
            $result = Complete-Quest -QuestId $startResult.Quest.QuestId
            $result.Success | Should -Be $true
        }
    }
    
    Describe "Drone-Combat Integration" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
        }
        
        It "Should handle drone vs drone combat" {
            # Player drone
            New-Drone -DroneId 'player_combat' -Type 'Combat' | Out-Null
            
            # Enemy drone
            New-Drone -DroneId 'enemy_combat' -Type 'Combat' -IsEnemy $true | Out-Null
            
            # Player drone attacks
            $attackResult = Invoke-DroneAction -DroneId 'player_combat' -Action 'Attack' `
                -TargetId 'enemy_combat'
            
            $attackResult.Success | Should -Be $true
            $attackResult.Damage | Should -BeGreaterThan 0
            
            # Apply damage to enemy
            $damageResult = Invoke-DroneDamage -DroneId 'enemy_combat' `
                -Damage $attackResult.Damage -SourceId 'player_combat'
            
            $damageResult.ActualDamage | Should -BeGreaterThan 0
        }
        
        It "Should process combat events across drones" {
            New-Drone -DroneId 'event_drone' -Type 'Scout' | Out-Null
            Set-DroneStatus -DroneId 'event_drone' -Status 'Deployed' | Out-Null
            
            $results = Process-DroneEvent -EventType 'CombatStarted'
            
            $drone = Get-Drone -DroneId 'event_drone'
            $drone.Status | Should -Be 'Combat'
        }
    }
    
    Describe "Full Game Flow Simulation" {
        BeforeEach {
            # Initialize all systems
            Initialize-WorldSystem | Out-Null
            Initialize-QuestSystem | Out-Null
            Initialize-FactionSystem | Out-Null
            Initialize-ShopSystem | Out-Null
            Initialize-TerminalSystem | Out-Null
            Initialize-DroneSystem | Out-Null
        }
        
        It "Should simulate complete gameplay session" {
            # 1. Create game world (Type: SafeHouse, Shop, Bar, Clinic, Workshop, MissionSite, Street, Hideout)
            $location = New-Location -Id 'watson' -Name 'Watson District' -Type 'Street'
            $location | Should -Not -BeNullOrEmpty
            
            # 2. Create faction (Type: Corporation, Crew, Syndicate, YoungTeam, Underground, Independent, Player)
            $faction = New-Faction -FactionId 'maelstrom' -Name 'Maelstrom' -Type 'Crew'
            $faction | Should -Not -BeNullOrEmpty
            
            # 3. Create shop in location (VendorType: BlackMarket, CorporateStore, StreetVendor, Fixer, ChopShop, MedClinic, TechShop)
            New-Shop -ShopId 'watson_arms' -Name 'Watson Arms Dealer' -VendorType 'BlackMarket' `
                -LocationId 'watson' | Out-Null
            
            # Create and add item to shop
            New-Item -ItemId 'smg_01' -Name 'Street SMG' -Category 'Weapons' `
                -BasePrice 750 -Rarity 'Common' | Out-Null
            Add-ShopInventory -ShopId 'watson_arms' -ItemId 'smg_01' -Quantity 5 | Out-Null
            
            # 4. Create terminal
            New-Terminal -TerminalId 'watson_access' -Name 'Access Point' -Type 'PublicTerminal' `
                -LocationId 'watson' | Out-Null
            
            # 5. Create quest (uses Name, Description, QuestType)
            New-QuestTemplate -TemplateId 'gang_war' -Name 'Gang War' -QuestType 'Faction' `
                -Description 'Help in the gang war' -FactionId 'maelstrom' -Rewards @{ XP = 150 } | Out-Null
            
            # 6. Start quest
            $questStart = Start-Quest -TemplateId 'gang_war'
            $questStart.Success | Should -Be $true
            
            # 7. Deploy drone for mission
            Add-DroneToInventory -Type 'Scout' | Out-Null
            $droneDeployed = Deploy-Drone -Type 'Scout' -Position @{ X = 50; Y = 50; Z = 100 }
            $droneDeployed.Success | Should -Be $true
            
            # 8. Use drone to scan
            $scanResult = Invoke-DroneAction -DroneId $droneDeployed.DroneId -Action 'Scan'
            $scanResult.Success | Should -Be $true
            
            # 9. Hack terminal (use Start-Hack)
            $hackResult = Start-Hack -TerminalId 'watson_access' `
                -HackerId 'player' -Intelligence 12 -HackingSkill 3
            $hackResult | Should -Not -BeNullOrEmpty
            
            # 10. Complete quest (use Quest.QuestId from start result)
            $questComplete = Complete-Quest -QuestId $questStart.Quest.QuestId
            $questComplete.Success | Should -Be $true
            
            # 11. Update faction reputation (use Set-Reputation)
            Set-Reputation -FactionId 'maelstrom' -Reputation 25 | Out-Null
            $repInfo = Get-Reputation -FactionId 'maelstrom'
            $repInfo.Reputation | Should -Be 25
            
            # 12. Give player currency and purchase from shop
            Add-PlayerCurrency -Amount 2000 | Out-Null
            $purchase = Invoke-Purchase -ShopId 'watson_arms' -ItemId 'smg_01' -Quantity 1
            $purchase.Success | Should -Be $true
            
            # 13. Recall drone
            $recall = Recall-Drone -DroneId $droneDeployed.DroneId
            $recall.Success | Should -Be $true
            
            Write-Host "Full gameplay simulation completed successfully!" -ForegroundColor Green
        }
    }
    
    Describe "State Persistence Integration" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            Initialize-DroneSystem | Out-Null
        }
        
        It "Should export and import drone state" {
            $tempDir = Join-Path $env:TEMP "pwsh_game_test_$(Get-Random)"
            [System.IO.Directory]::CreateDirectory($tempDir) | Out-Null
            
            try {
                # Create some data
                Add-DroneToInventory -Type 'Combat' | Out-Null
                
                # Export
                $droneExport = Export-DroneData -FilePath (Join-Path $tempDir "drones.json")
                $droneExport.Success | Should -Be $true
                
                # Reset and reimport
                Initialize-DroneSystem | Out-Null
                
                $droneImport = Import-DroneData -FilePath (Join-Path $tempDir "drones.json")
                $droneImport.Success | Should -Be $true
            }
            finally {
                # Cleanup temp directory
                if (Test-Path $tempDir) {
                    Get-ChildItem -Path $tempDir -File | ForEach-Object { Remove-Item $_.FullName }
                    Remove-Item $tempDir
                }
            }
        }
    }
    
    Describe "Error Handling Integration" {
        BeforeEach {
            Initialize-QuestSystem | Out-Null
            Initialize-ShopSystem | Out-Null
            Initialize-DroneSystem | Out-Null
        }
        
        It "Should handle missing entity references gracefully" {
            # Quest for non-existent character - should handle gracefully
            New-QuestTemplate -TemplateId 'orphan_quest' -Name 'Orphan Quest' -QuestType 'Side' `
                -Description 'An orphaned quest' | Out-Null
            # Start quest should work (quest system is player-agnostic)
            $result = Start-Quest -TemplateId 'orphan_quest'
            # Either succeeds or fails gracefully
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle invalid operations gracefully" {
            # Deploy without inventory
            Initialize-DroneSystem | Out-Null
            $result = Deploy-Drone -Type 'Heavy'
            $result.Success | Should -Be $false
            
            # Recall non-existent drone
            $recall = Recall-Drone -DroneId 'phantom_drone'
            $recall.Success | Should -Be $false
        }
    }
}
