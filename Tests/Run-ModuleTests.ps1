# Run all independent module tests using Pester
# Tests PowerShell modules without requiring HTTP servers

param(
    [switch]$Detailed,
    [switch]$CodeCoverage,
    [string]$TestFilter = "*"
)

$ErrorActionPreference = 'Continue'

Write-Host "🧪 PowerShell Leafmap Game - Module Tests" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

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

    # Find all test files
    $testPath = Join-Path $projectRoot "Tests"
    $testFiles = Get-ChildItem -Path $testPath -Filter "*.Tests.ps1" -Recurse |
                 Where-Object { $_.Name -like "$TestFilter.Tests.ps1" -or $TestFilter -eq "*" }

    if ($testFiles.Count -eq 0) {
        Write-Warning "No test files found matching filter: $TestFilter"
        exit 1
    }

    Write-Host "`n📁 Found $($testFiles.Count) test file(s):" -ForegroundColor Yellow
    $testFiles | ForEach-Object {
        Write-Host "   • $($_.Name)" -ForegroundColor White
    }

    # Configure Pester
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = $testFiles.FullName
    $configuration.Run.Exit = $false
    $configuration.Output.Verbosity = if ($Detailed) { 'Detailed' } else { 'Normal' }

    if ($CodeCoverage) {
        $moduleFiles = Get-ChildItem -Path "$projectRoot\Modules" -Filter "*.psm1" -Recurse
        $configuration.CodeCoverage.Enabled = $true
        $configuration.CodeCoverage.Path = $moduleFiles.FullName
        $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
        $configuration.CodeCoverage.OutputPath = "$projectRoot\Tests\coverage.xml"
    }

    Write-Host "`n🔬 Running tests..." -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────" -ForegroundColor Gray

    # Run tests
    $results = Invoke-Pester -Configuration $configuration

    Write-Host "`n─────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "📊 Test Results Summary" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────" -ForegroundColor Gray

    $passedColor = if ($results.PassedCount -gt 0) { 'Green' } else { 'Gray' }
    $failedColor = if ($results.FailedCount -gt 0) { 'Red' } else { 'Gray' }
    $skippedColor = if ($results.SkippedCount -gt 0) { 'Yellow' } else { 'Gray' }

    Write-Host "   ✓ Passed:  $($results.PassedCount)" -ForegroundColor $passedColor
    Write-Host "   ✗ Failed:  $($results.FailedCount)" -ForegroundColor $failedColor
    Write-Host "   ○ Skipped: $($results.SkippedCount)" -ForegroundColor $skippedColor
    Write-Host "   Total:     $($results.TotalCount)" -ForegroundColor White
    Write-Host "   Duration:  $([math]::Round($results.Duration.TotalSeconds, 2))s" -ForegroundColor Gray

    if ($CodeCoverage -and $results.CodeCoverage) {
        Write-Host "`n📈 Code Coverage" -ForegroundColor Yellow
        $coverage = $results.CodeCoverage
        $coveragePercent = if ($coverage.NumberOfCommandsAnalyzed -gt 0) {
            [math]::Round(($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100, 2)
        } else { 0 }
        Write-Host "   Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 50) { 'Yellow' } else { 'Red' })
    }

    # List failed tests if any
    if ($results.FailedCount -gt 0) {
        Write-Host "`n❌ Failed Tests:" -ForegroundColor Red
        $results.Failed | ForEach-Object {
            Write-Host "   • $($_.ExpandedPath)" -ForegroundColor Red
            if ($_.ErrorRecord) {
                Write-Host "     $($_.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
            }
        }
    }

    Write-Host "`n─────────────────────────────────────────" -ForegroundColor Gray

    # Return results for script consumption
    return @{
        Success = $results.FailedCount -eq 0
        Passed = $results.PassedCount
        Failed = $results.FailedCount
        Skipped = $results.SkippedCount
        Total = $results.TotalCount
        Duration = $results.Duration
    }

} finally {
    Pop-Location
}
