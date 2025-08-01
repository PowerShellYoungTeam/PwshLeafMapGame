Describe "FactionSystem Module" {
    BeforeAll {
        # Import the module
        Import-Module "..\..\Modules\FactionSystem\FactionSystem.psm1" -Force
    }
    
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module "..\..\Modules\FactionSystem\FactionSystem.psm1" -Force } | Should -Not -Throw
        }
    }
    
    Context "Initialize-FactionSystem" {
        It "Should initialize successfully" {
            $result = Initialize-FactionSystem
            $result.Initialized | Should -Be $true
        }
    }
    
    # Add more tests specific to this module
}
