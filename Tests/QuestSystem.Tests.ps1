# QuestSystem Tests
# Comprehensive tests for the QuestSystem module

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot "..\Modules\QuestSystem\QuestSystem.psd1"
    Import-Module $ModulePath -Force -Global
}

Describe "QuestSystem Module" {
    
    Context "Module Loading" {
        It "Should import without errors" {
            $ModulePath = Join-Path $PSScriptRoot "..\Modules\QuestSystem\QuestSystem.psd1"
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $expectedFunctions = @(
                'Initialize-QuestSystem',
                'New-QuestTemplate',
                'Get-QuestTemplate',
                'Start-Quest',
                'Get-Quest',
                'Complete-Quest',
                'Fail-Quest',
                'New-QuestObjective',
                'Update-QuestObjective',
                'Get-QuestProgress',
                'Register-QuestGiver',
                'Get-AvailableQuests',
                'New-Contract'
            )
            foreach ($func in $expectedFunctions) {
                Get-Command $func -Module QuestSystem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Initialize-QuestSystem" {
        It "Should initialize with default configuration" {
            $result = Initialize-QuestSystem
            
            $result.Initialized | Should -Be $true
            $result.ModuleName | Should -Be 'QuestSystem'
            $result.Configuration | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept custom configuration" {
            $config = @{
                MaxActiveQuests = 10
                MaxTrackedQuests = 3
            }
            $result = Initialize-QuestSystem -Configuration $config
            
            $result.Configuration.MaxActiveQuests | Should -Be 10
            $result.Configuration.MaxTrackedQuests | Should -Be 3
        }
        
        It "Should expose quest types and objective types" {
            $result = Initialize-QuestSystem
            
            $result.QuestTypes | Should -Not -BeNullOrEmpty
            $result.ObjectiveTypes | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "New-QuestTemplate" {
        BeforeEach {
            Initialize-QuestSystem
        }
        
        It "Should create a basic quest template" {
            $template = New-QuestTemplate `
                -TemplateId 'test-quest-001' `
                -Name 'Test Quest' `
                -Description 'A test quest' `
                -QuestType 'Side'
            
            $template | Should -Not -BeNullOrEmpty
            $template.TemplateId | Should -Be 'test-quest-001'
            $template.Name | Should -Be 'Test Quest'
            $template.QuestType | Should -Be 'Side'
        }
        
        It "Should set difficulty correctly" {
            $template = New-QuestTemplate `
                -TemplateId 'hard-quest' `
                -Name 'Hard Quest' `
                -Description 'A difficult quest' `
                -QuestType 'Contract' `
                -Difficulty 'Hard'
            
            $template.Difficulty | Should -Be 'Hard'
            $template.DifficultyInfo.XPMultiplier | Should -Be 1.5
        }
        
        It "Should include rewards" {
            $rewards = @{
                Experience = 500
                Credits = 1000
                Items = @('rare_item_001')
            }
            
            $template = New-QuestTemplate `
                -TemplateId 'reward-quest' `
                -Name 'Reward Quest' `
                -Description 'Quest with rewards' `
                -QuestType 'Side' `
                -Rewards $rewards
            
            $template.Rewards.Experience | Should -Be 500
            $template.Rewards.Credits | Should -Be 1000
            $template.Rewards.Items | Should -Contain 'rare_item_001'
        }
        
        It "Should support prerequisites" {
            $template = New-QuestTemplate `
                -TemplateId 'sequel-quest' `
                -Name 'Sequel Quest' `
                -Description 'Requires previous quest' `
                -QuestType 'MainStory' `
                -Prerequisites @('first-quest')
            
            $template.Prerequisites | Should -Contain 'first-quest'
        }
        
        It "Should support time limits" {
            $template = New-QuestTemplate `
                -TemplateId 'timed-quest' `
                -Name 'Timed Quest' `
                -Description 'Must complete quickly' `
                -QuestType 'Contract' `
                -TimeLimitMinutes 30
            
            $template.TimeLimitMinutes | Should -Be 30
        }
    }
    
    Context "Get-QuestTemplate" {
        BeforeEach {
            Initialize-QuestSystem
            
            New-QuestTemplate -TemplateId 'main-001' -Name 'Main Quest' -Description 'Main story' -QuestType 'MainStory'
            New-QuestTemplate -TemplateId 'side-001' -Name 'Side Quest' -Description 'Side quest' -QuestType 'Side'
            New-QuestTemplate -TemplateId 'faction-001' -Name 'Faction Quest' -Description 'Faction' -QuestType 'Faction' -FactionId 'corp-01'
        }
        
        It "Should retrieve by template ID" {
            $template = Get-QuestTemplate -TemplateId 'main-001'
            
            $template.Name | Should -Be 'Main Quest'
        }
        
        It "Should filter by quest type" {
            $templates = Get-QuestTemplate -QuestType 'Side'
            
            $templates.Count | Should -BeGreaterOrEqual 1
            $templates.Name | Should -Contain 'Side Quest'
        }
        
        It "Should filter by faction" {
            $templates = Get-QuestTemplate -FactionId 'corp-01'
            
            $templates.Count | Should -BeGreaterOrEqual 1
            $templates.Name | Should -Contain 'Faction Quest'
        }
        
        It "Should return all templates when no filter" {
            $templates = Get-QuestTemplate
            
            $templates.Count | Should -Be 3
        }
    }
    
    Context "New-QuestObjective" {
        BeforeEach {
            Initialize-QuestSystem
        }
        
        It "Should create a location objective" {
            $obj = New-QuestObjective `
                -ObjectiveId 'go-to-bar' `
                -Description 'Go to the Afterlife bar' `
                -Type 'GoToLocation' `
                -TargetId 'afterlife-bar'
            
            $obj.ObjectiveId | Should -Be 'go-to-bar'
            $obj.Type | Should -Be 'GoToLocation'
            $obj.TargetId | Should -Be 'afterlife-bar'
            $obj.IsComplete | Should -Be $false
        }
        
        It "Should create a kill objective with count" {
            $obj = New-QuestObjective `
                -ObjectiveId 'kill-gangers' `
                -Description 'Eliminate 5 gang members' `
                -Type 'KillTarget' `
                -TargetId 'ganger' `
                -RequiredCount 5
            
            $obj.RequiredCount | Should -Be 5
            $obj.CurrentCount | Should -Be 0
        }
        
        It "Should support optional objectives" {
            $obj = New-QuestObjective `
                -ObjectiveId 'bonus-stealth' `
                -Description 'Complete without being detected' `
                -Type 'Stealth' `
                -TargetId 'mission-area' `
                -IsOptional $true `
                -BonusReward @{ Credits = 500 }
            
            $obj.IsOptional | Should -Be $true
            $obj.BonusReward.Credits | Should -Be 500
        }
        
        It "Should support hidden objectives" {
            $obj = New-QuestObjective `
                -ObjectiveId 'secret-objective' `
                -Description 'Find the hidden cache' `
                -Type 'Discover' `
                -TargetId 'secret-cache' `
                -IsHidden $true
            
            $obj.IsHidden | Should -Be $true
        }
        
        It "Should support ordering" {
            $obj1 = New-QuestObjective -ObjectiveId 'step1' -Description 'First step' -Type 'TalkToNPC' -TargetId 'npc1' -OrderIndex 1
            $obj2 = New-QuestObjective -ObjectiveId 'step2' -Description 'Second step' -Type 'TalkToNPC' -TargetId 'npc2' -OrderIndex 2
            
            $obj1.OrderIndex | Should -Be 1
            $obj2.OrderIndex | Should -Be 2
        }
    }
    
    Context "Start-Quest" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj1 = New-QuestObjective -ObjectiveId 'obj1' -Description 'Objective 1' -Type 'TalkToNPC' -TargetId 'npc1'
            $obj2 = New-QuestObjective -ObjectiveId 'obj2' -Description 'Objective 2' -Type 'CollectItem' -TargetId 'item1' -RequiredCount 3
            
            New-QuestTemplate `
                -TemplateId 'test-quest' `
                -Name 'Test Quest' `
                -Description 'A test quest' `
                -QuestType 'Side' `
                -Objectives @($obj1, $obj2) `
                -Rewards @{ Experience = 100; Credits = 500 }
        }
        
        It "Should start a quest from template" {
            $result = Start-Quest -TemplateId 'test-quest'
            
            $result.Success | Should -Be $true
            $result.Quest | Should -Not -BeNullOrEmpty
            $result.Quest.Name | Should -Be 'Test Quest'
            $result.Quest.Status | Should -Be 'Active'
        }
        
        It "Should clone objectives for quest instance" {
            $result = Start-Quest -TemplateId 'test-quest'
            
            $result.Quest.Objectives.Count | Should -Be 2
            $result.Quest.Objectives['obj1'].IsComplete | Should -Be $false
        }
        
        It "Should fail if template not found" {
            $result = Start-Quest -TemplateId 'nonexistent'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'not found'
        }
        
        It "Should fail if prerequisites not met" {
            New-QuestTemplate `
                -TemplateId 'sequel' `
                -Name 'Sequel' `
                -Description 'Sequel quest' `
                -QuestType 'MainStory' `
                -Prerequisites @('first-quest')
            
            $result = Start-Quest -TemplateId 'sequel'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'Prerequisite'
        }
        
        It "Should fail if player level too low" {
            New-QuestTemplate `
                -TemplateId 'high-level' `
                -Name 'High Level Quest' `
                -Description 'Requires high level' `
                -QuestType 'Side' `
                -MinLevel 10
            
            $result = Start-Quest -TemplateId 'high-level' -PlayerLevel 5
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'level'
        }
        
        It "Should start quest directly without template" {
            $obj = New-QuestObjective -ObjectiveId 'direct-obj' -Description 'Direct objective' -Type 'TalkToNPC' -TargetId 'npc'
            
            $result = Start-Quest `
                -QuestId 'direct-quest' `
                -Name 'Direct Quest' `
                -Description 'Created directly' `
                -QuestType 'Discovery' `
                -Objectives @($obj)
            
            $result.Success | Should -Be $true
            $result.Quest.QuestId | Should -Be 'direct-quest'
        }
        
        It "Should prevent duplicate active quests" {
            Start-Quest -TemplateId 'test-quest'
            $result = Start-Quest -TemplateId 'test-quest'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'already active'
        }
    }
    
    Context "Get-Quest" {
        BeforeEach {
            Initialize-QuestSystem
            
            New-QuestTemplate -TemplateId 'q1' -Name 'Quest 1' -Description 'Quest 1' -QuestType 'Side'
            New-QuestTemplate -TemplateId 'q2' -Name 'Quest 2' -Description 'Quest 2' -QuestType 'MainStory'
            New-QuestTemplate -TemplateId 'q3' -Name 'Quest 3' -Description 'Quest 3' -QuestType 'Side' -FactionId 'faction1'
            
            Start-Quest -TemplateId 'q1'
            Start-Quest -TemplateId 'q2'
        }
        
        It "Should get quest by ID" {
            $quest = Get-Quest -QuestId 'q1'
            
            $quest.Name | Should -Be 'Quest 1'
        }
        
        It "Should get all active quests" {
            $quests = Get-Quest -Status 'Active'
            
            $quests.Count | Should -Be 2
        }
        
        It "Should filter by quest type" {
            $quests = Get-Quest -QuestType 'MainStory'
            
            $quests.Count | Should -BeGreaterOrEqual 1
            $quests.Name | Should -Contain 'Quest 2'
        }
        
        It "Should get tracked quests only" {
            # First quest auto-tracked, untrack the second
            Set-QuestTracked -QuestId 'q2' -Tracked $false
            
            $quests = Get-Quest -TrackedOnly
            
            $quests.Count | Should -BeGreaterOrEqual 1
            # q2 should not be tracked
            $quests.QuestId | Should -Not -Contain 'q2'
        }
    }
    
    Context "Update-QuestObjective" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj1 = New-QuestObjective -ObjectiveId 'kill-enemies' -Description 'Kill 3 enemies' -Type 'KillTarget' -TargetId 'enemy' -RequiredCount 3
            $obj2 = New-QuestObjective -ObjectiveId 'talk-npc' -Description 'Talk to contact' -Type 'TalkToNPC' -TargetId 'contact'
            
            New-QuestTemplate `
                -TemplateId 'progress-test' `
                -Name 'Progress Test' `
                -Description 'Test progress' `
                -QuestType 'Side' `
                -Objectives @($obj1, $obj2)
            
            Start-Quest -TemplateId 'progress-test'
        }
        
        It "Should increment objective progress" {
            $result = Update-QuestObjective -QuestId 'progress-test' -ObjectiveId 'kill-enemies'
            
            $result.Success | Should -Be $true
            $result.Objective.CurrentCount | Should -Be 1
            $result.Objective.IsComplete | Should -Be $false
        }
        
        It "Should complete objective when count reached" {
            Update-QuestObjective -QuestId 'progress-test' -ObjectiveId 'kill-enemies'
            Update-QuestObjective -QuestId 'progress-test' -ObjectiveId 'kill-enemies'
            $result = Update-QuestObjective -QuestId 'progress-test' -ObjectiveId 'kill-enemies'
            
            $result.Objective.IsComplete | Should -Be $true
        }
        
        It "Should set objective complete directly" {
            $result = Update-QuestObjective -QuestId 'progress-test' -ObjectiveId 'talk-npc' -SetComplete
            
            $result.Objective.IsComplete | Should -Be $true
        }
        
        It "Should indicate when quest is ready to complete" {
            Update-QuestObjective -QuestId 'progress-test' -ObjectiveId 'kill-enemies' -SetComplete
            $result = Update-QuestObjective -QuestId 'progress-test' -ObjectiveId 'talk-npc' -SetComplete
            
            $result.QuestReady | Should -Be $true
        }
    }
    
    Context "Get-QuestProgress" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj1 = New-QuestObjective -ObjectiveId 'obj1' -Description 'First' -Type 'TalkToNPC' -TargetId 'npc1'
            $obj2 = New-QuestObjective -ObjectiveId 'obj2' -Description 'Second' -Type 'TalkToNPC' -TargetId 'npc2'
            $obj3 = New-QuestObjective -ObjectiveId 'hidden' -Description 'Hidden' -Type 'Discover' -TargetId 'secret' -IsHidden $true
            
            New-QuestTemplate `
                -TemplateId 'progress-quest' `
                -Name 'Progress Quest' `
                -Description 'Test progress tracking' `
                -QuestType 'Side' `
                -Objectives @($obj1, $obj2, $obj3)
            
            Start-Quest -TemplateId 'progress-quest'
        }
        
        It "Should return progress percentage" {
            Update-QuestObjective -QuestId 'progress-quest' -ObjectiveId 'obj1' -SetComplete
            
            $progress = Get-QuestProgress -QuestId 'progress-quest'
            
            $progress.PercentComplete | Should -Be 50  # 1 of 2 visible objectives
            $progress.ObjectivesComplete | Should -Be 1
            $progress.ObjectivesTotal | Should -Be 2  # Hidden not counted
        }
        
        It "Should not count hidden objectives" {
            $progress = Get-QuestProgress -QuestId 'progress-quest'
            
            $progress.ObjectivesTotal | Should -Be 2
        }
    }
    
    Context "Complete-Quest" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj = New-QuestObjective -ObjectiveId 'main-obj' -Description 'Main objective' -Type 'TalkToNPC' -TargetId 'npc'
            $bonus = New-QuestObjective -ObjectiveId 'bonus-obj' -Description 'Bonus' -Type 'CollectItem' -TargetId 'item' -IsOptional $true -BonusReward @{ Credits = 200 }
            
            New-QuestTemplate `
                -TemplateId 'complete-test' `
                -Name 'Complete Test' `
                -Description 'Test completion' `
                -QuestType 'Side' `
                -Difficulty 'Hard' `
                -Objectives @($obj, $bonus) `
                -Rewards @{ Experience = 100; Credits = 500 }
            
            Start-Quest -TemplateId 'complete-test'
        }
        
        It "Should fail if objectives not complete" {
            $result = Complete-Quest -QuestId 'complete-test'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'incomplete'
        }
        
        It "Should complete when objectives done" {
            Update-QuestObjective -QuestId 'complete-test' -ObjectiveId 'main-obj' -SetComplete
            
            $result = Complete-Quest -QuestId 'complete-test'
            
            $result.Success | Should -Be $true
            $result.Quest.Status | Should -Be 'Completed'
        }
        
        It "Should apply difficulty multipliers" {
            Update-QuestObjective -QuestId 'complete-test' -ObjectiveId 'main-obj' -SetComplete
            
            $result = Complete-Quest -QuestId 'complete-test'
            
            $result.Rewards.Experience | Should -Be 150  # 100 * 1.5 (Hard)
            $result.Rewards.Credits | Should -Be 750     # 500 * 1.5 (Hard)
        }
        
        It "Should add bonus rewards for optional objectives" {
            Update-QuestObjective -QuestId 'complete-test' -ObjectiveId 'main-obj' -SetComplete
            Update-QuestObjective -QuestId 'complete-test' -ObjectiveId 'bonus-obj' -SetComplete
            
            $result = Complete-Quest -QuestId 'complete-test'
            
            $result.Rewards.Credits | Should -Be 950  # 750 + 200 bonus
        }
        
        It "Should force complete without checking objectives" {
            $result = Complete-Quest -QuestId 'complete-test' -Force
            
            $result.Success | Should -Be $true
        }
        
        It "Should move quest to completed list" {
            Update-QuestObjective -QuestId 'complete-test' -ObjectiveId 'main-obj' -SetComplete
            Complete-Quest -QuestId 'complete-test'
            
            $quest = Get-Quest -QuestId 'complete-test'
            
            $quest.Status | Should -Be 'Completed'
        }
    }
    
    Context "Fail-Quest" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj = New-QuestObjective -ObjectiveId 'obj' -Description 'Objective' -Type 'TalkToNPC' -TargetId 'npc'
            
            New-QuestTemplate `
                -TemplateId 'fail-test' `
                -Name 'Fail Test' `
                -Description 'Test failure' `
                -QuestType 'Side' `
                -Objectives @($obj) `
                -Rewards @{ Reputation = @{ 'faction1' = 100 } }
            
            Start-Quest -TemplateId 'fail-test'
        }
        
        It "Should fail a quest" {
            $result = Fail-Quest -QuestId 'fail-test' -Reason 'Player died'
            
            $result.Success | Should -Be $true
            $result.Quest.Status | Should -Be 'Failed'
            $result.Quest.FailureReason | Should -Be 'Player died'
        }
        
        It "Should calculate reputation penalties" {
            $result = Fail-Quest -QuestId 'fail-test'
            
            $result.Penalties.ReputationLoss['faction1'] | Should -Be -50  # 50% of reward
        }
        
        It "Should move quest to failed list" {
            Fail-Quest -QuestId 'fail-test'
            
            $quest = Get-Quest -QuestId 'fail-test'
            $quest.Status | Should -Be 'Failed'
        }
    }
    
    Context "Abandon-Quest" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj = New-QuestObjective -ObjectiveId 'obj' -Description 'Objective' -Type 'TalkToNPC' -TargetId 'npc'
            
            New-QuestTemplate -TemplateId 'abandonable' -Name 'Abandonable' -Description 'Can abandon' -QuestType 'Side' -Objectives @($obj)
            New-QuestTemplate -TemplateId 'main-story' -Name 'Main Story' -Description 'Cannot abandon' -QuestType 'MainStory' -Objectives @($obj)
            
            Start-Quest -TemplateId 'abandonable'
            Start-Quest -TemplateId 'main-story'
        }
        
        It "Should abandon side quests" {
            $result = Abandon-Quest -QuestId 'abandonable'
            
            $result.Success | Should -Be $true
            $result.Quest.FailureReason | Should -Be 'Abandoned'
        }
        
        It "Should not abandon main story quests" {
            $result = Abandon-Quest -QuestId 'main-story'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'cannot be abandoned'
        }
    }
    
    Context "Register-QuestGiver" {
        BeforeEach {
            Initialize-QuestSystem
            
            New-QuestTemplate -TemplateId 'fixer-quest-1' -Name 'Fixer Quest 1' -Description 'Job 1' -QuestType 'Contract'
            New-QuestTemplate -TemplateId 'fixer-quest-2' -Name 'Fixer Quest 2' -Description 'Job 2' -QuestType 'Contract'
        }
        
        It "Should register a quest giver" {
            $giver = Register-QuestGiver `
                -GiverId 'fixer-01' `
                -Name 'Dex DeShawn' `
                -Title 'Fixer' `
                -FactionId 'fixers' `
                -AvailableQuests @('fixer-quest-1', 'fixer-quest-2')
            
            $giver.GiverId | Should -Be 'fixer-01'
            $giver.Name | Should -Be 'Dex DeShawn'
            $giver.AvailableQuests.Count | Should -Be 2
        }
        
        It "Should retrieve quest giver by ID" {
            Register-QuestGiver -GiverId 'fixer-02' -Name 'Rogue' -Title 'Fixer'
            
            $giver = Get-QuestGiver -GiverId 'fixer-02'
            
            $giver.Name | Should -Be 'Rogue'
        }
        
        It "Should filter givers by faction" {
            Register-QuestGiver -GiverId 'corp-contact' -Name 'Corp Contact' -FactionId 'arasaka'
            Register-QuestGiver -GiverId 'street-fixer' -Name 'Street Fixer' -FactionId 'fixers'
            
            $givers = Get-QuestGiver -FactionId 'arasaka'
            
            $givers.Count | Should -BeGreaterOrEqual 1
            $givers.Name | Should -Contain 'Corp Contact'
        }
    }
    
    Context "Get-AvailableQuests" {
        BeforeEach {
            Initialize-QuestSystem
            
            New-QuestTemplate -TemplateId 'easy-quest' -Name 'Easy Quest' -Description 'Easy' -QuestType 'Side' -MinLevel 1
            New-QuestTemplate -TemplateId 'hard-quest' -Name 'Hard Quest' -Description 'Hard' -QuestType 'Side' -MinLevel 10
            New-QuestTemplate -TemplateId 'rep-quest' -Name 'Rep Quest' -Description 'Rep' -QuestType 'Faction' -FactionId 'faction1'
            
            Register-QuestGiver `
                -GiverId 'test-giver' `
                -Name 'Test Giver' `
                -AvailableQuests @('easy-quest', 'hard-quest', 'rep-quest')
        }
        
        It "Should return quests matching player level" {
            $quests = Get-AvailableQuests -GiverId 'test-giver' -PlayerLevel 5
            
            $quests.Count | Should -Be 2  # easy-quest and rep-quest
            $quests.Name | Should -Not -Contain 'Hard Quest'
        }
        
        It "Should not return already active quests" {
            Start-Quest -TemplateId 'easy-quest'
            
            $quests = Get-AvailableQuests -GiverId 'test-giver' -PlayerLevel 20
            
            $quests.TemplateId | Should -Not -Contain 'easy-quest'
        }
        
        It "Should not return already completed quests" {
            $obj = New-QuestObjective -ObjectiveId 'obj' -Description 'Obj' -Type 'TalkToNPC' -TargetId 'npc'
            
            # Add objective to template for completion
            $template = Get-QuestTemplate -TemplateId 'easy-quest'
            $template.Objectives = @($obj)
            
            Start-Quest -TemplateId 'easy-quest'
            Update-QuestObjective -QuestId 'easy-quest' -ObjectiveId 'obj' -SetComplete
            Complete-Quest -QuestId 'easy-quest'
            
            $quests = Get-AvailableQuests -GiverId 'test-giver' -PlayerLevel 20
            
            $quests.TemplateId | Should -Not -Contain 'easy-quest'
        }
    }
    
    Context "Quest Time Limits" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj = New-QuestObjective -ObjectiveId 'obj' -Description 'Objective' -Type 'TalkToNPC' -TargetId 'npc'
            
            New-QuestTemplate `
                -TemplateId 'timed-quest' `
                -Name 'Timed Quest' `
                -Description 'Must complete quickly' `
                -QuestType 'Contract' `
                -Objectives @($obj) `
                -TimeLimitMinutes 1
            
            Start-Quest -TemplateId 'timed-quest'
        }
        
        It "Should set time limit on quest" {
            $quest = Get-Quest -QuestId 'timed-quest'
            
            $quest.TimeLimit | Should -Not -BeNullOrEmpty
        }
        
        It "Should return time remaining" {
            $timeInfo = Get-QuestTimeRemaining -QuestId 'timed-quest'
            
            $timeInfo | Should -Not -BeNullOrEmpty
            $timeInfo.IsExpired | Should -Be $false
            $timeInfo.FormattedRemaining | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Process-QuestEvent" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj1 = New-QuestObjective -ObjectiveId 'go-bar' -Description 'Go to bar' -Type 'GoToLocation' -TargetId 'afterlife'
            $obj2 = New-QuestObjective -ObjectiveId 'kill-gangers' -Description 'Kill gangers' -Type 'KillTarget' -TargetId 'ganger' -RequiredCount 2
            
            New-QuestTemplate `
                -TemplateId 'event-quest' `
                -Name 'Event Quest' `
                -Description 'Test events' `
                -QuestType 'Side' `
                -Objectives @($obj1, $obj2)
            
            Start-Quest -TemplateId 'event-quest'
        }
        
        It "Should update objective from location event" {
            $updates = Process-QuestEvent -EventType 'PlayerArrivedAtLocation' -EventData @{ LocationId = 'afterlife' }
            
            $updates.Count | Should -BeGreaterOrEqual 1
            $matchingUpdate = $updates | Where-Object { $_.ObjectiveId -eq 'go-bar' }
            $matchingUpdate | Should -Not -BeNullOrEmpty
            $matchingUpdate.IsComplete | Should -Be $true
        }
        
        It "Should update objective from kill event" {
            Process-QuestEvent -EventType 'EnemyKilled' -EventData @{ EnemyType = 'ganger' }
            $updates = Process-QuestEvent -EventType 'EnemyKilled' -EventData @{ EnemyType = 'ganger' }
            
            $matchingUpdate = $updates | Where-Object { $_.ObjectiveId -eq 'kill-gangers' }
            $matchingUpdate | Should -Not -BeNullOrEmpty
            $matchingUpdate.IsComplete | Should -Be $true
        }
        
        It "Should not update for non-matching events" {
            $updates = Process-QuestEvent -EventType 'PlayerArrivedAtLocation' -EventData @{ LocationId = 'wrong-location' }
            
            $updates.Count | Should -Be 0
        }
    }
    
    Context "Contract System" {
        BeforeEach {
            Initialize-QuestSystem
            
            Register-QuestGiver -GiverId 'fixer-dex' -Name 'Dex' -Title 'Fixer'
        }
        
        It "Should create a contract" {
            $obj = New-QuestObjective -ObjectiveId 'retrieve-data' -Description 'Retrieve the data' -Type 'CollectItem' -TargetId 'data-chip'
            
            $contract = New-Contract `
                -ContractId 'heist-001' `
                -Name 'The Big Heist' `
                -Description 'Steal corporate data' `
                -ContractType 'DataTheft' `
                -ClientId 'fixer-dex' `
                -PaymentCredits 5000 `
                -PaymentUpfront 1000 `
                -Difficulty 'Hard' `
                -TimeLimitMinutes 60 `
                -Objectives @($obj)
            
            $contract.ContractId | Should -Be 'heist-001'
            $contract.PaymentTotal | Should -Be 5000
            $contract.PaymentUpfront | Should -Be 1000
            $contract.PaymentOnCompletion | Should -Be 4000
        }
        
        It "Should accept a contract" {
            $obj = New-QuestObjective -ObjectiveId 'obj' -Description 'Objective' -Type 'TalkToNPC' -TargetId 'target'
            
            New-Contract `
                -ContractId 'accept-test' `
                -Name 'Accept Test' `
                -Description 'Test acceptance' `
                -ClientId 'fixer-dex' `
                -PaymentCredits 1000 `
                -PaymentUpfront 200 `
                -Objectives @($obj)
            
            $result = Accept-Contract -ContractId 'accept-test'
            
            $result.Success | Should -Be $true
            $result.UpfrontPayment | Should -Be 200
            $result.Quest.QuestType | Should -Be 'Contract'
        }
    }
    
    Context "State Export/Import" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj = New-QuestObjective -ObjectiveId 'obj' -Description 'Objective' -Type 'TalkToNPC' -TargetId 'npc'
            New-QuestTemplate -TemplateId 'export-quest' -Name 'Export Quest' -Description 'For export' -QuestType 'Side' -Objectives @($obj)
            Start-Quest -TemplateId 'export-quest'
        }
        
        It "Should return system state" {
            $state = Get-QuestSystemState
            
            $state.Initialized | Should -Be $true
            $state.ActiveQuests.Count | Should -Be 1
            $state.Statistics.TotalActive | Should -Be 1
        }
        
        It "Should export quest data to file" {
            $exportPath = Join-Path $TestDrive 'quest-export.json'
            
            $result = Export-QuestData -FilePath $exportPath
            
            $result.Success | Should -Be $true
            Test-Path $exportPath | Should -Be $true
        }
        
        It "Should import quest data from file" {
            $exportPath = Join-Path $TestDrive 'quest-import.json'
            Export-QuestData -FilePath $exportPath
            
            # Reinitialize to clear state
            Initialize-QuestSystem
            
            $result = Import-QuestData -FilePath $exportPath
            
            $result.Success | Should -Be $true
            $result.ImportedActive | Should -Be 1
        }
    }
    
    Context "Ordered Objectives" {
        BeforeEach {
            Initialize-QuestSystem
            
            $obj1 = New-QuestObjective -ObjectiveId 'step1' -Description 'First step' -Type 'TalkToNPC' -TargetId 'npc1' -OrderIndex 1
            $obj2 = New-QuestObjective -ObjectiveId 'step2' -Description 'Second step' -Type 'TalkToNPC' -TargetId 'npc2' -OrderIndex 2
            $obj3 = New-QuestObjective -ObjectiveId 'anytime' -Description 'Anytime' -Type 'CollectItem' -TargetId 'item' -OrderIndex 0
            
            New-QuestTemplate `
                -TemplateId 'ordered-quest' `
                -Name 'Ordered Quest' `
                -Description 'Must do in order' `
                -QuestType 'Side' `
                -Objectives @($obj1, $obj2, $obj3)
            
            Start-Quest -TemplateId 'ordered-quest'
        }
        
        It "Should allow unordered objectives anytime" {
            $result = Update-QuestObjective -QuestId 'ordered-quest' -ObjectiveId 'anytime' -SetComplete
            
            $result.Success | Should -Be $true
        }
        
        It "Should block later ordered objectives until earlier complete" {
            $result = Update-QuestObjective -QuestId 'ordered-quest' -ObjectiveId 'step2' -SetComplete
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match 'Previous objectives'
        }
        
        It "Should allow ordered objectives in sequence" {
            Update-QuestObjective -QuestId 'ordered-quest' -ObjectiveId 'step1' -SetComplete
            $result = Update-QuestObjective -QuestId 'ordered-quest' -ObjectiveId 'step2' -SetComplete
            
            $result.Success | Should -Be $true
        }
    }
}
