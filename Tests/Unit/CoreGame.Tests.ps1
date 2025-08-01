Describe "CoreGame Module" {
    BeforeAll {
        # Import the module
        Import-Module "..\..\Modules\CoreGame\CoreGame.psm1" -Force
    }
    
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module "..\..\Modules\CoreGame\CoreGame.psm1" -Force } | Should -Not -Throw
        }
    }
    
    Context "Initialize-CoreGame" {
        It "Should initialize successfully" {
            $result = Initialize-CoreGame
            $result.Initialized | Should -Be $true
        }
    }
    
    # Add more tests specific to this module
}
