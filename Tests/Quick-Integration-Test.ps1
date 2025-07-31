# Simple Integration Test for CommandRegistry and CommunicationBridge
# This script tests the core functionality to ensure everything works before commit

Write-Host ""
Write-Host "🧪 PowerShell Leafmap Game - Integration Test" -ForegroundColor Magenta
Write-Host "=============================================" -ForegroundColor Magenta
Write-Host ""

$ErrorActionPreference = "Stop"
$TestsPassed = 0
$TestsFailed = 0

function Test-Step {
    param(
        [string]$StepName,
        [scriptblock]$TestCode
    )

    try {
        Write-Host "Testing: $StepName..." -ForegroundColor Cyan -NoNewline
        $result = & $TestCode
        Write-Host " ✅ PASSED" -ForegroundColor Green
        $script:TestsPassed++
        return $result
    }
    catch {
        Write-Host " ❌ FAILED" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Yellow
        $script:TestsFailed++
        throw
    }
}

try {
    # Test 1: Import CommandRegistry
    Test-Step "CommandRegistry Import" {
        Import-Module (Join-Path $PSScriptRoot "..\Modules\CoreGame\CommandRegistry.psm1") -Force
        # Verify functions are available
        if (-not (Get-Command Initialize-CommandRegistry -ErrorAction SilentlyContinue)) {
            throw "Initialize-CommandRegistry function not available after import"
        }
        if (-not (Get-Command Get-GameCommand -ErrorAction SilentlyContinue)) {
            throw "Get-GameCommand function not available after import"
        }
        return $true
    }

    # Test 2: Import CommunicationBridge
    Test-Step "CommunicationBridge Import" {
        Import-Module (Join-Path $PSScriptRoot "..\Modules\CoreGame\CommunicationBridge.psm1") -Force
        # Verify functions are available
        if (-not (Get-Command Initialize-CommunicationBridge -ErrorAction SilentlyContinue)) {
            throw "Initialize-CommunicationBridge function not available after import"
        }
        return $true
    }

    # Test 3: Initialize CommandRegistry
    $registry = Test-Step "CommandRegistry Initialization" {
        $reg = Initialize-CommandRegistry
        if (-not $reg) { throw "Registry initialization returned null" }
        return $reg
    }

    # Test 4: Check built-in commands
    $builtInCommands = Test-Step "Built-in Commands Check" {
        $commands = Get-GameCommand
        if ($commands.Count -ne 3) {
            throw "Expected 3 built-in commands, got $($commands.Count)"
        }
        return $commands
    }

    # Test 5: Initialize CommunicationBridge
    $bridge = Test-Step "CommunicationBridge Initialization" {
        $br = Initialize-CommunicationBridge
        if (-not $br) { throw "Bridge initialization returned null" }
        return $br
    }

    # Test 6: Check total commands after bridge
    $allCommands = Test-Step "Bridge Integration Check" {
        $commands = Get-GameCommand
        if ($commands.Count -lt 6) {
            throw "Expected at least 6 commands after bridge integration, got $($commands.Count)"
        }
        return $commands
    }

    # Test 7: Execute a command
    $cmdResult = Test-Step "Command Execution" {
        $result = Invoke-GameCommand -CommandName "registry.listCommands"
        if (-not $result.Success) {
            throw "Command execution failed: $($result.Error)"
        }
        return $result
    }

    # Test 8: Get bridge statistics
    $bridgeStats = Test-Step "Bridge Statistics" {
        $stats = Get-BridgeStatistics
        if (-not $stats) { throw "Bridge statistics returned null" }
        return $stats
    }

    Write-Host ""
    Write-Host "📊 TEST SUMMARY" -ForegroundColor Magenta
    Write-Host "===============" -ForegroundColor Magenta
    Write-Host "✅ Passed: $TestsPassed" -ForegroundColor Green
    Write-Host "❌ Failed: $TestsFailed" -ForegroundColor Red
    Write-Host ""

    if ($TestsFailed -eq 0) {
        Write-Host "🎉 ALL TESTS PASSED! System is ready for commit." -ForegroundColor Green
        Write-Host ""
        Write-Host "System Status:" -ForegroundColor Cyan
        Write-Host "• CommandRegistry: ✅ Active with $($builtInCommands.Count) built-in commands" -ForegroundColor White
        Write-Host "• CommunicationBridge: ✅ Connected and operational" -ForegroundColor White
        Write-Host "• Total Commands: $($allCommands.Count)" -ForegroundColor White
        Write-Host "• Integration: ✅ Fully functional" -ForegroundColor White
        Write-Host ""
        Write-Host "Ready for production! 🚀" -ForegroundColor Green
    } else {
        Write-Host "❌ Some tests failed. Please review and fix issues before committing." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "💥 CRITICAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "❌ Integration test failed. System not ready for commit." -ForegroundColor Red
    exit 1
}

Write-Host ""
