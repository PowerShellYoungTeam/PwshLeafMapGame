# Full Integration Test Runner
# Runs all tests: Module tests first, then HTTP integration tests

param(
    [switch]$Detailed,
    [switch]$StopOnFailure,
    [switch]$SkipModuleTests,
    [switch]$SkipHTTPTests
)

$ErrorActionPreference = 'Continue'

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║     PowerShell Leafmap Game - Full Integration Tests         ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$startTime = Get-Date

# Track overall results
$overallResults = @{
    ModuleTests  = $null
    HTTPTests    = $null
    TotalPassed  = 0
    TotalFailed  = 0
    TotalSkipped = 0
    StartTime    = $startTime
}

# Change to project root
Push-Location $projectRoot

try {
    # Check for Pester
    $pesterModule = Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge '5.0.0' }
    if (-not $pesterModule) {
        Write-Host "Installing Pester 5.x..." -ForegroundColor Yellow
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck
    }
    Import-Module Pester -MinimumVersion 5.0.0 -Force

    #────────────────────────────────────────────────────────────────
    # Phase 1: Module Tests (No HTTP required)
    #────────────────────────────────────────────────────────────────
    if (-not $SkipModuleTests) {
        Write-Host "`n┌────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host "│  Phase 1: Independent Module Tests     │" -ForegroundColor Yellow
        Write-Host "└────────────────────────────────────────┘" -ForegroundColor Yellow

        # Find module test files (exclude HTTP tests)
        $moduleTestFiles = Get-ChildItem -Path "$projectRoot\Tests" -Filter "*.Tests.ps1" |
        Where-Object { $_.Name -ne 'HTTP-Bridge.Tests.ps1' }

        if ($moduleTestFiles.Count -gt 0) {
            Write-Host "Found $($moduleTestFiles.Count) module test file(s)" -ForegroundColor Gray

            $configuration = New-PesterConfiguration
            $configuration.Run.Path = $moduleTestFiles.FullName
            $configuration.Run.Exit = $false
            $configuration.Run.PassThru = $true
            $configuration.Output.Verbosity = if ($Detailed) { 'Detailed' } else { 'Normal' }

            $moduleResults = Invoke-Pester -Configuration $configuration

            # Handle different Pester result object formats
            $modPassed = if ($moduleResults.PassedCount) { $moduleResults.PassedCount }
            elseif ($moduleResults.Passed) { $moduleResults.Passed.Count }
            else { 0 }
            $modFailed = if ($moduleResults.FailedCount) { $moduleResults.FailedCount }
            elseif ($moduleResults.Failed) { $moduleResults.Failed.Count }
            else { 0 }
            $modSkipped = if ($moduleResults.SkippedCount) { $moduleResults.SkippedCount }
            elseif ($moduleResults.Skipped) { $moduleResults.Skipped.Count }
            else { 0 }

            $overallResults.ModuleTests = @{
                Passed   = $modPassed
                Failed   = $modFailed
                Skipped  = $modSkipped
                Duration = $moduleResults.Duration
            }

            $overallResults.TotalPassed += $modPassed
            $overallResults.TotalFailed += $modFailed
            $overallResults.TotalSkipped += $modSkipped

            if ($StopOnFailure -and $moduleResults.FailedCount -gt 0) {
                Write-Host "`n❌ Module tests failed. Stopping due to -StopOnFailure flag." -ForegroundColor Red
                return $overallResults
            }
        }
        else {
            Write-Host "No module test files found" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`n⏭️  Skipping module tests (--SkipModuleTests)" -ForegroundColor Yellow
    }

    #────────────────────────────────────────────────────────────────
    # Phase 2: HTTP Bridge Integration Tests
    #────────────────────────────────────────────────────────────────
    if (-not $SkipHTTPTests) {
        Write-Host "`n┌────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host "│  Phase 2: HTTP Bridge Integration      │" -ForegroundColor Yellow
        Write-Host "└────────────────────────────────────────┘" -ForegroundColor Yellow

        $httpTestFile = Join-Path $projectRoot "Tests\HTTP-Bridge.Tests.ps1"

        if (Test-Path $httpTestFile) {
            Write-Host "Running HTTP bridge tests..." -ForegroundColor Gray
            Write-Host "Note: This will start a test server on port 18082" -ForegroundColor Gray

            $configuration = New-PesterConfiguration
            $configuration.Run.Path = $httpTestFile
            $configuration.Run.Exit = $false
            $configuration.Run.PassThru = $true
            $configuration.Output.Verbosity = if ($Detailed) { 'Detailed' } else { 'Normal' }

            $httpResults = Invoke-Pester -Configuration $configuration

            # Handle different Pester result object formats
            $httpPassed = if ($httpResults.PassedCount) { $httpResults.PassedCount }
            elseif ($httpResults.Passed) { $httpResults.Passed.Count }
            else { 0 }
            $httpFailed = if ($httpResults.FailedCount) { $httpResults.FailedCount }
            elseif ($httpResults.Failed) { $httpResults.Failed.Count }
            else { 0 }
            $httpSkipped = if ($httpResults.SkippedCount) { $httpResults.SkippedCount }
            elseif ($httpResults.Skipped) { $httpResults.Skipped.Count }
            else { 0 }

            $overallResults.HTTPTests = @{
                Passed   = $httpPassed
                Failed   = $httpFailed
                Skipped  = $httpSkipped
                Duration = $httpResults.Duration
            }

            $overallResults.TotalPassed += $httpPassed
            $overallResults.TotalFailed += $httpFailed
            $overallResults.TotalSkipped += $httpSkipped
        }
        else {
            Write-Host "HTTP test file not found: $httpTestFile" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`n⏭️  Skipping HTTP tests (--SkipHTTPTests)" -ForegroundColor Yellow
    }

    #────────────────────────────────────────────────────────────────
    # Final Summary
    #────────────────────────────────────────────────────────────────
    $endTime = Get-Date
    $totalDuration = $endTime - $startTime

    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                    TEST RESULTS SUMMARY                      ║
╠══════════════════════════════════════════════════════════════╣
"@ -ForegroundColor Cyan

    # Module test results
    if ($overallResults.ModuleTests) {
        $m = $overallResults.ModuleTests
        $moduleStatus = if ($m.Failed -eq 0) { "✓ PASS" } else { "✗ FAIL" }
        $moduleColor = if ($m.Failed -eq 0) { "Green" } else { "Red" }
        Write-Host "║  Module Tests:    $moduleStatus" -ForegroundColor $moduleColor -NoNewline
        Write-Host "  ($($m.Passed) passed, $($m.Failed) failed)" -ForegroundColor Gray
    }
    else {
        Write-Host "║  Module Tests:    ○ SKIPPED" -ForegroundColor Yellow
    }

    # HTTP test results
    if ($overallResults.HTTPTests) {
        $h = $overallResults.HTTPTests
        $httpStatus = if ($h.Failed -eq 0) { "✓ PASS" } else { "✗ FAIL" }
        $httpColor = if ($h.Failed -eq 0) { "Green" } else { "Red" }
        Write-Host "║  HTTP Tests:      $httpStatus" -ForegroundColor $httpColor -NoNewline
        Write-Host "  ($($h.Passed) passed, $($h.Failed) failed)" -ForegroundColor Gray
    }
    else {
        Write-Host "║  HTTP Tests:      ○ SKIPPED" -ForegroundColor Yellow
    }

    Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan

    # Totals
    $totalTests = $overallResults.TotalPassed + $overallResults.TotalFailed + $overallResults.TotalSkipped
    $passColor = if ($overallResults.TotalPassed -gt 0) { "Green" } else { "Gray" }
    $failColor = if ($overallResults.TotalFailed -gt 0) { "Red" } else { "Gray" }

    Write-Host "║  Total Passed:    $($overallResults.TotalPassed)" -ForegroundColor $passColor
    Write-Host "║  Total Failed:    $($overallResults.TotalFailed)" -ForegroundColor $failColor
    Write-Host "║  Total Skipped:   $($overallResults.TotalSkipped)" -ForegroundColor Yellow
    Write-Host "║  Total Tests:     $totalTests" -ForegroundColor White
    Write-Host "║  Duration:        $([math]::Round($totalDuration.TotalSeconds, 2))s" -ForegroundColor Gray
    Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan

    $overallStatus = if ($overallResults.TotalFailed -eq 0) {
        "✓ ALL TESTS PASSED"
    }
    else {
        "✗ SOME TESTS FAILED"
    }
    $overallColor = if ($overallResults.TotalFailed -eq 0) { "Green" } else { "Red" }

    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║              $overallStatus" -ForegroundColor $overallColor -NoNewline
    $padding = " " * (45 - $overallStatus.Length)
    Write-Host "$padding║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # Return results
    $overallResults.EndTime = $endTime
    $overallResults.TotalDuration = $totalDuration
    $overallResults.Success = $overallResults.TotalFailed -eq 0

    return $overallResults

}
finally {
    Pop-Location
}
