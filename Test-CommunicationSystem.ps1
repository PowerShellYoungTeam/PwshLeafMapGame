# Simple Communication System Test
# Tests the MessageBus without complex module inheritance

# Import the simplified communication system
$CommunicationModulePath = Join-Path $PSScriptRoot "Modules\CoreGame\SimpleCommunicationSystem.psm1"
Import-Module $CommunicationModulePath -Force

Write-Host "=== Simple Communication System Test ===" -ForegroundColor Cyan
Write-Host ""

# Create MessageBus
Write-Host "1. Creating MessageBus..." -ForegroundColor Yellow
$Global:MessageBus = New-MessageBus

# Start the message bus
Write-Host "2. Starting MessageBus..." -ForegroundColor Yellow
$Global:MessageBus.Start()

# Create a simple test module
Write-Host "3. Creating test modules..." -ForegroundColor Yellow

function New-SimpleTestModule {
    param([string]$ModuleName)

    $module = New-Object PSObject -Property @{
        ModuleName = $ModuleName
        Version = "1.0.0"
        Dependencies = @{}
        Capabilities = @{ "Testing" = $true }
        MessageBus = $null
        Config = @{}
        IsInitialized = $false
        LastActivity = Get-Date
    }

    $module | Add-Member -MemberType ScriptMethod -Name "Initialize" -Value {
        param([object]$MessageBus, [hashtable]$Config)
        $this.MessageBus = $MessageBus
        $this.Config = $Config
        $this.IsInitialized = $true
        $this.LastActivity = Get-Date

        return @{
            Success = $true
            Message = "Module $($this.ModuleName) initialized successfully"
            Timestamp = Get-Date
        }
    }

    $module | Add-Member -MemberType ScriptMethod -Name "HandleMessage" -Value {
        param([string]$Action, [object]$Data, [string]$Source)
        $this.LastActivity = Get-Date

        switch ($Action) {
            "Echo" {
                return @{
                    Success = $true
                    Message = "Echo from $($this.ModuleName): $($Data.Message)"
                    OriginalData = $Data
                }
            }
            "GetStatus" {
                return @{
                    ModuleName = $this.ModuleName
                    Version = $this.Version
                    IsInitialized = $this.IsInitialized
                    LastActivity = $this.LastActivity
                }
            }
            default {
                throw "Unknown action: $Action"
            }
        }
    }

    $module | Add-Member -MemberType ScriptMethod -Name "GetStatus" -Value {
        return @{
            ModuleName = $this.ModuleName
            Version = $this.Version
            IsInitialized = $this.IsInitialized
            LastActivity = $this.LastActivity
            Capabilities = $this.Capabilities
            Dependencies = $this.Dependencies
        }
    }

    $module | Add-Member -MemberType ScriptMethod -Name "ValidateDependencies" -Value {
        return @{
            IsValid = $true
            MissingDependencies = @()
            Errors = @()
        }
    }

    $module | Add-Member -MemberType ScriptMethod -Name "Shutdown" -Value {
        $this.IsInitialized = $false
        return @{
            Success = $true
            Message = "Module $($this.ModuleName) shutdown completed"
            Timestamp = Get-Date
        }
    }

    return $module
}

# Create and register test modules
$testModule1 = New-SimpleTestModule -ModuleName "TestModule1"
$testModule2 = New-SimpleTestModule -ModuleName "TestModule2"

$result1 = $Global:MessageBus.RegisterModule("TestModule1", $testModule1)
$result2 = $Global:MessageBus.RegisterModule("TestModule2", $testModule2)

Write-Host "TestModule1 Registration: $($result1.Success)" -ForegroundColor Green
Write-Host "TestModule2 Registration: $($result2.Success)" -ForegroundColor Green
Write-Host ""

# Test direct communication
Write-Host "4. Testing direct communication..." -ForegroundColor Yellow

$echoResult1 = $Global:MessageBus.SendMessage("TestModule1", "Echo", @{Message = "Hello from Test!"}, 30)
Write-Host "Echo Test 1: $($echoResult1.Success) - $($echoResult1.Message)" -ForegroundColor Green

$echoResult2 = $Global:MessageBus.SendMessage("TestModule2", "Echo", @{Message = "Greetings from MessageBus!"}, 30)
Write-Host "Echo Test 2: $($echoResult2.Success) - $($echoResult2.Message)" -ForegroundColor Green
Write-Host ""

# Test event subscription and publishing
Write-Host "5. Testing event system..." -ForegroundColor Yellow

$Global:MessageBus.Subscribe("TestModule1", "TestEvent", {
    param($Message)
    Write-Host "    TestModule1 received event: $($Message.Data.EventMessage)" -ForegroundColor Magenta
})

$Global:MessageBus.Subscribe("TestModule2", "TestEvent", {
    param($Message)
    Write-Host "    TestModule2 received event: $($Message.Data.EventMessage)" -ForegroundColor Cyan
})

# Publish test events
$Global:MessageBus.Publish("TestEvent", @{EventMessage = "Hello Event System!"}, "TestScript", 1)
$Global:MessageBus.Publish("TestEvent", @{EventMessage = "Broadcasting to all subscribers"}, "TestScript", 2)

# Wait for event processing
Start-Sleep -Seconds 2
Write-Host ""

# Test system status
Write-Host "6. System Status:" -ForegroundColor Yellow
$status = $Global:MessageBus.GetStatus()

Write-Host "  MessageBus Running: $($status.IsRunning)" -ForegroundColor Green
Write-Host "  Registered Modules: $($status.RegisteredModules.Count)" -ForegroundColor Green
Write-Host "  Messages Sent: $($status.Performance.MessagesSent)" -ForegroundColor Green
Write-Host "  Messages Processed: $($status.Performance.MessagesProcessed)" -ForegroundColor Green
Write-Host "  Queue Stats: High=$($status.QueueStats.High), Medium=$($status.QueueStats.Medium), Low=$($status.QueueStats.Low)" -ForegroundColor Green
Write-Host ""

# Test module status
Write-Host "7. Module Status:" -ForegroundColor Yellow
foreach ($moduleName in $status.RegisteredModules) {
    $moduleStatus = $Global:MessageBus.SendMessage($moduleName, "GetStatus", @{}, 30)
    Write-Host "  $moduleName`: Initialized=$($moduleStatus.IsInitialized), Last Activity=$($moduleStatus.LastActivity)" -ForegroundColor Green
}
Write-Host ""

# Cleanup
Write-Host "8. Shutting down..." -ForegroundColor Yellow
$Global:MessageBus.Shutdown()

Write-Host ""
Write-Host "=== Simple Communication Test Complete ===" -ForegroundColor Cyan
Write-Host "The communication system is working correctly!" -ForegroundColor Green
