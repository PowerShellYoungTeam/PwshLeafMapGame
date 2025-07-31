# CommandRegistry Integration Tests
# Comprehensive test suite for CommandRegistry and CommunicationBridge integration

param(
    [switch]$Detailed,
    [switch]$SkipCleanup
)

# Test configuration
$TestResults = @{
    Passed = 0
    Failed = 0
    Errors = @()
    Details = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Message = "",
        [object]$Details = $null
    )

    if ($Success) {
        Write-Host "✅ $TestName" -ForegroundColor Green
        $script:TestResults.Passed++
    } else {
        Write-Host "❌ $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "   $Message" -ForegroundColor Yellow
        }
        $script:TestResults.Failed++
        $script:TestResults.Errors += "$TestName`: $Message"
    }

    if ($Detailed -and $Details) {
        $script:TestResults.Details += @{
            TestName = $TestName
            Success = $Success
            Message = $Message
            Details = $Details
        }
    }
}

function Test-ModuleImport {
    Write-Host "`n=== MODULE IMPORT TESTS ===" -ForegroundColor Cyan

    try {
        # Test CommandRegistry import
        Import-Module (Join-Path $PSScriptRoot "..\..\Modules\CoreGame\CommandRegistry.psm1") -Force
        Write-TestResult "CommandRegistry Module Import" $true

        # Test CommunicationBridge import
        Import-Module (Join-Path $PSScriptRoot "..\..\Modules\CoreGame\CommunicationBridge.psm1") -Force
        Write-TestResult "CommunicationBridge Module Import" $true

    } catch {
        Write-TestResult "Module Import" $false $_.Exception.Message
        return $false
    }

    return $true
}

function Test-CommandRegistryInitialization {
    Write-Host "`n=== COMMAND REGISTRY INITIALIZATION TESTS ===" -ForegroundColor Cyan

    try {
        # Initialize CommandRegistry
        $registry = Initialize-CommandRegistry
        Write-TestResult "CommandRegistry Initialization" ($null -ne $registry)

        # Check built-in commands
        $builtInCommands = Get-GameCommand
        Write-TestResult "Built-in Commands Registration" ($builtInCommands.Count -eq 3) "Expected 3 commands, got $($builtInCommands.Count)"

        # Verify specific commands exist
        $listCmd = Get-GameCommand -CommandName "registry.listCommands"
        Write-TestResult "registry.listCommands Command" ($null -ne $listCmd)

        $docCmd = Get-GameCommand -CommandName "registry.getDocumentation"
        Write-TestResult "registry.getDocumentation Command" ($null -ne $docCmd)

        $statsCmd = Get-GameCommand -CommandName "registry.getStatistics"
        Write-TestResult "registry.getStatistics Command" ($null -ne $statsCmd)

        return $true

    } catch {
        Write-TestResult "CommandRegistry Initialization" $false $_.Exception.Message
        return $false
    }
}

function Test-CommunicationBridgeIntegration {
    Write-Host "`n=== COMMUNICATION BRIDGE INTEGRATION TESTS ===" -ForegroundColor Cyan

    try {
        # Initialize CommunicationBridge
        $bridge = Initialize-CommunicationBridge
        Write-TestResult "CommunicationBridge Initialization" ($null -ne $bridge)

        # Check total commands after bridge integration
        $allCommands = Get-GameCommand
        $expectedCommandCount = 6  # 3 registry + 3 bridge commands
        Write-TestResult "Bridge Commands Integration" ($allCommands.Count -ge $expectedCommandCount) "Expected at least $expectedCommandCount commands, got $($allCommands.Count)"

        # Verify bridge commands exist
        $bridgeCommands = $allCommands | Where-Object { $_.Module -eq "bridge" }
        Write-TestResult "Bridge Module Commands" ($bridgeCommands.Count -gt 0) "Found $($bridgeCommands.Count) bridge commands"

        return $true

    } catch {
        Write-TestResult "CommunicationBridge Integration" $false $_.Exception.Message
        return $false
    }
}

function Test-CommandExecution {
    Write-Host "`n=== COMMAND EXECUTION TESTS ===" -ForegroundColor Cyan

    try {
        # Test registry.listCommands
        $listResult = Invoke-GameCommand -CommandName "registry.listCommands"
        Write-TestResult "Execute registry.listCommands" $listResult.Success $listResult.Error

        if ($listResult.Success) {
            Write-TestResult "List Commands Data Structure" ($null -ne $listResult.Data.Commands -and $null -ne $listResult.Data.TotalCount)
            Write-TestResult "Commands Count Consistency" ($listResult.Data.TotalCount -eq $listResult.Data.Commands.Count)
        }

        # Test registry.getStatistics
        $statsResult = Invoke-GameCommand -CommandName "registry.getStatistics"
        Write-TestResult "Execute registry.getStatistics" $statsResult.Success $statsResult.Error

        if ($statsResult.Success) {
            $stats = $statsResult.Data
            Write-TestResult "Statistics Data Structure" ($null -ne $stats.TotalCommands -and $null -ne $stats.CommandsExecuted)
        }

        # Test registry.getDocumentation
        $docResult = Invoke-GameCommand -CommandName "registry.getDocumentation"
        Write-TestResult "Execute registry.getDocumentation" $docResult.Success $docResult.Error

        return $true

    } catch {
        Write-TestResult "Command Execution" $false $_.Exception.Message
        return $false
    }
}

function Test-BridgeConfiguration {
    Write-Host "`n=== BRIDGE CONFIGURATION TESTS ===" -ForegroundColor Cyan

    try {
        # Test bridge statistics
        $bridgeStats = Get-BridgeStatistics
        Write-TestResult "Bridge Statistics Retrieval" ($null -ne $bridgeStats)

        # Test bridge configuration
        $bridgeConfig = Get-BridgeConfiguration
        Write-TestResult "Bridge Configuration Retrieval" ($null -ne $bridgeConfig)

        if ($bridgeConfig) {
            Write-TestResult "Bridge HTTP Configuration" ($null -ne $bridgeConfig.HttpListener)
            Write-TestResult "Bridge State Manager" ($null -ne $bridgeConfig.StateManager)
        }

        return $true

    } catch {
        Write-TestResult "Bridge Configuration" $false $_.Exception.Message
        return $false
    }
}

function Test-ParameterValidation {
    Write-Host "`n=== PARAMETER VALIDATION TESTS ===" -ForegroundColor Cyan

    try {
        # Test command with parameters
        $listWithParams = Invoke-GameCommand -CommandName "registry.listCommands" -Parameters @{ Module = "registry" }
        Write-TestResult "Command with Valid Parameters" $listWithParams.Success

        if ($listWithParams.Success) {
            $filteredCommands = $listWithParams.Data.Commands | Where-Object { $_ -like "registry.*" }
            Write-TestResult "Parameter Filtering" ($filteredCommands.Count -eq $listWithParams.Data.TotalCount)
        }

        # Test documentation with specific command
        $specificDoc = Invoke-GameCommand -CommandName "registry.getDocumentation" -Parameters @{ CommandName = "registry.listCommands" }
        Write-TestResult "Documentation for Specific Command" $specificDoc.Success

        if ($specificDoc.Success) {
            Write-TestResult "Documentation Structure" ($null -ne $specificDoc.Data.Name -and $null -ne $specificDoc.Data.Parameters)
        }

        return $true

    } catch {
        Write-TestResult "Parameter Validation" $false $_.Exception.Message
        return $false
    }
}

function Test-ErrorHandling {
    Write-Host "`n=== ERROR HANDLING TESTS ===" -ForegroundColor Cyan

    try {
        # Test non-existent command
        try {
            $invalidResult = Invoke-GameCommand -CommandName "nonexistent.command"
            Write-TestResult "Non-existent Command Handling" $false "Should have thrown an error"
        } catch {
            Write-TestResult "Non-existent Command Error" $true "Correctly threw error: $($_.Exception.Message)"
        }

        # Test invalid parameters
        try {
            $invalidParams = Invoke-GameCommand -CommandName "registry.getDocumentation" -Parameters @{ InvalidParam = "test" }
            # This should succeed but warn about unknown parameters
            Write-TestResult "Unknown Parameter Handling" $invalidParams.Success "Handled gracefully"
        } catch {
            Write-TestResult "Unknown Parameter Error" $false $_.Exception.Message
        }

        return $true

    } catch {
        Write-TestResult "Error Handling" $false $_.Exception.Message
        return $false
    }
}

function Show-TestSummary {
    Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Magenta
    Write-Host "Passed: $($TestResults.Passed)" -ForegroundColor Green
    Write-Host "Failed: $($TestResults.Failed)" -ForegroundColor Red
    Write-Host "Total:  $($TestResults.Passed + $TestResults.Failed)" -ForegroundColor White

    if ($TestResults.Failed -gt 0) {
        Write-Host "`nFailures:" -ForegroundColor Red
        $TestResults.Errors | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
    }

    if ($Detailed -and $TestResults.Details.Count -gt 0) {
        Write-Host "`nDetailed Results:" -ForegroundColor Blue
        $TestResults.Details | ConvertTo-Json -Depth 3 | Write-Host
    }

    $successRate = [math]::Round(($TestResults.Passed / ($TestResults.Passed + $TestResults.Failed)) * 100, 2)
    Write-Host "`nSuccess Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
}

# Main test execution
Write-Host "🧪 Starting CommandRegistry Integration Tests" -ForegroundColor Magenta
Write-Host "=============================================" -ForegroundColor Magenta

$startTime = Get-Date

# Run all test suites
$moduleImportSuccess = Test-ModuleImport
if ($moduleImportSuccess) {
    $registryInitSuccess = Test-CommandRegistryInitialization
    if ($registryInitSuccess) {
        $bridgeIntegrationSuccess = Test-CommunicationBridgeIntegration
        if ($bridgeIntegrationSuccess) {
            Test-CommandExecution | Out-Null
            Test-BridgeConfiguration | Out-Null
            Test-ParameterValidation | Out-Null
            Test-ErrorHandling | Out-Null
        }
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "`nTest Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Blue
Show-TestSummary

# Return overall success
return ($TestResults.Failed -eq 0)
