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
        # Note: Full Initialize-GameEngine testing is in Tests/Basic.Tests.ps1
        # This unit test requires proper working directory for EventSystem
        It "Should have Initialize-GameEngine function available" {
            Get-Command Initialize-GameEngine -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    # Add more tests specific to this module
}
