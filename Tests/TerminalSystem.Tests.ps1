# TerminalSystem.Tests.ps1
# Comprehensive tests for the TerminalSystem module

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '..\Modules\TerminalSystem\TerminalSystem.psm1'
    Import-Module $modulePath -Force
}

AfterAll {
    # Clean up
    Remove-Module TerminalSystem -ErrorAction SilentlyContinue
}

Describe 'TerminalSystem Module' {
    
    Describe 'Initialize-TerminalSystem' {
        
        It 'Should initialize with default configuration' {
            $result = Initialize-TerminalSystem
            
            $result.Initialized | Should -Be $true
            $result.ModuleName | Should -Be 'TerminalSystem'
            $result.Configuration | Should -Not -BeNullOrEmpty
            $result.Configuration.BaseHackSuccessRate | Should -Be 30
            $result.Configuration.IntelligenceBonus | Should -Be 3
        }
        
        It 'Should accept custom configuration' {
            $config = @{
                BaseHackSuccessRate = 50
                IntelligenceBonus = 5
            }
            
            $result = Initialize-TerminalSystem -Configuration $config
            
            $result.Configuration.BaseHackSuccessRate | Should -Be 50
            $result.Configuration.IntelligenceBonus | Should -Be 5
        }
        
        It 'Should expose terminal types' {
            $result = Initialize-TerminalSystem
            
            $result.TerminalTypes | Should -Contain 'PublicTerminal'
            $result.TerminalTypes | Should -Contain 'CorporateTerminal'
            $result.TerminalTypes | Should -Contain 'SecurityTerminal'
            $result.TerminalTypes | Should -Contain 'DataServer'
            $result.TerminalTypes | Should -Contain 'BankTerminal'
            $result.TerminalTypes | Should -Contain 'MilitaryTerminal'
            $result.TerminalTypes | Should -Contain 'AICore'
        }
        
        It 'Should expose ICE types' {
            $result = Initialize-TerminalSystem
            
            $result.ICETypes | Should -Contain 'Firewall'
            $result.ICETypes | Should -Contain 'Tracer'
            $result.ICETypes | Should -Contain 'Killer'
            $result.ICETypes | Should -Contain 'BlackICE'
        }
        
        It 'Should expose hacking programs' {
            $result = Initialize-TerminalSystem
            
            $result.HackingPrograms | Should -Contain 'BasicDecrypt'
            $result.HackingPrograms | Should -Contain 'Probe'
            $result.HackingPrograms | Should -Contain 'ICEBreaker'
        }
    }
    
    Describe 'Terminal Management' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
        }
        
        Context 'New-Terminal' {
            
            It 'Should create a terminal with required parameters' {
                $terminal = New-Terminal -TerminalId 'term1' -Name 'Test Terminal' -Type 'PublicTerminal'
                
                $terminal.TerminalId | Should -Be 'term1'
                $terminal.Name | Should -Be 'Test Terminal'
                $terminal.Type | Should -Be 'PublicTerminal'
                $terminal.IsActive | Should -Be $true
            }
            
            It 'Should set default security level based on type' {
                $public = New-Terminal -TerminalId 'public1' -Name 'Public' -Type 'PublicTerminal'
                $corporate = New-Terminal -TerminalId 'corp1' -Name 'Corporate' -Type 'CorporateTerminal'
                $military = New-Terminal -TerminalId 'mil1' -Name 'Military' -Type 'MilitaryTerminal'
                
                $public.SecurityLevel | Should -Be 1
                $corporate.SecurityLevel | Should -Be 3
                $military.SecurityLevel | Should -Be 6
            }
            
            It 'Should set default ICE based on type' {
                $security = New-Terminal -TerminalId 'sec1' -Name 'Security' -Type 'SecurityTerminal'
                
                $security.ICE | Should -Contain 'Firewall'
                $security.ICE | Should -Contain 'Tracer'
                $security.ICE | Should -Contain 'Killer'
            }
            
            It 'Should allow custom security level' {
                $terminal = New-Terminal -TerminalId 'custom1' -Name 'Custom' -Type 'PublicTerminal' -SecurityLevel 5
                
                $terminal.SecurityLevel | Should -Be 5
            }
            
            It 'Should allow custom ICE' {
                $terminal = New-Terminal -TerminalId 'custom2' -Name 'Custom' -Type 'PublicTerminal' -ICE @('BlackICE', 'Sentinel')
                
                $terminal.ICE | Should -Contain 'BlackICE'
                $terminal.ICE | Should -Contain 'Sentinel'
            }
            
            It 'Should set location and faction' {
                $terminal = New-Terminal -TerminalId 'loc1' -Name 'Located' -Type 'CorporateTerminal' `
                    -LocationId 'office1' -FactionId 'megacorp'
                
                $terminal.LocationId | Should -Be 'office1'
                $terminal.FactionId | Should -Be 'megacorp'
            }
            
            It 'Should throw on duplicate terminal ID' {
                New-Terminal -TerminalId 'dup1' -Name 'First' -Type 'PublicTerminal'
                
                { New-Terminal -TerminalId 'dup1' -Name 'Second' -Type 'PublicTerminal' } | Should -Throw
            }
            
            It 'Should throw when not initialized' {
                # Re-import to reset state
                Remove-Module TerminalSystem -Force
                Import-Module $modulePath -Force
                
                { New-Terminal -TerminalId 'test' -Name 'Test' -Type 'PublicTerminal' } | Should -Throw
            }
        }
        
        Context 'Get-Terminal' {
            
            BeforeEach {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'get1' -Name 'Terminal 1' -Type 'PublicTerminal' -LocationId 'loc1' | Out-Null
                New-Terminal -TerminalId 'get2' -Name 'Terminal 2' -Type 'CorporateTerminal' -LocationId 'loc1' -FactionId 'corp1' | Out-Null
                New-Terminal -TerminalId 'get3' -Name 'Terminal 3' -Type 'CorporateTerminal' -LocationId 'loc2' -FactionId 'corp1' -IsActive $false | Out-Null
            }
            
            It 'Should get terminal by ID' {
                $terminal = Get-Terminal -TerminalId 'get1'
                
                $terminal.Name | Should -Be 'Terminal 1'
            }
            
            It 'Should return null for non-existent ID' {
                $terminal = Get-Terminal -TerminalId 'nonexistent'
                
                $terminal | Should -BeNullOrEmpty
            }
            
            It 'Should get terminals by location' {
                $terminals = Get-Terminal -LocationId 'loc1'
                
                $terminals.Count | Should -Be 2
            }
            
            It 'Should get terminals by type' {
                $terminals = Get-Terminal -Type 'CorporateTerminal'
                
                $terminals.Count | Should -Be 2
            }
            
            It 'Should get terminals by faction' {
                $terminals = Get-Terminal -FactionId 'corp1'
                
                $terminals.Count | Should -Be 2
            }
            
            It 'Should filter active only' {
                $terminals = Get-Terminal -ActiveOnly
                
                $terminals.Count | Should -Be 2
                $terminals | ForEach-Object { $_.IsActive | Should -Be $true }
            }
            
            It 'Should combine filters' {
                $terminals = Get-Terminal -Type 'CorporateTerminal' -ActiveOnly
                
                $terminals.Count | Should -Be 1
                $terminals[0].TerminalId | Should -Be 'get2'
            }
        }
        
        Context 'Set-TerminalActive' {
            
            BeforeEach {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'active1' -Name 'Test' -Type 'PublicTerminal' | Out-Null
            }
            
            It 'Should deactivate terminal' {
                $result = Set-TerminalActive -TerminalId 'active1' -Active $false
                $terminal = Get-Terminal -TerminalId 'active1'
                
                $result | Should -Be $true
                $terminal.IsActive | Should -Be $false
            }
            
            It 'Should activate terminal' {
                Set-TerminalActive -TerminalId 'active1' -Active $false | Out-Null
                $result = Set-TerminalActive -TerminalId 'active1' -Active $true
                $terminal = Get-Terminal -TerminalId 'active1'
                
                $result | Should -Be $true
                $terminal.IsActive | Should -Be $true
            }
            
            It 'Should return false for non-existent terminal' {
                $result = Set-TerminalActive -TerminalId 'nonexistent' -Active $false
                
                $result | Should -Be $false
            }
        }
        
        Context 'Remove-Terminal' {
            
            BeforeEach {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'remove1' -Name 'Test' -Type 'PublicTerminal' | Out-Null
            }
            
            It 'Should remove terminal' {
                $result = Remove-Terminal -TerminalId 'remove1'
                $terminal = Get-Terminal -TerminalId 'remove1'
                
                $result | Should -Be $true
                $terminal | Should -BeNullOrEmpty
            }
            
            It 'Should return false for non-existent terminal' {
                $result = Remove-Terminal -TerminalId 'nonexistent'
                
                $result | Should -Be $false
            }
        }
    }
    
    Describe 'Network Management' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
        }
        
        Context 'New-Network' {
            
            It 'Should create a network' {
                $network = New-Network -NetworkId 'net1' -Name 'Corporate Network'
                
                $network.NetworkId | Should -Be 'net1'
                $network.Name | Should -Be 'Corporate Network'
                $network.IsOnline | Should -Be $true
            }
            
            It 'Should set security level' {
                $network = New-Network -NetworkId 'net2' -Name 'Secure Network' -SecurityLevel 5
                
                $network.SecurityLevel | Should -Be 5
            }
            
            It 'Should throw on duplicate ID' {
                New-Network -NetworkId 'dup' -Name 'First' | Out-Null
                
                { New-Network -NetworkId 'dup' -Name 'Second' } | Should -Throw
            }
        }
        
        Context 'Get-Network' {
            
            BeforeEach {
                New-Network -NetworkId 'gn1' -Name 'Network 1' -FactionId 'corp1' | Out-Null
                New-Network -NetworkId 'gn2' -Name 'Network 2' -FactionId 'corp1' | Out-Null
                New-Network -NetworkId 'gn3' -Name 'Network 3' -FactionId 'corp2' | Out-Null
            }
            
            It 'Should get network by ID' {
                $network = Get-Network -NetworkId 'gn1'
                
                $network.Name | Should -Be 'Network 1'
            }
            
            It 'Should get networks by faction' {
                $networks = Get-Network -FactionId 'corp1'
                
                $networks.Count | Should -Be 2
            }
        }
        
        Context 'Add-TerminalToNetwork' {
            
            BeforeEach {
                New-Network -NetworkId 'addnet' -Name 'Test Network' | Out-Null
                New-Terminal -TerminalId 'addterm' -Name 'Test Terminal' -Type 'CorporateTerminal' | Out-Null
            }
            
            It 'Should add terminal to network' {
                $result = Add-TerminalToNetwork -NetworkId 'addnet' -TerminalId 'addterm'
                $network = Get-Network -NetworkId 'addnet'
                
                $result | Should -Be $true
                $network.ConnectedTerminals | Should -Contain 'addterm'
            }
            
            It 'Should not duplicate terminal in network' {
                Add-TerminalToNetwork -NetworkId 'addnet' -TerminalId 'addterm' | Out-Null
                Add-TerminalToNetwork -NetworkId 'addnet' -TerminalId 'addterm' | Out-Null
                $network = Get-Network -NetworkId 'addnet'
                
                ($network.ConnectedTerminals | Where-Object { $_ -eq 'addterm' }).Count | Should -Be 1
            }
            
            It 'Should throw for non-existent network' {
                { Add-TerminalToNetwork -NetworkId 'nonexistent' -TerminalId 'addterm' } | Should -Throw
            }
            
            It 'Should throw for non-existent terminal' {
                { Add-TerminalToNetwork -NetworkId 'addnet' -TerminalId 'nonexistent' } | Should -Throw
            }
        }
        
        Context 'Remove-TerminalFromNetwork' {
            
            BeforeEach {
                New-Network -NetworkId 'remnet' -Name 'Test Network' -ConnectedTerminals @('term1', 'term2') | Out-Null
            }
            
            It 'Should remove terminal from network' {
                $result = Remove-TerminalFromNetwork -NetworkId 'remnet' -TerminalId 'term1'
                $network = Get-Network -NetworkId 'remnet'
                
                $result | Should -Be $true
                $network.ConnectedTerminals | Should -Not -Contain 'term1'
                $network.ConnectedTerminals | Should -Contain 'term2'
            }
            
            It 'Should return false for non-existent network' {
                $result = Remove-TerminalFromNetwork -NetworkId 'nonexistent' -TerminalId 'term1'
                
                $result | Should -Be $false
            }
        }
    }
    
    Describe 'Hacking System' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
            New-Terminal -TerminalId 'hack1' -Name 'Public Terminal' -Type 'PublicTerminal' | Out-Null
            New-Terminal -TerminalId 'hack2' -Name 'Corporate Terminal' -Type 'CorporateTerminal' | Out-Null
            New-Terminal -TerminalId 'hack3' -Name 'Military Terminal' -Type 'MilitaryTerminal' | Out-Null
        }
        
        Context 'Get-HackChance' {
            
            It 'Should calculate base chance from difficulty' {
                $publicChance = Get-HackChance -TerminalId 'hack1'
                $corpChance = Get-HackChance -TerminalId 'hack2'
                
                # Public is VeryEasy (90 base), Corporate is Medium (60 base)
                $publicChance.BaseChance | Should -Be 90
                $corpChance.BaseChance | Should -Be 60
            }
            
            It 'Should add intelligence bonus' {
                $normalInt = Get-HackChance -TerminalId 'hack1' -Intelligence 10
                $highInt = Get-HackChance -TerminalId 'hack1' -Intelligence 15
                
                $highInt.IntelligenceBonus | Should -BeGreaterThan $normalInt.IntelligenceBonus
            }
            
            It 'Should add skill bonus' {
                $noSkill = Get-HackChance -TerminalId 'hack1' -HackingSkill 0
                $skilled = Get-HackChance -TerminalId 'hack1' -HackingSkill 3
                
                $skilled.SkillBonus | Should -BeGreaterThan $noSkill.SkillBonus
            }
            
            It 'Should apply security penalty' {
                $publicChance = Get-HackChance -TerminalId 'hack1'
                $militaryChance = Get-HackChance -TerminalId 'hack3'
                
                $militaryChance.SecurityPenalty | Should -BeGreaterThan $publicChance.SecurityPenalty
            }
            
            It 'Should apply ICE penalty' {
                $corpChance = Get-HackChance -TerminalId 'hack2'
                
                $corpChance.ICEPenalty | Should -BeGreaterThan 0
            }
            
            It 'Should clamp between 5 and 95' {
                # With very high skill, should cap at 95
                $highChance = Get-HackChance -TerminalId 'hack1' -Intelligence 20 -HackingSkill 10
                # Military with no skill should have low but not below 5
                $lowChance = Get-HackChance -TerminalId 'hack3' -Intelligence 5 -HackingSkill 0
                
                $highChance.TotalChance | Should -BeLessOrEqual 95
                $lowChance.TotalChance | Should -BeGreaterOrEqual 5
            }
        }
        
        Context 'Start-Hack' {
            
            It 'Should return success or failure' {
                $result = Start-Hack -TerminalId 'hack1' -Intelligence 15 -HackingSkill 3
                
                $result.Success | Should -BeIn @($true, $false)
                $result.TerminalId | Should -Be 'hack1'
                $result.Roll | Should -BeGreaterOrEqual 1
                $result.Roll | Should -BeLessOrEqual 100
            }
            
            It 'Should fail on offline terminal' {
                Set-TerminalActive -TerminalId 'hack1' -Active $false | Out-Null
                
                $result = Start-Hack -TerminalId 'hack1'
                
                $result.Success | Should -Be $false
                $result.Reason | Should -Be 'Terminal is offline'
            }
            
            It 'Should mark terminal as compromised on success' {
                # Use very easy terminal with high stats to ensure success
                New-Terminal -TerminalId 'easyHack' -Name 'Easy' -Type 'PublicTerminal' -SecurityLevel 0 -ICE @() | Out-Null
                
                # Run multiple times to ensure at least one success
                $success = $false
                for ($i = 0; $i -lt 20; $i++) {
                    Initialize-TerminalSystem | Out-Null
                    New-Terminal -TerminalId 'easyHack' -Name 'Easy' -Type 'PublicTerminal' -SecurityLevel 0 -ICE @() | Out-Null
                    $result = Start-Hack -TerminalId 'easyHack' -Intelligence 20 -HackingSkill 5
                    if ($result.Success) {
                        $terminal = Get-Terminal -TerminalId 'easyHack'
                        $terminal.Compromised | Should -Be $true
                        $success = $true
                        break
                    }
                }
                
                $success | Should -Be $true -Because "At least one hack should succeed with 95% chance"
            }
            
            It 'Should record hack in history' {
                Start-Hack -TerminalId 'hack1' | Out-Null
                
                $history = Get-HackHistory -TerminalId 'hack1'
                $history.Count | Should -BeGreaterOrEqual 1
            }
            
            It 'Should award XP on success' {
                # Multiple attempts to ensure success
                for ($i = 0; $i -lt 10; $i++) {
                    Initialize-TerminalSystem | Out-Null
                    New-Terminal -TerminalId 'xpHack' -Name 'XP Test' -Type 'PublicTerminal' | Out-Null
                    $result = Start-Hack -TerminalId 'xpHack' -Intelligence 20 -HackingSkill 5
                    if ($result.Success) {
                        $result.XPEarned | Should -BeGreaterThan 0
                        break
                    }
                }
            }
        }
        
        Context 'Invoke-DataTheft' {
            
            BeforeEach {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'dataterm' -Name 'Data Terminal' -Type 'CorporateTerminal' | Out-Null
                # Force compromise
                $terminal = Get-Terminal -TerminalId 'dataterm'
                $terminal.Compromised = $true
            }
            
            It 'Should fail if terminal not compromised' {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'locked' -Name 'Locked' -Type 'CorporateTerminal' | Out-Null
                
                $result = Invoke-DataTheft -TerminalId 'locked'
                
                $result.Success | Should -Be $false
                $result.Reason | Should -Be 'Terminal not compromised - hack first'
            }
            
            It 'Should steal data from compromised terminal' {
                $result = Invoke-DataTheft -TerminalId 'dataterm' -All
                
                $result.Success | Should -Be $true
                $result.StolenData.Count | Should -BeGreaterOrEqual 1
            }
            
            It 'Should steal specific data type' {
                $result = Invoke-DataTheft -TerminalId 'dataterm' -DataType 'EmployeeData'
                
                $result.Success | Should -Be $true
                $result.StolenData | Where-Object { $_.DataType -eq 'EmployeeData' } | Should -Not -BeNullOrEmpty
            }
            
            It 'Should calculate data value' {
                $result = Invoke-DataTheft -TerminalId 'dataterm' -All
                
                $result.TotalDataValue | Should -BeGreaterOrEqual 0
            }
        }
        
        Context 'Invoke-TerminalAction' {
            
            BeforeEach {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'actionterm' -Name 'Action Terminal' -Type 'SecurityTerminal' | Out-Null
                $terminal = Get-Terminal -TerminalId 'actionterm'
                $terminal.Compromised = $true
            }
            
            It 'Should fail if not compromised' {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'noaction' -Name 'No Action' -Type 'SecurityTerminal' | Out-Null
                
                $result = Invoke-TerminalAction -TerminalId 'noaction' -Action 'DisableAlarms'
                
                $result.Success | Should -Be $false
            }
            
            It 'Should disable alarms' {
                $result = Invoke-TerminalAction -TerminalId 'actionterm' -Action 'DisableAlarms'
                
                $result.Success | Should -Be $true
                $result.Duration | Should -BeGreaterThan 0
            }
            
            It 'Should open doors' {
                $result = Invoke-TerminalAction -TerminalId 'actionterm' -Action 'OpenDoors'
                
                $result.Success | Should -Be $true
            }
            
            It 'Should disable cameras' {
                $result = Invoke-TerminalAction -TerminalId 'actionterm' -Action 'DisableCameras'
                
                $result.Success | Should -Be $true
            }
            
            It 'Should control turrets on security terminal' {
                $result = Invoke-TerminalAction -TerminalId 'actionterm' -Action 'ControlTurrets'
                
                $result.Success | Should -Be $true
            }
            
            It 'Should not control turrets on public terminal' {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'pubaction' -Name 'Public' -Type 'PublicTerminal' | Out-Null
                $terminal = Get-Terminal -TerminalId 'pubaction'
                $terminal.Compromised = $true
                
                $result = Invoke-TerminalAction -TerminalId 'pubaction' -Action 'ControlTurrets'
                
                $result.Success | Should -Be $false
            }
            
            It 'Should plant backdoor' {
                $result = Invoke-TerminalAction -TerminalId 'actionterm' -Action 'PlantBackdoor'
                $terminal = Get-Terminal -TerminalId 'actionterm'
                
                $result.Success | Should -Be $true
                $terminal.Backdoor | Should -Be $true
            }
            
            It 'Should wipe access log' {
                $terminal = Get-Terminal -TerminalId 'actionterm'
                $terminal.AccessLog.Add(@{ Test = $true }) | Out-Null
                
                $result = Invoke-TerminalAction -TerminalId 'actionterm' -Action 'WipeAccessLog'
                
                $result.Success | Should -Be $true
                $terminal.AccessLog.Count | Should -Be 0
            }
            
            It 'Should overload system' {
                $result = Invoke-TerminalAction -TerminalId 'actionterm' -Action 'OverloadSystem'
                $terminal = Get-Terminal -TerminalId 'actionterm'
                
                $result.Success | Should -Be $true
                $terminal.IsActive | Should -Be $false
            }
        }
    }
    
    Describe 'ICE Management' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
            New-Terminal -TerminalId 'iceterm' -Name 'ICE Terminal' -Type 'SecurityTerminal' | Out-Null
        }
        
        Context 'Get-TerminalICE' {
            
            It 'Should return ICE list' {
                $ice = Get-TerminalICE -TerminalId 'iceterm'
                
                $ice.Count | Should -BeGreaterThan 0
                $ice[0].Name | Should -Not -BeNullOrEmpty
            }
            
            It 'Should include ICE details' {
                $ice = Get-TerminalICE -TerminalId 'iceterm'
                
                $ice[0].Description | Should -Not -BeNullOrEmpty
                $ice[0].Strength | Should -BeGreaterThan 0
            }
            
            It 'Should filter active only' {
                $terminal = Get-Terminal -TerminalId 'iceterm'
                $originalCount = $terminal.ActiveICE.Count
                $terminal.ActiveICE = @($terminal.ActiveICE | Select-Object -First 1)
                
                $activeIce = Get-TerminalICE -TerminalId 'iceterm' -ActiveOnly
                
                $activeIce.Count | Should -Be 1
            }
        }
        
        Context 'Invoke-ICEBypass' {
            
            It 'Should attempt to bypass ICE' {
                $result = Invoke-ICEBypass -TerminalId 'iceterm' -ICEName 'Firewall' -Intelligence 15 -HackingSkill 3
                
                $result.ICE | Should -Be 'Firewall'
                $result.Success | Should -BeIn @($true, $false)
            }
            
            It 'Should fail for non-active ICE' {
                $terminal = Get-Terminal -TerminalId 'iceterm'
                $terminal.ActiveICE = @()
                
                $result = Invoke-ICEBypass -TerminalId 'iceterm' -ICEName 'Firewall'
                
                $result.Success | Should -Be $false
                $result.Reason | Should -Be 'ICE not active on this terminal'
            }
            
            It 'Should remove ICE on success' {
                # Multiple attempts for probability
                for ($i = 0; $i -lt 20; $i++) {
                    Initialize-TerminalSystem | Out-Null
                    New-Terminal -TerminalId 'bypassterm' -Name 'Bypass Test' -Type 'CorporateTerminal' | Out-Null
                    
                    $result = Invoke-ICEBypass -TerminalId 'bypassterm' -ICEName 'Firewall' -Intelligence 20 -HackingSkill 5
                    
                    if ($result.Success) {
                        $terminal = Get-Terminal -TerminalId 'bypassterm'
                        $terminal.ActiveICE | Should -Not -Contain 'Firewall'
                        break
                    }
                }
            }
            
            It 'Should apply damage on failure' {
                Initialize-TerminalSystem | Out-Null
                New-Terminal -TerminalId 'damageterm' -Name 'Damage Test' -Type 'DataServer' | Out-Null
                
                # With low stats against hard ICE, failure is likely
                for ($i = 0; $i -lt 20; $i++) {
                    $result = Invoke-ICEBypass -TerminalId 'damageterm' -ICEName 'BlackICE' -Intelligence 5 -HackingSkill 0
                    
                    if (-not $result.Success) {
                        $result.DamageReceived | Should -BeGreaterThan 0
                        break
                    }
                }
            }
        }
        
        Context 'Reset-TerminalICE' {
            
            It 'Should reset ICE and compromised state' {
                $terminal = Get-Terminal -TerminalId 'iceterm'
                $terminal.ActiveICE = @()
                $terminal.Compromised = $true
                $terminal.Backdoor = $true
                
                $result = Reset-TerminalICE -TerminalId 'iceterm'
                
                $result | Should -Be $true
                $terminal.ActiveICE.Count | Should -Be $terminal.ICE.Count
                $terminal.Compromised | Should -Be $false
                $terminal.Backdoor | Should -Be $false
            }
            
            It 'Should return false for non-existent terminal' {
                $result = Reset-TerminalICE -TerminalId 'nonexistent'
                
                $result | Should -Be $false
            }
        }
    }
    
    Describe 'Hacking Programs' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
        }
        
        Context 'Get-HackingProgram' {
            
            It 'Should list all programs' {
                $programs = Get-HackingProgram
                
                $programs.Count | Should -BeGreaterThan 0
            }
            
            It 'Should get specific program' {
                $prog = Get-HackingProgram -ProgramName 'ICEBreaker'
                
                $prog.Name | Should -Be 'ICEBreaker'
                $prog.Effect | Should -Be 'DestroyICE'
            }
            
            It 'Should return null for unknown program' {
                $prog = Get-HackingProgram -ProgramName 'NonExistent'
                
                $prog | Should -BeNullOrEmpty
            }
            
            It 'Should filter owned programs' {
                Add-HackingProgram -ProgramName 'Probe' | Out-Null
                
                $owned = Get-HackingProgram -Owned
                
                $owned.Count | Should -Be 1
                $owned[0].Name | Should -Be 'Probe'
            }
        }
        
        Context 'Add-HackingProgram' {
            
            It 'Should add program to inventory' {
                $result = Add-HackingProgram -ProgramName 'Ghost'
                
                $result.Success | Should -Be $true
                $result.Program | Should -Be 'Ghost'
            }
            
            It 'Should fail for already owned program' {
                Add-HackingProgram -ProgramName 'Mask' | Out-Null
                
                $result = Add-HackingProgram -ProgramName 'Mask'
                
                $result.Success | Should -Be $false
                $result.Reason | Should -Be 'Program already owned'
            }
            
            It 'Should throw for unknown program' {
                { Add-HackingProgram -ProgramName 'FakeProgram' } | Should -Throw
            }
        }
        
        Context 'Remove-HackingProgram' {
            
            It 'Should remove owned program' {
                Add-HackingProgram -ProgramName 'DataVault' | Out-Null
                
                $result = Remove-HackingProgram -ProgramName 'DataVault'
                
                $result | Should -Be $true
                $prog = Get-HackingProgram -ProgramName 'DataVault'
                $prog.Owned | Should -Be $false
            }
            
            It 'Should return false for unowned program' {
                $result = Remove-HackingProgram -ProgramName 'Worm'
                
                $result | Should -Be $false
            }
        }
    }
    
    Describe 'Security Alerts' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
        }
        
        Context 'Get-SecurityAlert' {
            
            BeforeEach {
                # Create some failed hacks to generate alerts
                New-Terminal -TerminalId 'alertterm' -Name 'Alert Terminal' -Type 'MilitaryTerminal' `
                    -LocationId 'mil_base' -FactionId 'military' | Out-Null
                
                # Force detection on failure
                for ($i = 0; $i -lt 10; $i++) {
                    $result = Start-Hack -TerminalId 'alertterm' -Intelligence 5 -HackingSkill 0
                    if ($result.Detected) { break }
                }
            }
            
            It 'Should return alerts' {
                $alerts = Get-SecurityAlert
                
                # May or may not have alerts depending on detection rolls
                $alerts | Should -Not -BeNullOrEmpty -Because "Detection should occur eventually"
            }
            
            It 'Should filter by faction' {
                $alerts = Get-SecurityAlert -FactionId 'military'
                
                $alerts | ForEach-Object { $_.FactionId | Should -Be 'military' }
            }
            
            It 'Should filter by location' {
                $alerts = Get-SecurityAlert -LocationId 'mil_base'
                
                $alerts | ForEach-Object { $_.LocationId | Should -Be 'mil_base' }
            }
        }
        
        Context 'Clear-SecurityAlert' {
            
            It 'Should clear all alerts' {
                Initialize-TerminalSystem | Out-Null
                
                $result = Clear-SecurityAlert -All
                $alerts = Get-SecurityAlert
                
                $result | Should -Be $true
                $alerts.Count | Should -Be 0
            }
        }
        
        Context 'Trace Level' {
            
            It 'Should start at zero' {
                $level = Get-TraceLevel
                
                $level | Should -Be 0
            }
            
            It 'Should add trace level' {
                Add-TraceLevel -Amount 25 | Out-Null
                $level = Get-TraceLevel
                
                $level | Should -Be 25
            }
            
            It 'Should cap at 100' {
                Add-TraceLevel -Amount 150 | Out-Null
                $level = Get-TraceLevel
                
                $level | Should -Be 100
            }
            
            It 'Should reduce trace level' {
                Add-TraceLevel -Amount 50 | Out-Null
                Reduce-TraceLevel -Amount 20 | Out-Null
                $level = Get-TraceLevel
                
                $level | Should -Be 30
            }
            
            It 'Should not go below zero' {
                Reduce-TraceLevel -Amount 50 | Out-Null
                $level = Get-TraceLevel
                
                $level | Should -Be 0
            }
        }
    }
    
    Describe 'Hack History & Statistics' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
            New-Terminal -TerminalId 'histterm' -Name 'History Terminal' -Type 'PublicTerminal' | Out-Null
            
            # Generate some hack history
            for ($i = 0; $i -lt 5; $i++) {
                Start-Hack -TerminalId 'histterm' -HackerId 'player' | Out-Null
            }
        }
        
        Context 'Get-HackHistory' {
            
            It 'Should return hack history' {
                $history = Get-HackHistory
                
                $history.Count | Should -BeGreaterOrEqual 5
            }
            
            It 'Should filter by terminal' {
                $history = Get-HackHistory -TerminalId 'histterm'
                
                $history | ForEach-Object { $_.TerminalId | Should -Be 'histterm' }
            }
            
            It 'Should filter by hacker' {
                $history = Get-HackHistory -HackerId 'player'
                
                $history | ForEach-Object { $_.HackerId | Should -Be 'player' }
            }
            
            It 'Should filter successful only' {
                $history = Get-HackHistory -SuccessOnly
                
                $history | ForEach-Object { $_.Success | Should -Be $true }
            }
            
            It 'Should limit results' {
                $history = Get-HackHistory -Limit 3
                
                $history.Count | Should -BeLessOrEqual 3
            }
        }
        
        Context 'Get-HackStatistics' {
            
            It 'Should return statistics' {
                $stats = Get-HackStatistics -HackerId 'player'
                
                $stats.TotalAttempts | Should -BeGreaterOrEqual 5
                $stats.SuccessRate | Should -BeGreaterOrEqual 0
                $stats.SuccessRate | Should -BeLessOrEqual 100
            }
            
            It 'Should return zero stats for unknown hacker' {
                $stats = Get-HackStatistics -HackerId 'unknown'
                
                $stats.TotalAttempts | Should -Be 0
                $stats.SuccessRate | Should -Be 0
            }
        }
    }
    
    Describe 'State Management' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
            New-Terminal -TerminalId 'stateterm1' -Name 'State Terminal 1' -Type 'PublicTerminal' | Out-Null
            New-Terminal -TerminalId 'stateterm2' -Name 'State Terminal 2' -Type 'CorporateTerminal' | Out-Null
            New-Network -NetworkId 'statenet' -Name 'State Network' | Out-Null
            Add-HackingProgram -ProgramName 'Probe' | Out-Null
        }
        
        Context 'Get-TerminalSystemState' {
            
            It 'Should return system state' {
                $state = Get-TerminalSystemState
                
                $state.Initialized | Should -Be $true
                $state.TerminalCount | Should -Be 2
                $state.NetworkCount | Should -Be 1
                $state.OwnedPrograms | Should -Be 1
            }
            
            It 'Should count compromised terminals' {
                $terminal = Get-Terminal -TerminalId 'stateterm1'
                $terminal.Compromised = $true
                
                $state = Get-TerminalSystemState
                
                $state.CompromisedTerminals | Should -Be 1
            }
        }
        
        Context 'Export-TerminalData / Import-TerminalData' {
            
            It 'Should export and import data' {
                $exportPath = Join-Path $TestDrive 'terminal-export.json'
                
                # Export
                $exportResult = Export-TerminalData -FilePath $exportPath
                $exportResult.Success | Should -Be $true
                Test-Path $exportPath | Should -Be $true
                
                # Clear state
                Initialize-TerminalSystem | Out-Null
                $emptyState = Get-TerminalSystemState
                $emptyState.TerminalCount | Should -Be 0
                
                # Import
                $importResult = Import-TerminalData -FilePath $exportPath
                $importResult.Success | Should -Be $true
                $importResult.TerminalCount | Should -Be 2
                
                # Verify data
                $terminal = Get-Terminal -TerminalId 'stateterm1'
                $terminal | Should -Not -BeNullOrEmpty
            }
            
            It 'Should throw for non-existent file' {
                { Import-TerminalData -FilePath 'C:\nonexistent\file.json' } | Should -Throw
            }
        }
    }
    
    Describe 'Event Processing' {
        
        BeforeEach {
            Initialize-TerminalSystem | Out-Null
            New-Terminal -TerminalId 'eventterm' -Name 'Event Terminal' -Type 'PublicTerminal' -LocationId 'eventloc' | Out-Null
            Add-TraceLevel -Amount 50 | Out-Null
        }
        
        Context 'Process-TerminalEvent' {
            
            It 'Should reduce trace on time advance' {
                $results = Process-TerminalEvent -EventType 'TimeAdvanced' -EventData @{ MinutesPassed = 30 }
                
                $traceResult = $results | Where-Object { $_.Type -eq 'TraceLevelReduced' }
                $traceResult | Should -Not -BeNullOrEmpty
                
                $newLevel = Get-TraceLevel
                $newLevel | Should -BeLessThan 50
            }
            
            It 'Should detect terminals on location entered' {
                $results = Process-TerminalEvent -EventType 'LocationEntered' -EventData @{ LocationId = 'eventloc' }
                
                $termResult = $results | Where-Object { $_.Type -eq 'TerminalsAvailable' }
                $termResult | Should -Not -BeNullOrEmpty
                $termResult.Count | Should -Be 1
            }
            
            It 'Should reset terminal on mission complete' {
                $terminal = Get-Terminal -TerminalId 'eventterm'
                $terminal.Compromised = $true
                
                Process-TerminalEvent -EventType 'MissionComplete' -EventData @{ TerminalId = 'eventterm' }
                
                $terminal.Compromised | Should -Be $false
            }
        }
    }
    
    Describe 'Integration Tests' {
        
        It 'Should complete full hacking workflow' {
            # Initialize
            Initialize-TerminalSystem | Out-Null
            
            # Create terminal
            $terminal = New-Terminal -TerminalId 'workflow' -Name 'Workflow Terminal' -Type 'CorporateTerminal' `
                -LocationId 'corp_office' -FactionId 'megacorp'
            $terminal | Should -Not -BeNullOrEmpty
            
            # Check hack chance
            $chance = Get-HackChance -TerminalId 'workflow' -Intelligence 14 -HackingSkill 2
            $chance.TotalChance | Should -BeGreaterThan 0
            
            # Attempt hack (may succeed or fail)
            $hackResult = Start-Hack -TerminalId 'workflow' -Intelligence 14 -HackingSkill 2
            $hackResult.TerminalId | Should -Be 'workflow'
            
            # If successful, perform actions
            if ($hackResult.Success) {
                # Steal data
                $dataResult = Invoke-DataTheft -TerminalId 'workflow' -All
                $dataResult.Success | Should -Be $true
                
                # Plant backdoor
                $backdoorResult = Invoke-TerminalAction -TerminalId 'workflow' -Action 'PlantBackdoor'
                $backdoorResult.Success | Should -Be $true
                
                # Verify backdoor bonus
                $newChance = Get-HackChance -TerminalId 'workflow' -Intelligence 14 -HackingSkill 2
                $newChance.BackdoorBonus | Should -BeGreaterThan 0
            }
            
            # Check statistics
            $stats = Get-HackStatistics -HackerId 'player'
            $stats.TotalAttempts | Should -BeGreaterOrEqual 1
        }
        
        It 'Should handle network with multiple terminals' {
            Initialize-TerminalSystem | Out-Null
            
            # Create network
            $network = New-Network -NetworkId 'corpnet' -Name 'Corporate Network' -FactionId 'megacorp'
            
            # Create and link terminals
            New-Terminal -TerminalId 'corpterm1' -Name 'Lobby Terminal' -Type 'PublicTerminal' | Out-Null
            New-Terminal -TerminalId 'corpterm2' -Name 'Server Room' -Type 'DataServer' | Out-Null
            New-Terminal -TerminalId 'corpterm3' -Name 'Security Station' -Type 'SecurityTerminal' | Out-Null
            
            Add-TerminalToNetwork -NetworkId 'corpnet' -TerminalId 'corpterm1' | Out-Null
            Add-TerminalToNetwork -NetworkId 'corpnet' -TerminalId 'corpterm2' | Out-Null
            Add-TerminalToNetwork -NetworkId 'corpnet' -TerminalId 'corpterm3' | Out-Null
            
            $network = Get-Network -NetworkId 'corpnet'
            $network.ConnectedTerminals.Count | Should -Be 3
            
            # State check
            $state = Get-TerminalSystemState
            $state.TerminalCount | Should -Be 3
            $state.NetworkCount | Should -Be 1
        }
        
        It 'Should manage programs and use in hacking' {
            Initialize-TerminalSystem | Out-Null
            
            # Acquire programs
            Add-HackingProgram -ProgramName 'Probe' | Out-Null
            Add-HackingProgram -ProgramName 'ICEBreaker' | Out-Null
            Add-HackingProgram -ProgramName 'Ghost' | Out-Null
            
            $owned = Get-HackingProgram -Owned
            $owned.Count | Should -Be 3
            
            # Create hard terminal
            New-Terminal -TerminalId 'hardterm' -Name 'Hard Terminal' -Type 'DataServer' | Out-Null
            
            # Check chance with and without programs
            $baseChance = Get-HackChance -TerminalId 'hardterm' -Intelligence 12 -HackingSkill 1
            $progChance = Get-HackChance -TerminalId 'hardterm' -Intelligence 12 -HackingSkill 1 `
                -ActivePrograms @('ICEBreaker', 'Ghost')
            
            $progChance.ProgramBonus | Should -BeGreaterThan $baseChance.ProgramBonus
        }
    }
}
