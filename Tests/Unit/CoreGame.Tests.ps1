Describe "CoreGame Module" {
    BeforeAll {
        # Import the module using proper path resolution
        $ModulePath = Join-Path $PSScriptRoot "..\..\Modules\CoreGame\CoreGame.psd1"
        Import-Module $ModulePath -Force -Global
    }
    
    Context "Module Loading" {
        It "Should import without errors" {
            $ModulePath = Join-Path $PSScriptRoot "..\..\Modules\CoreGame\CoreGame.psd1"
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }
    }
    
    Context "Initialize-GameEngine" {
        It "Should initialize successfully" {
            $result = Initialize-GameEngine
            $result.Initialized | Should -Be $true
        }
    }
    
    # Add more tests specific to this module
}
