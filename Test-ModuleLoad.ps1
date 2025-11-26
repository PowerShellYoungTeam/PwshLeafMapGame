# Quick test of module loading
$ModulesPath = 'S:\AI-Game-Dev\PwshLeafMapGame\Modules\CoreGame'
Push-Location $ModulesPath

Write-Host "Loading GameLogging..." -ForegroundColor Yellow
Import-Module .\GameLogging.psm1 -Force -Global
Write-Host "  Loaded. Checking for Initialize-GameLogging..." -ForegroundColor Gray
$cmd = Get-Command Initialize-GameLogging -ErrorAction SilentlyContinue
if ($cmd) {
    Write-Host "  ✓ Found: $($cmd.Name) from $($cmd.Source)" -ForegroundColor Green
} else {
    Write-Host "  ✗ NOT FOUND" -ForegroundColor Red
}

Pop-Location
