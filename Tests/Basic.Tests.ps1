# Basic.Tests.ps1
# Core module loading and function export tests

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot "..\Modules\CoreGame\CoreGame.psd1"
    Import-Module $ModulePath -Force -DisableNameChecking
}

Describe "CoreGame Module" {
    Context "Module Loading" {
        It "Should load CoreGame module successfully" {
            Get-Module CoreGame | Should -Not -BeNullOrEmpty
        }
        
        It "Should pass manifest validation" {
            $ManifestPath = Join-Path $PSScriptRoot "..\Modules\CoreGame\CoreGame.psd1"
            { Test-ModuleManifest -Path $ManifestPath } | Should -Not -Throw
        }
        
        It "Should export Initialize-GameEngine function" {
            Get-Command Initialize-GameEngine -Module CoreGame -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export at least 40 functions across all submodules" {
            # Count functions from all CoreGame submodules loaded globally
            $subModules = @('GameLogging', 'EventSystem', 'StateManager', 'DataModels', 'PathfindingSystem', 'CommunicationBridge', 'CommandRegistry')
            $totalFunctions = 0
            foreach ($mod in $subModules) {
                $totalFunctions += (Get-Module $mod -ErrorAction SilentlyContinue).ExportedFunctions.Count
            }
            # Add CoreGame's own exported function
            $totalFunctions += (Get-Module CoreGame).ExportedFunctions.Count
            $totalFunctions | Should -BeGreaterOrEqual 40
        }
    }
    
    Context "GameLogging Functions" {
        It "Should export Initialize-GameLogging" {
            Get-Command Initialize-GameLogging -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Write-GameLog" {
            Get-Command Write-GameLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Set-LoggingConfig" {
            Get-Command Set-LoggingConfig -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "EventSystem Functions" {
        It "Should export Initialize-EventSystem" {
            Get-Command Initialize-EventSystem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Register-GameEvent" {
            Get-Command Register-GameEvent -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Send-GameEvent" {
            Get-Command Send-GameEvent -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "StateManager Functions" {
        It "Should export Initialize-StateManager" {
            Get-Command Initialize-StateManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Register-GameEntity" {
            Get-Command Register-GameEntity -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Update-GameEntityState" {
            Get-Command Update-GameEntityState -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Save-GameState" {
            Get-Command Save-GameState -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "DataModels Functions" {
        It "Should export New-PlayerEntity" {
            Get-Command New-PlayerEntity -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export New-GameEntity" {
            Get-Command New-GameEntity -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export New-NPCEntity" {
            Get-Command New-NPCEntity -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "PathfindingSystem Functions" {
        It "Should export Initialize-PathfindingSystem" {
            Get-Command Initialize-PathfindingSystem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Start-UnitMovement" {
            Get-Command Start-UnitMovement -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "CommunicationBridge Functions" {
        It "Should export Initialize-CommunicationBridge" {
            Get-Command Initialize-CommunicationBridge -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Send-BridgeCommand" {
            Get-Command Send-BridgeCommand -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "CommandRegistry Functions" {
        It "Should export Initialize-CommandRegistry" {
            Get-Command Initialize-CommandRegistry -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Register-GameCommand" {
            Get-Command Register-GameCommand -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-GameCommand" {
            Get-Command Invoke-GameCommand -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    Remove-Module CoreGame -Force -ErrorAction SilentlyContinue
}
