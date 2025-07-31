# Final Integration Test - Direct Module Testing
# This script directly tests the modules without function scoping issues

Write-Host ""
Write-Host "🚀 PowerShell Leafmap Game - Final Integration Test" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""

$TestResults = @{ Passed = 0; Failed = 0; Messages = @() }

function Log-Test {
    param([string]$Message, [string]$Type = "Info")
    $color = switch ($Type) {
        "Success" { "Green" }
        "Error" { "Red" }
        "Warning" { "Yellow" }
        default { "White" }
    }
    Write-Host $Message -ForegroundColor $color
    $script:TestResults.Messages += "$Type`: $Message"
}

function Test-Integration {
    try {
        Log-Test "🔧 Importing CommandRegistry module..." "Info"
        Import-Module "./Modules/CoreGame/CommandRegistry.psm1" -Force
        Log-Test "✅ CommandRegistry imported successfully" "Success"
        $script:TestResults.Passed++

        Log-Test "🔧 Importing CommunicationBridge module..." "Info"
        Import-Module "./Modules/CoreGame/CommunicationBridge.psm1" -Force
        Log-Test "✅ CommunicationBridge imported successfully" "Success"
        $script:TestResults.Passed++

        Log-Test "🔧 Testing function availability..." "Info"
        $initCmd = Get-Command Initialize-CommandRegistry -ErrorAction SilentlyContinue
        $getCmd = Get-Command Get-GameCommand -ErrorAction SilentlyContinue
        $bridgeCmd = Get-Command Initialize-CommunicationBridge -ErrorAction SilentlyContinue

        if ($initCmd -and $getCmd -and $bridgeCmd) {
            Log-Test "✅ All required functions are available" "Success"
            $script:TestResults.Passed++
        } else {
            Log-Test "❌ Some functions are missing" "Error"
            $script:TestResults.Failed++
            return $false
        }

        Log-Test "🔧 Initializing CommandRegistry..." "Info"
        $registry = & $initCmd
        if ($registry) {
            Log-Test "✅ CommandRegistry initialized successfully" "Success"
            $script:TestResults.Passed++
        } else {
            Log-Test "❌ CommandRegistry initialization failed" "Error"
            $script:TestResults.Failed++
            return $false
        }

        Log-Test "🔧 Getting built-in commands..." "Info"
        $commands = & $getCmd
        if ($commands -and $commands.Count -eq 3) {
            Log-Test "✅ Built-in commands loaded ($($commands.Count) commands)" "Success"
            $script:TestResults.Passed++

            foreach ($cmd in $commands) {
                Log-Test "  📝 $($cmd.FullName) - $($cmd.Description)" "Info"
            }
        } else {
            Log-Test "❌ Built-in commands check failed (Expected 3, got $($commands.Count))" "Error"
            $script:TestResults.Failed++
        }

        Log-Test "🔧 Initializing CommunicationBridge..." "Info"
        $bridge = & $bridgeCmd
        if ($bridge) {
            Log-Test "✅ CommunicationBridge initialized successfully" "Success"
            $script:TestResults.Passed++
        } else {
            Log-Test "❌ CommunicationBridge initialization failed" "Error"
            $script:TestResults.Failed++
            return $false
        }

        Log-Test "🔧 Checking total commands after bridge integration..." "Info"
        $allCommands = & $getCmd
        if ($allCommands -and $allCommands.Count -ge 6) {
            Log-Test "✅ Bridge integration successful ($($allCommands.Count) total commands)" "Success"
            $script:TestResults.Passed++

            $bridgeCommands = $allCommands | Where-Object { $_.Module -eq "bridge" }
            $registryCommands = $allCommands | Where-Object { $_.Module -eq "registry" }
            Log-Test "  📊 Registry commands: $($registryCommands.Count)" "Info"
            Log-Test "  📊 Bridge commands: $($bridgeCommands.Count)" "Info"
        } else {
            Log-Test "❌ Bridge integration check failed (Expected ≥6, got $($allCommands.Count))" "Error"
            $script:TestResults.Failed++
        }

        Log-Test "🔧 Testing command execution..." "Info"
        $invokeCmd = Get-Command Invoke-GameCommand -ErrorAction SilentlyContinue
        if ($invokeCmd) {
            $result = & $invokeCmd -CommandName "registry.listCommands"
            if ($result -and $result.Success) {
                Log-Test "✅ Command execution successful" "Success"
                Log-Test "  📊 Listed $($result.Data.TotalCount) available commands" "Info"
                $script:TestResults.Passed++
            } else {
                Log-Test "❌ Command execution failed: $($result.Error)" "Error"
                $script:TestResults.Failed++
            }
        } else {
            Log-Test "❌ Invoke-GameCommand not available" "Error"
            $script:TestResults.Failed++
        }

        Log-Test "🔧 Testing bridge statistics..." "Info"
        $bridgeStatsCmd = Get-Command Get-BridgeStatistics -ErrorAction SilentlyContinue
        if ($bridgeStatsCmd) {
            $bridgeStats = & $bridgeStatsCmd
            if ($bridgeStats) {
                Log-Test "✅ Bridge statistics retrieved successfully" "Success"
                $script:TestResults.Passed++
            } else {
                Log-Test "❌ Bridge statistics retrieval failed" "Error"
                $script:TestResults.Failed++
            }
        } else {
            Log-Test "❌ Get-BridgeStatistics not available" "Error"
            $script:TestResults.Failed++
        }

        return $true

    } catch {
        Log-Test "💥 Critical error during integration test: $($_.Exception.Message)" "Error"
        $script:TestResults.Failed++
        return $false
    }
}

# Run the integration test
$testSuccess = Test-Integration

Write-Host ""
Write-Host "📊 FINAL TEST RESULTS" -ForegroundColor Magenta
Write-Host "=====================" -ForegroundColor Magenta
Write-Host "✅ Tests Passed: $($TestResults.Passed)" -ForegroundColor Green
Write-Host "❌ Tests Failed: $($TestResults.Failed)" -ForegroundColor Red
Write-Host ""

if ($TestResults.Failed -eq 0 -and $TestResults.Passed -gt 0) {
    Write-Host "🎉 ALL INTEGRATION TESTS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 SYSTEM STATUS SUMMARY:" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host "✅ CommandRegistry Module: Fully functional" -ForegroundColor Green
    Write-Host "✅ CommunicationBridge Module: Fully functional" -ForegroundColor Green
    Write-Host "✅ Module Integration: Complete" -ForegroundColor Green
    Write-Host "✅ Command Execution: Working" -ForegroundColor Green
    Write-Host "✅ Bridge Communication: Active" -ForegroundColor Green
    Write-Host ""
    Write-Host "🚀 SYSTEM IS READY FOR COMMIT! 🚀" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔗 Demo available at: Tests\CommandRegistry-Demo.html" -ForegroundColor Cyan
    Write-Host "🧪 Test suite available at: Tests\Integration\CommandRegistry-Integration.Tests.ps1" -ForegroundColor Cyan

    exit 0
} else {
    Write-Host "❌ INTEGRATION TESTS FAILED" -ForegroundColor Red
    Write-Host "Please review the errors above before committing." -ForegroundColor Yellow
    exit 1
}
