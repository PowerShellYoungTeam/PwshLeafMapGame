# FactionSystem.Tests.ps1
# Comprehensive tests for the FactionSystem module

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "..\Modules\FactionSystem\FactionSystem.psm1"
    Import-Module $modulePath -Force
}

Describe "FactionSystem Module" {
    
    Describe "Initialize-FactionSystem" {
        BeforeEach {
            # Fresh init for each test
            Initialize-FactionSystem | Out-Null
        }
        
        It "Should initialize successfully with default configuration" {
            $result = Initialize-FactionSystem
            $result.Initialized | Should -BeTrue
            $result.ModuleName | Should -Be 'FactionSystem'
        }
        
        It "Should return available faction types" {
            $result = Initialize-FactionSystem
            $result.FactionTypes | Should -Contain 'Corporation'
            $result.FactionTypes | Should -Contain 'Crew'
            $result.FactionTypes | Should -Contain 'Syndicate'
            $result.FactionTypes | Should -Contain 'YoungTeam'
            $result.FactionTypes | Should -Contain 'Underground'
            $result.FactionTypes | Should -Contain 'Independent'
            $result.FactionTypes | Should -Contain 'Player'
        }
        
        It "Should return standing levels" {
            $result = Initialize-FactionSystem
            $result.StandingLevels | Should -Contain 'Hostile'
            $result.StandingLevels | Should -Contain 'Unfriendly'
            $result.StandingLevels | Should -Contain 'Neutral'
            $result.StandingLevels | Should -Contain 'Friendly'
            $result.StandingLevels | Should -Contain 'Allied'
        }
        
        It "Should accept custom configuration" {
            $config = @{
                DefaultPlayerReputation = 10
                MaxReputation = 500
            }
            $result = Initialize-FactionSystem -Configuration $config
            $result.Configuration.DefaultPlayerReputation | Should -Be 10
            $result.Configuration.MaxReputation | Should -Be 500
        }
    }
    
    Describe "New-Faction" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
        }
        
        It "Should create a Corporation faction" {
            $faction = New-Faction -FactionId 'omnitech' -Name 'OmniTech Industries' -Type 'Corporation'
            $faction.FactionId | Should -Be 'omnitech'
            $faction.Name | Should -Be 'OmniTech Industries'
            $faction.Type | Should -Be 'Corporation'
            $faction.IsActive | Should -BeTrue
        }
        
        It "Should create a Crew faction (ex-military)" {
            $faction = New-Faction `
                -FactionId 'iron_wolves' `
                -Name 'Iron Wolves' `
                -Type 'Crew' `
                -Description 'Former military operators turned crime syndicate' `
                -Leader 'Colonel Viktor Volkov' `
                -LeaderTitle 'Commander'
            
            $faction.Type | Should -Be 'Crew'
            $faction.Leader | Should -Be 'Colonel Viktor Volkov'
            $faction.TypeInfo.OrganizationLevel | Should -Be 'VeryHigh'
            $faction.TypeInfo.DefaultDanger | Should -Be 'VeryHigh'
        }
        
        It "Should create a Syndicate faction (organized street gang)" {
            $faction = New-Faction `
                -FactionId 'neon_serpents' `
                -Name 'Neon Serpents' `
                -Type 'Syndicate' `
                -Colors 'Green & Black' `
                -Specializations @('DrugTrafficking', 'Extortion')
            
            $faction.Type | Should -Be 'Syndicate'
            $faction.Colors | Should -Be 'Green & Black'
            $faction.TypeInfo.OrganizationLevel | Should -Be 'High'
        }
        
        It "Should create a YoungTeam faction (youth gang)" {
            $faction = New-Faction `
                -FactionId 'westside_razors' `
                -Name 'Westside Razors' `
                -Type 'YoungTeam' `
                -DangerLevel 'Medium'
            
            $faction.Type | Should -Be 'YoungTeam'
            $faction.TypeInfo.OrganizationLevel | Should -Be 'Low'
            $faction.TypeInfo.Description | Should -Match 'Youth street gangs'
        }
        
        It "Should create an Underground faction" {
            $faction = New-Faction `
                -FactionId 'fixers_guild' `
                -Name "Fixers' Guild" `
                -Type 'Underground'
            
            $faction.Type | Should -Be 'Underground'
            $faction.Services | Should -Contain 'Intel'
        }
        
        It "Should initialize player reputation with new faction" {
            New-Faction -FactionId 'test_corp' -Name 'Test Corp' -Type 'Corporation'
            $rep = Get-Reputation -FactionId 'test_corp'
            $rep.Reputation | Should -Be 0
            $rep.Standing | Should -Be 'Neutral'
        }
        
        It "Should register controlled territories" {
            $faction = New-Faction `
                -FactionId 'corp1' `
                -Name 'Corp One' `
                -Type 'Corporation' `
                -ControlledTerritories @('downtown_plaza', 'corp_tower')
            
            $controller = Get-TerritoryController -TerritoryId 'downtown_plaza'
            $controller.FactionId | Should -Be 'corp1'
        }
        
        It "Should create a hidden faction" {
            $faction = New-Faction `
                -FactionId 'shadow_council' `
                -Name 'Shadow Council' `
                -Type 'Corporation' `
                -IsHidden $true
            
            $faction.IsHidden | Should -BeTrue
            
            # Should not appear in regular queries
            $visible = Get-Faction
            $visible.FactionId | Should -Not -Contain 'shadow_council'
            
            # Should appear with IncludeHidden
            $all = Get-Faction -IncludeHidden
            $all.FactionId | Should -Contain 'shadow_council'
        }
    }
    
    Describe "Get-Faction" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'corp1' -Name 'Corp 1' -Type 'Corporation' | Out-Null
            New-Faction -FactionId 'crew1' -Name 'Crew 1' -Type 'Crew' | Out-Null
            New-Faction -FactionId 'yt1' -Name 'Young Team 1' -Type 'YoungTeam' | Out-Null
        }
        
        It "Should get a specific faction by ID" {
            $faction = Get-Faction -FactionId 'corp1'
            $faction.Name | Should -Be 'Corp 1'
        }
        
        It "Should get all factions" {
            $factions = Get-Faction
            $factions.Count | Should -BeGreaterOrEqual 3
        }
        
        It "Should filter factions by type" {
            $crews = Get-Faction -Type 'Crew'
            $crews | ForEach-Object { $_.Type | Should -Be 'Crew' }
        }
    }
    
    Describe "Set-FactionActive" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'test_faction' -Name 'Test' -Type 'Syndicate' | Out-Null
        }
        
        It "Should deactivate a faction" {
            $result = Set-FactionActive -FactionId 'test_faction' -Active $false
            $result | Should -BeTrue
            
            $faction = Get-Faction -FactionId 'test_faction'
            $faction.IsActive | Should -BeFalse
        }
        
        It "Should reactivate a faction" {
            Set-FactionActive -FactionId 'test_faction' -Active $false | Out-Null
            Set-FactionActive -FactionId 'test_faction' -Active $true | Out-Null
            
            $faction = Get-Faction -FactionId 'test_faction'
            $faction.IsActive | Should -BeTrue
        }
    }
    
    Describe "Remove-Faction" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'to_remove' -Name 'Doomed' -Type 'YoungTeam' `
                -ControlledTerritories @('turf1') | Out-Null
        }
        
        It "Should remove a faction" {
            $result = Remove-Faction -FactionId 'to_remove'
            $result | Should -BeTrue
            
            $faction = Get-Faction -FactionId 'to_remove'
            $faction | Should -BeNullOrEmpty
        }
        
        It "Should clean up territory control when removing faction" {
            Remove-Faction -FactionId 'to_remove' | Out-Null
            $controller = Get-TerritoryController -TerritoryId 'turf1'
            $controller | Should -BeNullOrEmpty
        }
    }
    
    Describe "Reputation System" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'rep_test' -Name 'Rep Test' -Type 'Syndicate' | Out-Null
        }
        
        Describe "Get-Reputation" {
            It "Should return current reputation and standing" {
                $rep = Get-Reputation -FactionId 'rep_test'
                $rep.FactionId | Should -Be 'rep_test'
                $rep.Reputation | Should -Be 0
                $rep.Standing | Should -Be 'Neutral'
                $rep.PriceModifier | Should -Be 1.0
            }
            
            It "Should return access level based on standing" {
                $rep = Get-Reputation -FactionId 'rep_test'
                $rep.AccessLevel | Should -Be 2  # Neutral = access level 2
            }
            
            It "Should indicate next reputation threshold" {
                $rep = Get-Reputation -FactionId 'rep_test'
                $rep.NextThreshold.Standing | Should -Be 'Friendly'
            }
        }
        
        Describe "Set-Reputation" {
            It "Should set reputation to a specific value" {
                $result = Set-Reputation -FactionId 'rep_test' -Reputation 50
                $result.Success | Should -BeTrue
                $result.NewReputation | Should -Be 50
                $result.NewStanding | Should -Be 'Friendly'
            }
            
            It "Should clamp reputation to max value" {
                $result = Set-Reputation -FactionId 'rep_test' -Reputation 2000
                $result.NewReputation | Should -Be 1000  # Default max
            }
            
            It "Should clamp reputation to min value" {
                $result = Set-Reputation -FactionId 'rep_test' -Reputation -2000
                $result.NewReputation | Should -Be -1000  # Default min
            }
        }
        
        Describe "Add-Reputation" {
            It "Should add positive reputation" {
                $result = Add-Reputation -FactionId 'rep_test' -Amount 30 -Reason 'Helped them'
                $result.Success | Should -BeTrue
                $result.NewReputation | Should -Be 30
                $result.Change | Should -Be 30
            }
            
            It "Should add negative reputation" {
                $result = Add-Reputation -FactionId 'rep_test' -Amount -20 -Reason 'Attacked them'
                $result.NewReputation | Should -Be -20
            }
            
            It "Should track standing changes" {
                Add-Reputation -FactionId 'rep_test' -Amount 50 | Out-Null
                $result = Add-Reputation -FactionId 'rep_test' -Amount 30
                $result.OldStanding | Should -Be 'Friendly'
                $result.NewStanding | Should -Be 'Allied'
            }
        }
        
        Describe "Standing Levels" {
            It "Should be Hostile at -100 rep" {
                Set-Reputation -FactionId 'rep_test' -Reputation -100 | Out-Null
                $rep = Get-Reputation -FactionId 'rep_test'
                $rep.Standing | Should -Be 'Hostile'
                $rep.PriceModifier | Should -Be 2.0
                $rep.AttackOnSight | Should -BeTrue
            }
            
            It "Should be Unfriendly at -30 rep" {
                Set-Reputation -FactionId 'rep_test' -Reputation -30 | Out-Null
                $rep = Get-Reputation -FactionId 'rep_test'
                $rep.Standing | Should -Be 'Unfriendly'
                $rep.PriceModifier | Should -Be 1.5
            }
            
            It "Should be Neutral at 0 rep" {
                $rep = Get-Reputation -FactionId 'rep_test'
                $rep.Standing | Should -Be 'Neutral'
                $rep.PriceModifier | Should -Be 1.0
            }
            
            It "Should be Friendly at 50 rep" {
                Set-Reputation -FactionId 'rep_test' -Reputation 50 | Out-Null
                $rep = Get-Reputation -FactionId 'rep_test'
                $rep.Standing | Should -Be 'Friendly'
                $rep.PriceModifier | Should -Be 0.9
            }
            
            It "Should be Allied at 100 rep" {
                Set-Reputation -FactionId 'rep_test' -Reputation 100 | Out-Null
                $rep = Get-Reputation -FactionId 'rep_test'
                $rep.Standing | Should -Be 'Allied'
                $rep.PriceModifier | Should -Be 0.8
            }
        }
        
        Describe "Get-AllReputations" {
            BeforeEach {
                New-Faction -FactionId 'corp_rep' -Name 'Corp' -Type 'Corporation' | Out-Null
                New-Faction -FactionId 'gang_rep' -Name 'Gang' -Type 'Syndicate' | Out-Null
                Set-Reputation -FactionId 'corp_rep' -Reputation 50 | Out-Null
                Set-Reputation -FactionId 'gang_rep' -Reputation -30 | Out-Null
            }
            
            It "Should return all reputations sorted by value" {
                $reps = Get-AllReputations
                $reps.Count | Should -BeGreaterOrEqual 3
                # Should be sorted descending
                $reps[0].Reputation | Should -BeGreaterOrEqual $reps[1].Reputation
            }
        }
    }
    
    Describe "Faction Relationships" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'factionA' -Name 'Faction A' -Type 'Corporation' | Out-Null
            New-Faction -FactionId 'factionB' -Name 'Faction B' -Type 'Syndicate' | Out-Null
            New-Faction -FactionId 'factionC' -Name 'Faction C' -Type 'Crew' | Out-Null
        }
        
        Describe "Set-FactionRelationship" {
            It "Should set relationship between factions" {
                $result = Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship 'Hostile'
                $result.Success | Should -BeTrue
                $result.Relationship | Should -Be 'Hostile'
            }
            
            It "Should support all relationship types" {
                foreach ($rel in @('AtWar', 'Hostile', 'Rival', 'Neutral', 'Friendly', 'Allied')) {
                    $result = Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship $rel
                    $result.Relationship | Should -Be $rel
                }
            }
        }
        
        Describe "Get-FactionRelationship" {
            It "Should get relationship between factions" {
                Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship 'AtWar' | Out-Null
                $rel = Get-FactionRelationship -FactionA 'factionA' -FactionB 'factionB'
                $rel.Relationship | Should -Be 'AtWar'
            }
            
            It "Should return Neutral for undefined relationships" {
                $rel = Get-FactionRelationship -FactionA 'factionA' -FactionB 'factionC'
                $rel.Relationship | Should -Be 'Neutral'
                $rel.IsDefault | Should -BeTrue
            }
            
            It "Should be bidirectional" {
                Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship 'Allied' | Out-Null
                $rel1 = Get-FactionRelationship -FactionA 'factionA' -FactionB 'factionB'
                $rel2 = Get-FactionRelationship -FactionA 'factionB' -FactionB 'factionA'
                $rel1.Relationship | Should -Be $rel2.Relationship
            }
        }
        
        Describe "Get-FactionRelationships" {
            It "Should get all relationships for a faction" {
                Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship 'Hostile' | Out-Null
                Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionC' -Relationship 'Allied' | Out-Null
                
                $rels = Get-FactionRelationships -FactionId 'factionA'
                $rels.Count | Should -Be 2
            }
        }
        
        Describe "Test-FactionsHostile" {
            It "Should return true for AtWar factions" {
                Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship 'AtWar' | Out-Null
                Test-FactionsHostile -FactionA 'factionA' -FactionB 'factionB' | Should -BeTrue
            }
            
            It "Should return true for Hostile factions" {
                Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship 'Hostile' | Out-Null
                Test-FactionsHostile -FactionA 'factionA' -FactionB 'factionB' | Should -BeTrue
            }
            
            It "Should return false for Neutral factions" {
                Test-FactionsHostile -FactionA 'factionA' -FactionB 'factionC' | Should -BeFalse
            }
        }
        
        Describe "Test-FactionsAllied" {
            It "Should return true for Allied factions" {
                Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship 'Allied' | Out-Null
                Test-FactionsAllied -FactionA 'factionA' -FactionB 'factionB' | Should -BeTrue
            }
            
            It "Should return true for Friendly factions" {
                Set-FactionRelationship -FactionA 'factionA' -FactionB 'factionB' -Relationship 'Friendly' | Out-Null
                Test-FactionsAllied -FactionA 'factionA' -FactionB 'factionB' | Should -BeTrue
            }
            
            It "Should return false for Neutral factions" {
                Test-FactionsAllied -FactionA 'factionA' -FactionB 'factionC' | Should -BeFalse
            }
        }
    }
    
    Describe "Territory Control" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'terr_faction1' -Name 'Faction 1' -Type 'Syndicate' | Out-Null
            New-Faction -FactionId 'terr_faction2' -Name 'Faction 2' -Type 'Crew' | Out-Null
        }
        
        Describe "Set-TerritoryControl" {
            It "Should assign territory to a faction" {
                $result = Set-TerritoryControl -TerritoryId 'north_block' -FactionId 'terr_faction1'
                $result.Success | Should -BeTrue
                $result.NewController | Should -Be 'terr_faction1'
            }
            
            It "Should update faction's controlled territories list" {
                Set-TerritoryControl -TerritoryId 'east_side' -FactionId 'terr_faction1' | Out-Null
                $faction = Get-Faction -FactionId 'terr_faction1'
                $faction.ControlledTerritories | Should -Contain 'east_side'
            }
        }
        
        Describe "Get-TerritoryController" {
            It "Should return controlling faction" {
                Set-TerritoryControl -TerritoryId 'test_zone' -FactionId 'terr_faction1' | Out-Null
                $controller = Get-TerritoryController -TerritoryId 'test_zone'
                $controller.FactionId | Should -Be 'terr_faction1'
            }
            
            It "Should return null for uncontrolled territory" {
                $controller = Get-TerritoryController -TerritoryId 'uncontrolled_zone'
                $controller | Should -BeNullOrEmpty
            }
        }
        
        Describe "Get-FactionTerritories" {
            It "Should return all territories controlled by faction" {
                Set-TerritoryControl -TerritoryId 'zone1' -FactionId 'terr_faction1' | Out-Null
                Set-TerritoryControl -TerritoryId 'zone2' -FactionId 'terr_faction1' | Out-Null
                
                $territories = Get-FactionTerritories -FactionId 'terr_faction1'
                $territories | Should -Contain 'zone1'
                $territories | Should -Contain 'zone2'
            }
        }
        
        Describe "Transfer-Territory" {
            It "Should transfer territory between factions" {
                Set-TerritoryControl -TerritoryId 'contested' -FactionId 'terr_faction1' | Out-Null
                $result = Transfer-Territory -TerritoryId 'contested' -ToFactionId 'terr_faction2' -Method 'Conquest'
                
                $result.Success | Should -BeTrue
                $result.OldController | Should -Be 'terr_faction1'
                $result.NewController | Should -Be 'terr_faction2'
                $result.Method | Should -Be 'Conquest'
            }
            
            It "Should remove territory from old faction's list" {
                Set-TerritoryControl -TerritoryId 'takeover_zone' -FactionId 'terr_faction1' | Out-Null
                Transfer-Territory -TerritoryId 'takeover_zone' -ToFactionId 'terr_faction2' | Out-Null
                
                $oldFaction = Get-Faction -FactionId 'terr_faction1'
                $oldFaction.ControlledTerritories | Should -Not -Contain 'takeover_zone'
            }
        }
    }
    
    Describe "Standing Effects" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'effects_test' -Name 'Effects Test' -Type 'Syndicate' `
                -Services @('BlackMarket', 'Protection') | Out-Null
        }
        
        Describe "Get-StandingEffects" {
            It "Should return standing effects for faction" {
                Set-Reputation -FactionId 'effects_test' -Reputation 50 | Out-Null
                $effects = Get-StandingEffects -FactionId 'effects_test'
                
                $effects.Standing | Should -Be 'Friendly'
                $effects.PriceModifier | Should -Be 0.9
                $effects.CanAccessServices | Should -BeTrue
            }
            
            It "Should show available services based on standing" {
                Set-Reputation -FactionId 'effects_test' -Reputation 50 | Out-Null
                $effects = Get-StandingEffects -FactionId 'effects_test'
                $effects.AvailableServices | Should -Contain 'BlackMarket'
            }
            
            It "Should deny services when hostile" {
                Set-Reputation -FactionId 'effects_test' -Reputation -100 | Out-Null
                $effects = Get-StandingEffects -FactionId 'effects_test'
                $effects.CanAccessServices | Should -BeFalse
                $effects.AvailableServices | Should -BeNullOrEmpty
            }
        }
        
        Describe "Test-CanAccessFaction" {
            It "Should return true for sufficient access level" {
                Set-Reputation -FactionId 'effects_test' -Reputation 0 | Out-Null
                Test-CanAccessFaction -FactionId 'effects_test' -RequiredAccessLevel 2 | Should -BeTrue
            }
            
            It "Should return false for insufficient access level" {
                Set-Reputation -FactionId 'effects_test' -Reputation -100 | Out-Null
                Test-CanAccessFaction -FactionId 'effects_test' -RequiredAccessLevel 2 | Should -BeFalse
            }
        }
        
        Describe "Get-PriceModifier" {
            It "Should return correct price modifier based on standing" {
                Set-Reputation -FactionId 'effects_test' -Reputation 100 | Out-Null
                Get-PriceModifier -FactionId 'effects_test' | Should -Be 0.8
            }
            
            It "Should return 2.0 for hostile standing" {
                Set-Reputation -FactionId 'effects_test' -Reputation -100 | Out-Null
                Get-PriceModifier -FactionId 'effects_test' | Should -Be 2.0
            }
        }
    }
    
    Describe "Process-FactionEvent" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'event_faction' -Name 'Event Faction' -Type 'Syndicate' | Out-Null
        }
        
        It "Should process QuestCompleted event" {
            $results = Process-FactionEvent -EventType 'QuestCompleted' -EventData @{
                FactionId = 'event_faction'
                ReputationReward = 25
                QuestName = 'Test Quest'
            }
            
            $results.Count | Should -BeGreaterOrEqual 1
            $rep = Get-Reputation -FactionId 'event_faction'
            $rep.Reputation | Should -Be 25
        }
        
        It "Should process QuestFailed event" {
            Set-Reputation -FactionId 'event_faction' -Reputation 50 | Out-Null
            
            $results = Process-FactionEvent -EventType 'QuestFailed' -EventData @{
                FactionId = 'event_faction'
                ReputationPenalty = 15
                QuestName = 'Failed Quest'
            }
            
            $rep = Get-Reputation -FactionId 'event_faction'
            $rep.Reputation | Should -Be 35
        }
        
        It "Should process EnemyKilled event" {
            $results = Process-FactionEvent -EventType 'EnemyKilled' -EventData @{
                FactionId = 'event_faction'
                ReputationPenalty = 5
            }
            
            $rep = Get-Reputation -FactionId 'event_faction'
            $rep.Reputation | Should -Be -5
        }
    }
    
    Describe "State Export/Import" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
            New-Faction -FactionId 'export_test' -Name 'Export Test' -Type 'Corporation' | Out-Null
            Set-Reputation -FactionId 'export_test' -Reputation 50 | Out-Null
            Set-TerritoryControl -TerritoryId 'export_zone' -FactionId 'export_test' | Out-Null
        }
        
        Describe "Get-FactionSystemState" {
            It "Should return complete state" {
                $state = Get-FactionSystemState
                $state.Initialized | Should -BeTrue
                $state.Factions.Count | Should -BeGreaterOrEqual 1
                $state.Statistics.TotalFactions | Should -BeGreaterOrEqual 1
            }
        }
        
        Describe "Export-FactionData" {
            It "Should export to file" {
                $tempFile = Join-Path $TestDrive 'faction-export.json'
                $result = Export-FactionData -FilePath $tempFile
                
                $result.Success | Should -BeTrue
                Test-Path $tempFile | Should -BeTrue
            }
            
            It "Should export valid JSON" {
                $tempFile = Join-Path $TestDrive 'faction-export2.json'
                Export-FactionData -FilePath $tempFile | Out-Null
                
                $content = Get-Content $tempFile -Raw
                { $content | ConvertFrom-Json } | Should -Not -Throw
            }
        }
        
        Describe "Import-FactionData" {
            It "Should import from file" {
                $tempFile = Join-Path $TestDrive 'faction-roundtrip.json'
                Export-FactionData -FilePath $tempFile | Out-Null
                
                Initialize-FactionSystem | Out-Null  # Reset
                $result = Import-FactionData -FilePath $tempFile
                
                $result.Success | Should -BeTrue
                $faction = Get-Faction -FactionId 'export_test'
                $faction | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Describe "Faction Type Scenarios" {
        BeforeEach {
            Initialize-FactionSystem | Out-Null
        }
        
        It "Should create a typical Corporation setup" {
            $corp = New-Faction `
                -FactionId 'nexus_corp' `
                -Name 'Nexus Corporation' `
                -Type 'Corporation' `
                -Leader 'CEO Amanda Chen' `
                -LeaderTitle 'CEO' `
                -Headquarters 'nexus_tower' `
                -ControlledTerritories @('financial_district', 'tech_campus') `
                -Colors 'Blue & Silver' `
                -Services @('LegalGoods', 'Cyberware', 'Employment')
            
            $corp.TypeInfo.DefaultWealth | Should -Be 'Massive'
            $corp.ControlledTerritories.Count | Should -Be 2
        }
        
        It "Should create a typical Crew setup (ex-military)" {
            $crew = New-Faction `
                -FactionId 'black_ops' `
                -Name 'Black Ops Division' `
                -Type 'Crew' `
                -Leader 'Major Sarah Stone' `
                -LeaderTitle 'Commander' `
                -Specializations @('Weapons', 'Tactics', 'Infiltration') `
                -DangerLevel 'Extreme'
            
            $crew.TypeInfo.OrganizationLevel | Should -Be 'VeryHigh'
            $crew.DangerLevel | Should -Be 'Extreme'
        }
        
        It "Should create a typical Syndicate setup (organized street gang)" {
            $syndicate = New-Faction `
                -FactionId 'jade_dragons' `
                -Name 'Jade Dragons' `
                -Type 'Syndicate' `
                -Leader 'Dragon Master Lin Wei' `
                -LeaderTitle 'Dragon Master' `
                -Colors 'Green & Gold' `
                -Specializations @('Extortion', 'Gambling', 'DrugTrafficking')
            
            $syndicate.TypeInfo.OrganizationLevel | Should -Be 'High'
            $syndicate.TypeInfo.TypicalServices | Should -Contain 'BlackMarket'
        }
        
        It "Should create a typical YoungTeam setup (youth gang)" {
            $yt = New-Faction `
                -FactionId 'eastend_razors' `
                -Name 'Eastend Razors' `
                -Type 'YoungTeam' `
                -Description 'Reckless youth gang controlling the east blocks' `
                -DangerLevel 'Variable' `
                -Colors 'Red & Black' `
                -OrganizationLevel 'Low'
            
            $yt.TypeInfo.DefaultWealth | Should -Be 'Low'
            $yt.TypeInfo.Description | Should -Match 'chaotic'
        }
        
        It "Should create a typical Underground setup" {
            $underground = New-Faction `
                -FactionId 'shadow_network' `
                -Name 'Shadow Network' `
                -Type 'Underground' `
                -Services @('Intel', 'Fencing', 'SafeHouses', 'FakeIDs')
            
            $underground.TypeInfo.DefaultDanger | Should -Be 'Low'
        }
    }
    
    Describe "Reputation Spread to Rivals" {
        BeforeEach {
            Initialize-FactionSystem -Configuration @{ RivalryReputationSpread = $true; RivalrySpreadFactor = 0.5 } | Out-Null
            New-Faction -FactionId 'rival1' -Name 'Rival 1' -Type 'Syndicate' | Out-Null
            New-Faction -FactionId 'rival2' -Name 'Rival 2' -Type 'Syndicate' | Out-Null
            Set-FactionRelationship -FactionA 'rival1' -FactionB 'rival2' -Relationship 'Rival' | Out-Null
        }
        
        It "Should spread reputation to rivals when enabled" {
            $result = Add-Reputation -FactionId 'rival1' -Amount 50 -Reason 'Test'
            
            # rival2 should lose reputation (50 * 0.5 = 25)
            $rival2Rep = Get-Reputation -FactionId 'rival2'
            $rival2Rep.Reputation | Should -Be -25
        }
    }
}
