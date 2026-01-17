Describe "CharacterSystem Module" {
    BeforeAll {
        # Import CoreGame first (dependency)
        $CorePath = Join-Path $PSScriptRoot "..\..\Modules\CoreGame\CoreGame.psd1"
        Import-Module $CorePath -Force -Global
        # Import CharacterSystem
        $ModulePath = Join-Path $PSScriptRoot "..\..\Modules\CharacterSystem\CharacterSystem.psd1"
        Import-Module $ModulePath -Force
    }
    
    Context "Module Loading" {
        It "Should import without errors" {
            $ModulePath = Join-Path $PSScriptRoot "..\..\Modules\CharacterSystem\CharacterSystem.psd1"
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }
    }
    
    Context "Initialize-CharacterSystem" {
        It "Should initialize successfully" {
            $result = Initialize-CharacterSystem
            $result.Initialized | Should -Be $true
        }
    }
    
    # Full tests are in Tests/CharacterSystem.Tests.ps1
}
