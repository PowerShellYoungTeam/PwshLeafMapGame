Describe 'Parent' {
    BeforeEach {
        Write-Host 'Parent BeforeEach'
    }
    
    Describe 'Child' {
        BeforeEach {
            Write-Host 'Child BeforeEach'
        }
        
        It 'Test 1' { Write-Host 'Test 1'; $true | Should -BeTrue }
        It 'Test 2' { Write-Host 'Test 2'; $true | Should -BeTrue }
    }
}
