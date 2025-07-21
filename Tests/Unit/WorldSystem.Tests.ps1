Describe "WorldSystem Module" {
    BeforeAll {
        # Import the module
        Import-Module "..\..\Modules\WorldSystem\WorldSystem.psm1" -Force
    }
    
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module "..\..\Modules\WorldSystem\WorldSystem.psm1" -Force } | Should -Not -Throw
        }
    }
    
    Context "Initialize-WorldSystem" {
        It "Should initialize successfully" {
            $result = Initialize-WorldSystem
            $result.Initialized | Should -Be $true
        }
    }
    
    # Add more tests specific to this module
}
