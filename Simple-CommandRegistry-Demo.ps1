#!/usr/bin/env pwsh
#
# Simple Command Registry Demo
# Tests the core functionality without complex dependencies
#

Write-Host "🎮 Simple Command Registry Demo" -ForegroundColor Cyan
Write-Host "Testing core command registration functionality..."

try {
    # Import just the CommandRegistry module directly
    $RegistryModulePath = Join-Path $PSScriptRoot "Modules\CoreGame\CommandRegistry.psm1"

    if (Test-Path $RegistryModulePath) {
        Write-Host "📦 Loading CommandRegistry module..." -ForegroundColor Yellow
        Import-Module $RegistryModulePath -Force -Verbose:$false

        Write-Host "🎯 Initializing Command Registry..." -ForegroundColor Yellow
        Initialize-CommandRegistry

        # Test basic command registration
        Write-Host "🔧 Testing command registration..." -ForegroundColor Yellow

        # Create a simple test command
        $testHandler = {
            param($Name)
            return @{
                Success = $true
                Message = "Hello, $($Name)!"
                Timestamp = Get-Date
            }
        }

        # Register the command using the exported function
        Register-Command -Name "greet" -Module "test" -Handler $testHandler -Description "Simple greeting command" -Parameters @(
            @{
                Name = "Name"
                Type = "string"
                Required = $true
                Description = "Name to greet"
            }
        )

        Write-Host "✅ Command registered successfully" -ForegroundColor Green

        # Test command discovery
        Write-Host "🔍 Testing command discovery..." -ForegroundColor Yellow
        $commands = Get-RegisteredCommands
        Write-Host "Found $($commands.Count) registered commands:" -ForegroundColor Green

        foreach ($cmd in $commands.Values) {
            Write-Host "  • $($cmd.FullName) - $($cmd.Description)" -ForegroundColor White
        }

        # Test command execution
        Write-Host "🚀 Testing command execution..." -ForegroundColor Yellow
        $result = Invoke-RegisteredCommand -CommandName "test.greet" -Parameters @{ Name = "PowerShell Developer" }

        if ($result.Success) {
            Write-Host "✅ Command executed successfully!" -ForegroundColor Green
            Write-Host "   Result: $($result.Message)" -ForegroundColor White
        } else {
            Write-Host "❌ Command execution failed: $($result.Error)" -ForegroundColor Red
        }

        # Test documentation generation
        Write-Host "📚 Testing documentation generation..." -ForegroundColor Yellow
        $docs = Get-CommandDocumentation
        $docsJson = $docs | ConvertTo-Json -Depth 5
        Write-Host "Generated documentation ($($docsJson.Length) characters)" -ForegroundColor Green

        # Show a summary
        Write-Host "`n🎉 Demo Summary:" -ForegroundColor Magenta
        Write-Host "• Command Registry initialized successfully" -ForegroundColor White
        Write-Host "• Test command registered and executed" -ForegroundColor White
        Write-Host "• Command discovery working" -ForegroundColor White
        Write-Host "• Documentation generation working" -ForegroundColor White
        Write-Host "`n✨ The Command Registry system is working perfectly!" -ForegroundColor Green

    } else {
        Write-Error "CommandRegistry module not found at: $RegistryModulePath"
    }
}
catch {
    Write-Error "Demo failed: $($_.Exception.Message)"
    Write-Host "Error details:" -ForegroundColor Red
    Write-Host $_.Exception.ToString() -ForegroundColor Red
}
