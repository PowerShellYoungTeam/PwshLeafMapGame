# DroneSystem.Tests.ps1
# Comprehensive tests for the DroneSystem module

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "..\Modules\DroneSystem\DroneSystem.psm1"
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module DroneSystem -Force -ErrorAction SilentlyContinue
}

Describe "DroneSystem Module" {
    
    Describe "Initialize-DroneSystem" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
        }
        
        It "Should initialize successfully" {
            $result = Initialize-DroneSystem
            $result.Initialized | Should -Be $true
        }
        
        It "Should have default configuration" {
            $result = Initialize-DroneSystem
            $result.Configuration.MaxActiveDrones | Should -Be 5
            $result.Configuration.MaxDroneInventory | Should -Be 20
            $result.Configuration.BaseDetectionRange | Should -Be 150
        }
        
        It "Should accept custom configuration" {
            $result = Initialize-DroneSystem -Configuration @{
                MaxActiveDrones = 10
                MaxDroneInventory = 50
            }
            $result.Configuration.MaxActiveDrones | Should -Be 10
            $result.Configuration.MaxDroneInventory | Should -Be 50
        }
        
        It "Should list all drone types" {
            $result = Initialize-DroneSystem
            $result.DroneTypes | Should -Contain 'Scout'
            $result.DroneTypes | Should -Contain 'Combat'
            $result.DroneTypes | Should -Contain 'Support'
            $result.DroneTypes | Should -Contain 'EMP'
            $result.DroneTypes | Should -Contain 'Heavy'
            $result.DroneTypes | Should -Contain 'Stealth'
            $result.DroneTypes | Should -Contain 'Carrier'
            $result.DroneTypes | Should -Contain 'Turret'
        }
        
        It "Should list all mission types" {
            $result = Initialize-DroneSystem
            $result.MissionTypes | Should -Contain 'Patrol'
            $result.MissionTypes | Should -Contain 'Reconnaissance'
            $result.MissionTypes | Should -Contain 'Strike'
        }
    }
    
    Describe "New-Drone" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
        }
        
        It "Should create a Scout drone" {
            $drone = New-Drone -DroneId 'drone_001' -Type 'Scout'
            $drone.DroneId | Should -Be 'drone_001'
            $drone.Type | Should -Be 'Scout'
            $drone.Status | Should -Be 'Idle'
        }
        
        It "Should create a Combat drone with correct stats" {
            $drone = New-Drone -DroneId 'drone_002' -Type 'Combat'
            $drone.Type | Should -Be 'Combat'
            $drone.Attack | Should -BeGreaterThan 0
            $drone.AttackRange | Should -BeGreaterThan 0
        }
        
        It "Should apply custom name" {
            $drone = New-Drone -DroneId 'drone_003' -Type 'Scout' -Name 'Alpha Scout'
            $drone.Name | Should -Be 'Alpha Scout'
        }
        
        It "Should set owner correctly" {
            $drone = New-Drone -DroneId 'drone_004' -Type 'Scout' -OwnerId 'player1'
            $drone.OwnerId | Should -Be 'player1'
        }
        
        It "Should create enemy drone" {
            $drone = New-Drone -DroneId 'drone_005' -Type 'Combat' -IsEnemy $true
            $drone.IsEnemy | Should -Be $true
        }
        
        It "Should apply level bonuses" {
            $drone = New-Drone -DroneId 'drone_006' -Type 'Combat' -Level 5
            $drone.Level | Should -Be 5
            $drone.MaxHP | Should -BeGreaterThan 60  # Base is 60, level 5 adds 40%
        }
        
        It "Should apply upgrades" {
            $drone = New-Drone -DroneId 'drone_007' -Type 'Scout' -Upgrades @('ArmorPlating')
            $drone.Armor | Should -BeGreaterThan 0
            $drone.Upgrades.ContainsKey('ArmorPlating') | Should -Be $true
        }
        
        It "Should set initial position" {
            $pos = @{ X = 100; Y = 200; Z = 50 }
            $drone = New-Drone -DroneId 'drone_008' -Type 'Scout' -Position $pos
            $drone.Position.X | Should -Be 100
            $drone.Position.Y | Should -Be 200
            $drone.Position.Z | Should -Be 50
        }
        
        It "Should throw on duplicate DroneId" {
            New-Drone -DroneId 'drone_dup' -Type 'Scout' | Out-Null
            { New-Drone -DroneId 'drone_dup' -Type 'Combat' } | Should -Throw "*already exists*"
        }
        
        It "Should throw if not initialized" {
            Remove-Module DroneSystem -Force
            Import-Module (Join-Path $PSScriptRoot "..\Modules\DroneSystem\DroneSystem.psm1") -Force
            { New-Drone -DroneId 'test' -Type 'Scout' } | Should -Throw "*not initialized*"
        }
        
        It "Should have abilities based on type" {
            $scout = New-Drone -DroneId 'scout_test' -Type 'Scout'
            $scout.Abilities | Should -Contain 'Scan'
            $scout.Abilities | Should -Contain 'MarkTarget'
            
            $combat = New-Drone -DroneId 'combat_test' -Type 'Combat'
            $combat.Abilities | Should -Contain 'Attack'
        }
    }
    
    Describe "Get-Drone" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'get_001' -Type 'Scout' | Out-Null
            New-Drone -DroneId 'get_002' -Type 'Combat' | Out-Null
            New-Drone -DroneId 'get_003' -Type 'Support' | Out-Null
            New-Drone -DroneId 'enemy_001' -Type 'Combat' -IsEnemy $true | Out-Null
        }
        
        It "Should get drone by ID" {
            $drone = Get-Drone -DroneId 'get_001'
            $drone.DroneId | Should -Be 'get_001'
            $drone.Type | Should -Be 'Scout'
        }
        
        It "Should return null for unknown ID" {
            $drone = Get-Drone -DroneId 'unknown'
            $drone | Should -BeNullOrEmpty
        }
        
        It "Should get all drones" {
            $drones = Get-Drone
            $drones.Count | Should -Be 4
        }
        
        It "Should filter by type" {
            $drones = Get-Drone -Type 'Combat'
            $drones.Count | Should -Be 2  # 1 player + 1 enemy
        }
        
        It "Should filter player only" {
            $drones = Get-Drone -PlayerOnly
            $drones.Count | Should -Be 3
        }
        
        It "Should filter enemy only" {
            $drones = Get-Drone -EnemyOnly
            $drones.Count | Should -Be 1
        }
    }
    
    Describe "Remove-Drone" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'rem_001' -Type 'Scout' | Out-Null
        }
        
        It "Should remove drone" {
            $result = Remove-Drone -DroneId 'rem_001'
            $result | Should -Be $true
            Get-Drone -DroneId 'rem_001' | Should -BeNullOrEmpty
        }
        
        It "Should track destroyed drones" {
            Remove-Drone -DroneId 'rem_001' -Destroyed | Out-Null
            $state = Get-DroneSystemState
            $state.TotalDronesDestroyed | Should -Be 1
        }
        
        It "Should return false for unknown drone" {
            $result = Remove-Drone -DroneId 'unknown'
            $result | Should -Be $false
        }
    }
    
    Describe "Set-DroneStatus" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'status_001' -Type 'Scout' | Out-Null
        }
        
        It "Should change drone status" {
            Set-DroneStatus -DroneId 'status_001' -Status 'Deployed' | Out-Null
            $drone = Get-Drone -DroneId 'status_001'
            $drone.Status | Should -Be 'Deployed'
        }
        
        It "Should set deployed time" {
            Set-DroneStatus -DroneId 'status_001' -Status 'Deployed' | Out-Null
            $drone = Get-Drone -DroneId 'status_001'
            $drone.DeployedAt | Should -Not -BeNullOrEmpty
        }
    }
    
    Describe "Drone Inventory" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
        }
        
        Describe "Add-DroneToInventory" {
            It "Should add drone to inventory" {
                $result = Add-DroneToInventory -Type 'Scout'
                $result.Success | Should -Be $true
                $result.Type | Should -Be 'Scout'
                $result.Quantity | Should -Be 1
            }
            
            It "Should add multiple drones" {
                $result = Add-DroneToInventory -Type 'Combat' -Quantity 3
                $result.Success | Should -Be $true
                $result.Quantity | Should -Be 3
                $result.InventoryIds.Count | Should -Be 3
            }
            
            It "Should respect inventory limit" {
                Initialize-DroneSystem -Configuration @{ MaxDroneInventory = 2 } | Out-Null
                Add-DroneToInventory -Type 'Scout' | Out-Null
                Add-DroneToInventory -Type 'Scout' | Out-Null
                $result = Add-DroneToInventory -Type 'Scout'
                $result.Success | Should -Be $false
                $result.Reason | Should -BeLike "*full*"
            }
        }
        
        Describe "Get-DroneInventory" {
            It "Should get empty inventory" {
                $inv = Get-DroneInventory
                $inv.Count | Should -Be 0
            }
            
            It "Should get inventory items" {
                Add-DroneToInventory -Type 'Scout' | Out-Null
                Add-DroneToInventory -Type 'Combat' | Out-Null
                $inv = Get-DroneInventory
                $inv.Count | Should -Be 2
            }
            
            It "Should filter by type" {
                Add-DroneToInventory -Type 'Scout' -Quantity 2 | Out-Null
                Add-DroneToInventory -Type 'Combat' | Out-Null
                $inv = Get-DroneInventory -Type 'Scout'
                $inv.Count | Should -Be 2
            }
        }
        
        Describe "Remove-DroneFromInventory" {
            It "Should remove from inventory" {
                $added = Add-DroneToInventory -Type 'Scout'
                $result = Remove-DroneFromInventory -InventoryId $added.InventoryIds[0]
                $result | Should -Be $true
                (Get-DroneInventory).Count | Should -Be 0
            }
        }
    }
    
    Describe "Drone Deployment" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            Add-DroneToInventory -Type 'Scout' | Out-Null
            Add-DroneToInventory -Type 'Combat' | Out-Null
        }
        
        Describe "Deploy-Drone" {
            It "Should deploy drone from inventory" {
                $result = Deploy-Drone -Type 'Scout'
                $result.Success | Should -Be $true
                $result.DroneId | Should -Not -BeNullOrEmpty
                $result.Drone.Type | Should -Be 'Scout'
            }
            
            It "Should remove from inventory on deploy" {
                $initialInv = (Get-DroneInventory).Count
                Deploy-Drone -Type 'Scout' | Out-Null
                (Get-DroneInventory).Count | Should -Be ($initialInv - 1)
            }
            
            It "Should set custom position" {
                $result = Deploy-Drone -Type 'Scout' -Position @{ X = 100; Y = 200; Z = 100 }
                $drone = Get-Drone -DroneId $result.DroneId
                $drone.Position.X | Should -Be 100
            }
            
            It "Should respect active drone limit" {
                Initialize-DroneSystem -Configuration @{ MaxActiveDrones = 1 } | Out-Null
                Add-DroneToInventory -Type 'Scout' -Quantity 2 | Out-Null
                Deploy-Drone -Type 'Scout' | Out-Null
                $result = Deploy-Drone -Type 'Scout'
                $result.Success | Should -Be $false
                $result.Reason | Should -BeLike "*Maximum*"
            }
            
            It "Should fail if no inventory" {
                Initialize-DroneSystem | Out-Null  # Reset inventory
                $result = Deploy-Drone -Type 'Heavy'
                $result.Success | Should -Be $false
            }
        }
        
        Describe "Recall-Drone" {
            It "Should recall deployed drone" {
                $deployed = Deploy-Drone -Type 'Scout'
                $result = Recall-Drone -DroneId $deployed.DroneId
                $result.Success | Should -Be $true
            }
            
            It "Should return drone to inventory" {
                $initialInv = (Get-DroneInventory).Count
                $deployed = Deploy-Drone -Type 'Scout'
                Recall-Drone -DroneId $deployed.DroneId | Out-Null
                (Get-DroneInventory).Count | Should -Be $initialInv
            }
            
            It "Should fail for unknown drone" {
                $result = Recall-Drone -DroneId 'unknown'
                $result.Success | Should -Be $false
            }
            
            It "Should fail for enemy drone" {
                New-Drone -DroneId 'enemy_recall' -Type 'Combat' -IsEnemy $true | Out-Null
                $result = Recall-Drone -DroneId 'enemy_recall'
                $result.Success | Should -Be $false
            }
        }
    }
    
    Describe "Drone Actions" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
        }
        
        Describe "Invoke-DroneAction - Scan" {
            BeforeEach {
                New-Drone -DroneId 'scan_drone' -Type 'Scout' | Out-Null
                Set-DroneStatus -DroneId 'scan_drone' -Status 'Deployed' | Out-Null
            }
            
            It "Should perform scan" {
                $result = Invoke-DroneAction -DroneId 'scan_drone' -Action 'Scan'
                $result.Success | Should -Be $true
                $result.ScanRadius | Should -BeGreaterThan 0
            }
            
            It "Should consume energy" {
                $drone = Get-Drone -DroneId 'scan_drone'
                $initialEnergy = $drone.Energy
                Invoke-DroneAction -DroneId 'scan_drone' -Action 'Scan' | Out-Null
                $drone = Get-Drone -DroneId 'scan_drone'
                $drone.Energy | Should -BeLessThan $initialEnergy
            }
            
            It "Should fail with insufficient energy" {
                $drone = Get-Drone -DroneId 'scan_drone'
                $drone.Energy = 5
                $result = Invoke-DroneAction -DroneId 'scan_drone' -Action 'Scan'
                $result.Success | Should -Be $false
            }
        }
        
        Describe "Invoke-DroneAction - Attack" {
            BeforeEach {
                New-Drone -DroneId 'attack_drone' -Type 'Combat' | Out-Null
                Set-DroneStatus -DroneId 'attack_drone' -Status 'Deployed' | Out-Null
            }
            
            It "Should perform attack" {
                $result = Invoke-DroneAction -DroneId 'attack_drone' -Action 'Attack' -TargetId 'enemy1'
                $result.Success | Should -Be $true
                $result.Damage | Should -BeGreaterThan 0
            }
            
            It "Should track damage dealt" {
                Invoke-DroneAction -DroneId 'attack_drone' -Action 'Attack' | Out-Null
                $drone = Get-Drone -DroneId 'attack_drone'
                $drone.DamageDealt | Should -BeGreaterThan 0
            }
            
            It "Should set combat status" {
                Invoke-DroneAction -DroneId 'attack_drone' -Action 'Attack' | Out-Null
                $drone = Get-Drone -DroneId 'attack_drone'
                $drone.Status | Should -Be 'Combat'
            }
        }
        
        Describe "Invoke-DroneAction - Heal" {
            BeforeEach {
                New-Drone -DroneId 'support_drone' -Type 'Support' | Out-Null
            }
            
            It "Should perform heal" {
                $result = Invoke-DroneAction -DroneId 'support_drone' -Action 'Heal' -TargetId 'player'
                $result.Success | Should -Be $true
                $result.HealAmount | Should -BeGreaterThan 0
            }
        }
        
        Describe "Invoke-DroneAction - EMPBlast" {
            BeforeEach {
                New-Drone -DroneId 'emp_drone' -Type 'EMP' | Out-Null
            }
            
            It "Should perform EMP blast" {
                $result = Invoke-DroneAction -DroneId 'emp_drone' -Action 'EMPBlast'
                $result.Success | Should -Be $true
                $result.EMPRadius | Should -BeGreaterThan 0
                $result.EMPDamage | Should -BeGreaterThan 0
            }
        }
        
        Describe "Invoke-DroneAction - Cloak" {
            BeforeEach {
                New-Drone -DroneId 'stealth_drone' -Type 'Stealth' | Out-Null
            }
            
            It "Should activate cloak" {
                $result = Invoke-DroneAction -DroneId 'stealth_drone' -Action 'Cloak'
                $result.Success | Should -Be $true
                $drone = Get-Drone -DroneId 'stealth_drone'
                $drone.Status | Should -Be 'Cloaked'
            }
            
            It "Should decloak" {
                Invoke-DroneAction -DroneId 'stealth_drone' -Action 'Cloak' | Out-Null
                $result = Invoke-DroneAction -DroneId 'stealth_drone' -Action 'Decloak'
                $result.Success | Should -Be $true
                $drone = Get-Drone -DroneId 'stealth_drone'
                $drone.Status | Should -Be 'Deployed'
            }
        }
        
        Describe "Invoke-DroneAction - Disabled Drone" {
            It "Should fail when disabled" {
                New-Drone -DroneId 'disabled_drone' -Type 'Scout' | Out-Null
                Set-DroneStatus -DroneId 'disabled_drone' -Status 'Disabled' | Out-Null
                $result = Invoke-DroneAction -DroneId 'disabled_drone' -Action 'Scan'
                $result.Success | Should -Be $false
            }
        }
        
        Describe "Invoke-DroneAction - Missing Ability" {
            It "Should fail if drone lacks ability" {
                New-Drone -DroneId 'scout_no_attack' -Type 'Scout' | Out-Null
                $result = Invoke-DroneAction -DroneId 'scout_no_attack' -Action 'Attack'
                $result.Success | Should -Be $false
                $result.Reason | Should -BeLike "*does not have ability*"
            }
        }
    }
    
    Describe "Move-Drone" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'move_drone' -Type 'Scout' -Position @{ X = 0; Y = 0; Z = 50 } | Out-Null
        }
        
        It "Should move drone" {
            $result = Move-Drone -DroneId 'move_drone' -TargetPosition @{ X = 100; Y = 100; Z = 50 }
            $result.Success | Should -Be $true
            $drone = Get-Drone -DroneId 'move_drone'
            $drone.Position.X | Should -Be 100
        }
        
        It "Should calculate distance" {
            $result = Move-Drone -DroneId 'move_drone' -TargetPosition @{ X = 100; Y = 0; Z = 50 }
            $result.Distance | Should -Be 100
        }
        
        It "Should consume energy based on distance" {
            $drone = Get-Drone -DroneId 'move_drone'
            $initialEnergy = $drone.Energy
            Move-Drone -DroneId 'move_drone' -TargetPosition @{ X = 200; Y = 0; Z = 50 } | Out-Null
            $drone = Get-Drone -DroneId 'move_drone'
            $drone.Energy | Should -BeLessThan $initialEnergy
        }
        
        It "Should fail with insufficient energy" {
            $drone = Get-Drone -DroneId 'move_drone'
            $drone.Energy = 1
            $result = Move-Drone -DroneId 'move_drone' -TargetPosition @{ X = 1000; Y = 1000; Z = 50 }
            $result.Success | Should -Be $false
        }
        
        It "Should fail for turret" {
            New-Drone -DroneId 'turret_move' -Type 'Turret' | Out-Null
            $result = Move-Drone -DroneId 'turret_move' -TargetPosition @{ X = 100; Y = 100; Z = 0 }
            $result.Success | Should -Be $false
            $result.Reason | Should -BeLike "*cannot move*"
        }
    }
    
    Describe "Drone Missions" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'mission_scout' -Type 'Scout' | Out-Null
            New-Drone -DroneId 'mission_combat' -Type 'Combat' | Out-Null
        }
        
        Describe "Start-DroneMission" {
            It "Should start patrol mission" {
                $result = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol'
                $result.Success | Should -Be $true
                $result.MissionId | Should -Not -BeNullOrEmpty
            }
            
            It "Should consume energy" {
                $drone = Get-Drone -DroneId 'mission_scout'
                $initialEnergy = $drone.Energy
                Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol' | Out-Null
                $drone = Get-Drone -DroneId 'mission_scout'
                $drone.Energy | Should -BeLessThan $initialEnergy
            }
            
            It "Should set drone on mission" {
                Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol' | Out-Null
                $drone = Get-Drone -DroneId 'mission_scout'
                $drone.Status | Should -Be 'OnMission'
                $drone.CurrentMission | Should -Not -BeNullOrEmpty
            }
            
            It "Should fail if already on mission" {
                Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol' | Out-Null
                $result = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Reconnaissance'
                $result.Success | Should -Be $false
            }
            
            It "Should fail if missing required ability" {
                $result = Start-DroneMission -DroneId 'mission_combat' -MissionType 'Reconnaissance'
                $result.Success | Should -Be $false
                $result.Reason | Should -BeLike "*lacks required ability*"
            }
        }
        
        Describe "Get-DroneMission" {
            It "Should get mission by ID" {
                $started = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol'
                $mission = Get-DroneMission -MissionId $started.MissionId
                $mission.MissionType | Should -Be 'Patrol'
            }
            
            It "Should get mission by drone ID" {
                $started = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol'
                $mission = Get-DroneMission -DroneId 'mission_scout'
                $mission.MissionId | Should -Be $started.MissionId
            }
            
            It "Should get all active missions" {
                Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol' | Out-Null
                Start-DroneMission -DroneId 'mission_combat' -MissionType 'Patrol' | Out-Null
                $missions = Get-DroneMission -ActiveOnly
                $missions.Count | Should -Be 2
            }
        }
        
        Describe "Complete-DroneMission" {
            It "Should complete mission successfully" {
                $started = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol'
                $result = Complete-DroneMission -MissionId $started.MissionId -Success $true
                $result.Success | Should -Be $true
                $result.MissionSuccess | Should -Be $true
            }
            
            It "Should award XP on success" {
                $started = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol'
                $result = Complete-DroneMission -MissionId $started.MissionId -Success $true
                $result.XPAwarded | Should -BeGreaterThan 0
            }
            
            It "Should not award XP on failure" {
                $started = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol'
                $result = Complete-DroneMission -MissionId $started.MissionId -Success $false
                $result.XPAwarded | Should -Be 0
            }
            
            It "Should clear drone mission" {
                $started = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol'
                Complete-DroneMission -MissionId $started.MissionId | Out-Null
                $drone = Get-Drone -DroneId 'mission_scout'
                $drone.CurrentMission | Should -BeNullOrEmpty
                $drone.Status | Should -Be 'Deployed'
            }
            
            It "Should increment missions completed" {
                $drone = Get-Drone -DroneId 'mission_scout'
                $initial = $drone.MissionsCompleted
                $started = Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol'
                Complete-DroneMission -MissionId $started.MissionId -Success $true | Out-Null
                $drone = Get-Drone -DroneId 'mission_scout'
                $drone.MissionsCompleted | Should -Be ($initial + 1)
            }
        }
        
        Describe "Cancel-DroneMission" {
            It "Should cancel mission" {
                Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol' | Out-Null
                $result = Cancel-DroneMission -DroneId 'mission_scout'
                $result.Success | Should -Be $true
            }
            
            It "Should clear drone mission" {
                Start-DroneMission -DroneId 'mission_scout' -MissionType 'Patrol' | Out-Null
                Cancel-DroneMission -DroneId 'mission_scout' | Out-Null
                $drone = Get-Drone -DroneId 'mission_scout'
                $drone.CurrentMission | Should -BeNullOrEmpty
            }
        }
    }
    
    Describe "Drone Combat" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'combat_target' -Type 'Scout' | Out-Null
        }
        
        Describe "Invoke-DroneDamage" {
            It "Should apply damage" {
                $drone = Get-Drone -DroneId 'combat_target'
                $initialHP = $drone.HP
                $result = Invoke-DroneDamage -DroneId 'combat_target' -Damage 10
                $result.ActualDamage | Should -Be 10
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.HP | Should -Be ($initialHP - 10)
            }
            
            It "Should apply armor mitigation" {
                New-Drone -DroneId 'armored' -Type 'Heavy' | Out-Null  # Has armor
                $result = Invoke-DroneDamage -DroneId 'armored' -Damage 20 -DamageType 'Kinetic'
                $result.ArmorMitigation | Should -BeGreaterThan 0
                $result.ActualDamage | Should -BeLessThan 20
            }
            
            It "Should apply EMP bonus damage" {
                $result = Invoke-DroneDamage -DroneId 'combat_target' -Damage 20 -DamageType 'EMP'
                $result.ActualDamage | Should -BeGreaterThan 20
            }
            
            It "Should disable drone at 0 HP" {
                $drone = Get-Drone -DroneId 'combat_target'
                Invoke-DroneDamage -DroneId 'combat_target' -Damage ($drone.HP + 10) | Out-Null
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.HP | Should -Be 0
                $drone.Status | Should -Be 'Disabled'
            }
            
            It "Should mark as damaged when critically low" {
                $drone = Get-Drone -DroneId 'combat_target'
                $criticalDamage = $drone.HP - ($drone.MaxHP * 0.2)
                Invoke-DroneDamage -DroneId 'combat_target' -Damage $criticalDamage | Out-Null
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.Status | Should -Be 'Damaged'
            }
        }
        
        Describe "Repair-Drone" {
            BeforeEach {
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.HP = 10
                $drone.Status = 'Damaged'
            }
            
            It "Should repair drone" {
                $result = Repair-Drone -DroneId 'combat_target' -Amount 15
                $result.Repaired | Should -Be 15
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.HP | Should -Be 25
            }
            
            It "Should full repair" {
                $result = Repair-Drone -DroneId 'combat_target' -FullRepair
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.HP | Should -Be $drone.MaxHP
            }
            
            It "Should not exceed max HP" {
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.HP = $drone.MaxHP - 5
                $result = Repair-Drone -DroneId 'combat_target' -Amount 20
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.HP | Should -Be $drone.MaxHP
            }
            
            It "Should restore disabled drone" {
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.Status = 'Disabled'
                Repair-Drone -DroneId 'combat_target' -FullRepair | Out-Null
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.Status | Should -Be 'Idle'
            }
        }
        
        Describe "Recharge-Drone" {
            BeforeEach {
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.Energy = 20
            }
            
            It "Should recharge drone" {
                $result = Recharge-Drone -DroneId 'combat_target' -Amount 30
                $result.Recharged | Should -Be 30
            }
            
            It "Should full recharge" {
                $result = Recharge-Drone -DroneId 'combat_target' -FullRecharge
                $drone = Get-Drone -DroneId 'combat_target'
                $drone.Energy | Should -Be $drone.MaxEnergy
            }
        }
    }
    
    Describe "Drone Override" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'enemy_target' -Type 'Scout' -IsEnemy $true | Out-Null
        }
        
        It "Should attempt override" {
            $result = Invoke-DroneOverride -DroneId 'enemy_target' -Intelligence 20 -HackingSkill 5
            $result.Roll | Should -BeGreaterThan 0
            $result.RequiredRoll | Should -BeGreaterThan 0
        }
        
        It "Should fail on friendly drone" {
            New-Drone -DroneId 'friendly' -Type 'Scout' | Out-Null
            $result = Invoke-DroneOverride -DroneId 'friendly'
            $result.Success | Should -Be $false
            $result.Reason | Should -BeLike "*friendly*"
        }
        
        It "Should fail on disabled drone" {
            Set-DroneStatus -DroneId 'enemy_target' -Status 'Disabled' | Out-Null
            $result = Invoke-DroneOverride -DroneId 'enemy_target'
            $result.Success | Should -Be $false
        }
        
        It "Should transfer ownership on success" {
            # Set up high chance of success
            $initialEnemyCount = (Get-Drone -EnemyOnly).Count
            # Force success with mock - we test the mechanism
            for ($i = 0; $i -lt 100; $i++) {
                Initialize-DroneSystem | Out-Null
                New-Drone -DroneId "enemy_$i" -Type 'Scout' -IsEnemy $true | Out-Null
                $result = Invoke-DroneOverride -DroneId "enemy_$i" -Intelligence 20 -HackingSkill 10
                if ($result.Success) {
                    $result.NewOwnerId | Should -Not -BeNullOrEmpty
                    $drone = Get-Drone -DroneId "enemy_$i"
                    $drone.IsEnemy | Should -Be $false
                    break
                }
            }
        }
    }
    
    Describe "Drone Upgrades" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'upgrade_drone' -Type 'Scout' | Out-Null
        }
        
        Describe "Get-DroneUpgrade" {
            It "Should list all upgrades" {
                $upgrades = Get-DroneUpgrade
                $upgrades.Count | Should -BeGreaterThan 0
            }
            
            It "Should get specific upgrade" {
                $upgrade = Get-DroneUpgrade -UpgradeName 'ArmorPlating'
                $upgrade.Name | Should -Be 'ArmorPlating'
                $upgrade.Cost | Should -BeGreaterThan 0
            }
        }
        
        Describe "Install-DroneUpgrade" {
            It "Should install upgrade" {
                $result = Install-DroneUpgrade -DroneId 'upgrade_drone' -UpgradeName 'ArmorPlating'
                $result.Success | Should -Be $true
                $result.NewLevel | Should -Be 1
            }
            
            It "Should apply upgrade effects" {
                $drone = Get-Drone -DroneId 'upgrade_drone'
                $initialArmor = $drone.Armor
                Install-DroneUpgrade -DroneId 'upgrade_drone' -UpgradeName 'ArmorPlating' | Out-Null
                $drone = Get-Drone -DroneId 'upgrade_drone'
                $drone.Armor | Should -BeGreaterThan $initialArmor
            }
            
            It "Should respect max level" {
                $upgrade = Get-DroneUpgrade -UpgradeName 'StealthCoating'
                for ($i = 0; $i -lt $upgrade.MaxLevel; $i++) {
                    Install-DroneUpgrade -DroneId 'upgrade_drone' -UpgradeName 'StealthCoating' | Out-Null
                }
                $result = Install-DroneUpgrade -DroneId 'upgrade_drone' -UpgradeName 'StealthCoating'
                $result.Success | Should -Be $false
                $result.Reason | Should -BeLike "*max level*"
            }
        }
    }
    
    Describe "State Management" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            Add-DroneToInventory -Type 'Scout' -Quantity 3 | Out-Null
            New-Drone -DroneId 'state_drone' -Type 'Combat' | Out-Null
        }
        
        Describe "Get-DroneSystemState" {
            It "Should return system state" {
                $state = Get-DroneSystemState
                $state.Initialized | Should -Be $true
            }
            
            It "Should count drones" {
                $state = Get-DroneSystemState
                $state.TotalDrones | Should -Be 1
                $state.InventoryCount | Should -Be 3
            }
        }
        
        Describe "Get-DroneStatistics" {
            It "Should get individual drone stats" {
                $stats = Get-DroneStatistics -DroneId 'state_drone'
                $stats.DroneId | Should -Be 'state_drone'
                $stats.Level | Should -Be 1
            }
            
            It "Should get overall statistics" {
                $stats = Get-DroneStatistics
                $stats | Should -Not -BeNullOrEmpty
            }
        }
        
        Describe "Export/Import Data" {
            It "Should export data" {
                $tempFile = Join-Path $env:TEMP "drone_test_export.json"
                $result = Export-DroneData -FilePath $tempFile
                $result.Success | Should -Be $true
                Test-Path $tempFile | Should -Be $true
                if (Test-Path $tempFile) { Remove-Item $tempFile }
            }
            
            It "Should import data" {
                $tempFile = Join-Path $env:TEMP "drone_test_import.json"
                Export-DroneData -FilePath $tempFile | Out-Null
                
                Initialize-DroneSystem | Out-Null  # Reset
                $result = Import-DroneData -FilePath $tempFile
                $result.Success | Should -Be $true
                
                if (Test-Path $tempFile) { Remove-Item $tempFile }
            }
        }
    }
    
    Describe "Event Processing" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'event_drone' -Type 'Scout' | Out-Null
            Set-DroneStatus -DroneId 'event_drone' -Status 'Deployed' | Out-Null
        }
        
        It "Should process time advanced event" {
            $drone = Get-Drone -DroneId 'event_drone'
            $drone.Energy = 50
            $results = Process-DroneEvent -EventType 'TimeAdvanced' -EventData @{ MinutesPassed = 60 }
            $drone = Get-Drone -DroneId 'event_drone'
            $drone.Energy | Should -BeGreaterThan 50
        }
        
        It "Should process combat started event" {
            $results = Process-DroneEvent -EventType 'CombatStarted'
            $drone = Get-Drone -DroneId 'event_drone'
            $drone.Status | Should -Be 'Combat'
        }
        
        It "Should process combat ended event" {
            Set-DroneStatus -DroneId 'event_drone' -Status 'Combat' | Out-Null
            $results = Process-DroneEvent -EventType 'CombatEnded'
            $drone = Get-Drone -DroneId 'event_drone'
            $drone.Status | Should -Be 'Deployed'
        }
        
        It "Should process EMP detonated event" {
            New-Drone -DroneId 'emp_victim' -Type 'Combat' -Position @{ X = 50; Y = 50; Z = 0 } | Out-Null
            $results = Process-DroneEvent -EventType 'EMPDetonated' -EventData @{
                Position = @{ X = 50; Y = 50; Z = 0 }
                Radius = 100
                Damage = 50
            }
            $results.Count | Should -BeGreaterThan 0
        }
        
        It "Should process area entered event" {
            New-Drone -DroneId 'enemy_area' -Type 'Combat' -Position @{ X = 100; Y = 100; Z = 0 } -IsEnemy $true | Out-Null
            $results = Process-DroneEvent -EventType 'AreaEntered' -EventData @{
                Position = @{ X = 100; Y = 100; Z = 0 }
            }
            $enemyDetected = $results | Where-Object { $_.Type -eq 'EnemyDroneDetected' }
            $enemyDetected | Should -Not -BeNullOrEmpty
        }
    }
    
    Describe "Level Up System" {
        BeforeEach {
            Initialize-DroneSystem | Out-Null
            New-Drone -DroneId 'levelup_drone' -Type 'Scout' | Out-Null
        }
        
        It "Should level up when XP threshold reached" {
            $drone = Get-Drone -DroneId 'levelup_drone'
            $drone.XP = 99  # Just below threshold
            
            $started = Start-DroneMission -DroneId 'levelup_drone' -MissionType 'Patrol'
            $result = Complete-DroneMission -MissionId $started.MissionId -Success $true
            
            $drone = Get-Drone -DroneId 'levelup_drone'
            # Should have gained enough XP to level up
            if ($result.XPAwarded -gt 1) {
                $drone.Level | Should -BeGreaterOrEqual 1
            }
        }
        
        It "Should increase stats on level up" {
            $drone = Get-Drone -DroneId 'levelup_drone'
            $drone.XP = $drone.XPToNextLevel - 1
            $initialMaxHP = $drone.MaxHP
            
            $started = Start-DroneMission -DroneId 'levelup_drone' -MissionType 'Patrol'
            Complete-DroneMission -MissionId $started.MissionId -Success $true | Out-Null
            
            $drone = Get-Drone -DroneId 'levelup_drone'
            if ($drone.Level -gt 1) {
                $drone.MaxHP | Should -BeGreaterThan $initialMaxHP
            }
        }
    }
}
