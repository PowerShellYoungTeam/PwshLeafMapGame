Describe "CharacterSystem Module" {
    BeforeAll {
        # Import the module
        Import-Module "..\..\Modules\CharacterSystem\CharacterSystem.psm1" -Force
    }
    
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module "..\..\Modules\CharacterSystem\CharacterSystem.psm1" -Force } | Should -Not -Throw
        }
    }
    
    Context "Initialize-CharacterSystem" {
        It "Should initialize successfully" {
            $result = Initialize-CharacterSystem
            $result.Initialized | Should -Be $true
        }
    }
    
    # Add more tests specific to this module
}
