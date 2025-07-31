# Enhanced Integration Test with CommunicationBridge
# This test validates the complete integration including CommunicationBridge

Write-Host ""
Write-Host "🚀 PowerShell Leafmap Game - ENHANCED INTEGRATION TEST" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""

# Clean start
Remove-Module CommandRegistry, CommunicationBridge, EventSystem -ErrorAction SilentlyContinue

Write-Host "1. Importing EventSystem module..." -ForegroundColor Cyan
Import-Module "./Modules/CoreGame/EventSystem.psm1" -Force
Write-Host "   ✅ EventSystem loaded" -ForegroundColor Green

Write-Host "2. Importing CommandRegistry module..." -ForegroundColor Cyan
Import-Module "./Modules/CoreGame/CommandRegistry.psm1" -Force
Write-Host "   ✅ CommandRegistry loaded" -ForegroundColor Green

Write-Host "3. Initializing CommandRegistry..." -ForegroundColor Cyan
$registry = Initialize-CommandRegistry
Write-Host "   ✅ CommandRegistry initialized" -ForegroundColor Green

Write-Host "4. Getting initial commands..." -ForegroundColor Cyan
$commands = Get-GameCommand
Write-Host "   ✅ Found $($commands.Count) initial commands:" -ForegroundColor Green
$commands | ForEach-Object { Write-Host "      - $($_.FullName)" -ForegroundColor White }

Write-Host "5. Importing CommunicationBridge module..." -ForegroundColor Cyan
Import-Module "./Modules/CoreGame/CommunicationBridge.psm1" -Force
Write-Host "   ✅ CommunicationBridge module loaded" -ForegroundColor Green

Write-Host "6. Initializing CommunicationBridge..." -ForegroundColor Cyan
try {
    $bridgeResult = Initialize-CommunicationBridge @{
        HttpServerEnabled = $false  # Disable HTTP server for testing
        WebSocketEnabled = $false   # Disable WebSocket for testing
        FileBasedEnabled = $true    # Keep file-based for testing
    }
    Write-Host "   ✅ CommunicationBridge initialized successfully" -ForegroundColor Green
    Write-Host "   📊 CommandRegistry Available: $($bridgeResult.CommandRegistryAvailable)" -ForegroundColor White
} catch {
    Write-Host "   ❌ CommunicationBridge initialization failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "7. Checking commands after bridge initialization..." -ForegroundColor Cyan
try {
    $allCommands = Get-GameCommand
    Write-Host "   ✅ Found $($allCommands.Count) total commands:" -ForegroundColor Green
    $allCommands | ForEach-Object { Write-Host "      - $($_.FullName)" -ForegroundColor White }

    # Test if bridge commands were added
    $bridgeCommands = $allCommands | Where-Object { $_.Module -eq "bridge" }
    if ($bridgeCommands) {
        Write-Host "   📊 Bridge commands registered: $($bridgeCommands.Count)" -ForegroundColor Cyan
        $bridgeCommands | ForEach-Object { Write-Host "      - $($_.FullName)" -ForegroundColor Yellow }
    }
} catch {
    Write-Host "   ❌ Failed to get commands: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "8. Testing command execution through bridge..." -ForegroundColor Cyan
try {
    $result = Invoke-GameCommand -CommandName "registry.listCommands"
    Write-Host "   ✅ Command executed successfully: $($result.Success)" -ForegroundColor Green
    Write-Host "   📊 Listed $($result.Data.TotalCount) available commands" -ForegroundColor White
} catch {
    Write-Host "   ❌ Command execution failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "9. Testing bridge statistics..." -ForegroundColor Cyan
try {
    $bridgeStats = Get-BridgeStatistics
    Write-Host "   ✅ Bridge statistics retrieved" -ForegroundColor Green
    if ($bridgeStats -and $bridgeStats.MessagesProcessed -is [int]) {
        Write-Host "   📊 Messages processed: $($bridgeStats.MessagesProcessed)" -ForegroundColor White
        Write-Host "   📊 Commands executed: $($bridgeStats.CommandsExecuted)" -ForegroundColor White
    }
} catch {
    Write-Host "   ❌ Bridge statistics failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "10. Testing event system integration..." -ForegroundColor Cyan
try {
    if (Get-Command -Name "Send-GameEvent" -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType "test.integration" -Data @{ TestValue = "BridgeIntegration" }
        Write-Host "   ✅ Event sent successfully" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ Send-GameEvent function not available in current scope" -ForegroundColor Yellow
        Write-Host "   ℹ️ EventSystem module may need scope adjustment for global function access" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Event sending failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 ENHANCED INTEGRATION TEST RESULTS:" -ForegroundColor Magenta
Write-Host "=====================================" -ForegroundColor Magenta

# Check if all modules are working
$registryWorking = $false
$bridgeWorking = $false
$eventWorking = $false

try {
    $commands = Get-GameCommand
    $registryWorking = $commands.Count -gt 0
} catch { }

try {
    $bridgeStats = Get-BridgeStatistics
    $bridgeWorking = $null -ne $bridgeStats
} catch { }

try {
    if (Get-Command -Name "Send-GameEvent" -ErrorAction SilentlyContinue) {
        Send-GameEvent -EventType "test.final" -Data @{ Test = "Final" }
        $eventWorking = $true
    } else {
        $eventWorking = $false
    }
} catch {
    $eventWorking = $false
}

if ($registryWorking) {
    Write-Host "✅ CommandRegistry: WORKING" -ForegroundColor Green
} else {
    Write-Host "❌ CommandRegistry: FAILED" -ForegroundColor Red
}

if ($eventWorking) {
    Write-Host "✅ EventSystem: WORKING" -ForegroundColor Green
} else {
    Write-Host "❌ EventSystem: FAILED" -ForegroundColor Red
}

if ($bridgeWorking) {
    Write-Host "✅ CommunicationBridge: WORKING" -ForegroundColor Green
} else {
    Write-Host "❌ CommunicationBridge: FAILED" -ForegroundColor Red
}

Write-Host ""
if ($registryWorking -and $eventWorking -and $bridgeWorking) {
    Write-Host "🎉 ALL MODULES INTEGRATED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "🚀 READY TO COMMIT FULL INTEGRATION!" -ForegroundColor Green
} else {
    Write-Host "⚠️ SOME INTEGRATION ISSUES REMAIN" -ForegroundColor Yellow
    Write-Host "📋 Check individual module status above" -ForegroundColor Cyan
}
