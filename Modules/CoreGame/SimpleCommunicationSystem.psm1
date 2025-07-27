# Simplified Communication System
# Basic MessageBus implementation without complex concurrent collections

# Simple MessageBus class
class SimpleMessageBus {
    [hashtable]$RegisteredModules
    [hashtable]$Subscribers
    [hashtable]$Configuration
    [bool]$IsRunning
    [hashtable]$Performance

    SimpleMessageBus([hashtable]$Config = @{}) {
        $this.RegisteredModules = @{}
        $this.Subscribers = @{}
        $this.Configuration = $this.GetDefaultConfiguration() + $Config
        $this.IsRunning = $false
        $this.Performance = @{
            MessagesSent = 0
            MessagesReceived = 0
            MessagesProcessed = 0
            ErrorCount = 0
            StartTime = Get-Date
            LastActivity = Get-Date
        }
    }

    [hashtable] GetDefaultConfiguration() {
        return @{
            MaxQueueSize = 10000
            ProcessingIntervalMs = 50
            EnableBatching = $true
            BatchSize = 25
            DefaultRequestTimeout = 30
            EnablePerformanceMetrics = $true
            MaxRetries = 3
            RetryDelayMs = 1000
        }
    }

    # Register a module with the bus
    [hashtable] RegisterModule([string]$ModuleName, [object]$ModuleInstance) {
        if ($this.RegisteredModules.ContainsKey($ModuleName)) {
            throw "Module $ModuleName is already registered"
        }

        # Register the module
        $this.RegisteredModules[$ModuleName] = $ModuleInstance

        # Initialize module
        try {
            $initResult = $ModuleInstance.Initialize($this, $this.Configuration)
            Write-Host "Registered module: $ModuleName" -ForegroundColor Green

            return @{
                Success = $true
                ModuleName = $ModuleName
                InitializationResult = $initResult
            }
        }
        catch {
            Write-Error "Failed to initialize module $ModuleName`: $($_.Exception.Message)"
            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }

    # Check if module is registered
    [bool] IsModuleRegistered([string]$ModuleName) {
        return $this.RegisteredModules.ContainsKey($ModuleName)
    }

    # Subscribe to message types
    [void] Subscribe([string]$ModuleName, [string]$MessageType, [scriptblock]$Handler) {
        if (-not $this.IsModuleRegistered($ModuleName)) {
            throw "Module $ModuleName is not registered"
        }

        if (-not $this.Subscribers.ContainsKey($MessageType)) {
            $this.Subscribers[$MessageType] = @()
        }

        $subscription = @{
            ModuleName = $ModuleName
            Handler = $Handler
            SubscribedAt = Get-Date
        }

        $this.Subscribers[$MessageType] += $subscription
        Write-Verbose "Module $ModuleName subscribed to $MessageType events"
    }

    # Publish a message to all subscribers
    [void] Publish([string]$MessageType, [object]$Data, [string]$Source, [int]$Priority = 2) {
        $message = @{
            Id = [System.Guid]::NewGuid().ToString()
            Type = $MessageType
            Source = $Source
            Data = $Data
            Timestamp = Get-Date
            Priority = $Priority
        }

        # Process immediately for simplicity
        $this.ProcessMessage($message)

        $this.Performance.MessagesSent++
        $this.Performance.LastActivity = Get-Date

        Write-Verbose "Published $MessageType message from $Source (Priority: $Priority)"
    }

    # Process a single message
    [void] ProcessMessage([object]$Message) {
        try {
            if ($this.Subscribers.ContainsKey($Message.Type)) {
                $currentSubscribers = $this.Subscribers[$Message.Type]

                foreach ($subscription in $currentSubscribers) {
                    try {
                        & $subscription.Handler $Message
                    }
                    catch {
                        Write-Error "Error in subscriber $($subscription.ModuleName) for message type $($Message.Type): $($_.Exception.Message)"
                        $this.Performance.ErrorCount++
                    }
                }
            }

            $this.Performance.MessagesProcessed++
        }
        catch {
            Write-Error "Error processing message $($Message.Id): $($_.Exception.Message)"
            $this.Performance.ErrorCount++
        }
    }

    # Send direct message to specific module
    [object] SendMessage([string]$TargetModule, [string]$Action, [object]$Data, [int]$TimeoutSeconds = 0) {
        if (-not $this.IsModuleRegistered($TargetModule)) {
            throw "Target module $TargetModule is not registered"
        }

        if ($TimeoutSeconds -eq 0) {
            $TimeoutSeconds = $this.Configuration.DefaultRequestTimeout
        }

        $module = $this.RegisteredModules[$TargetModule]

        try {
            $result = $module.HandleMessage($Action, $Data, "DirectMessage")
            $this.Performance.MessagesReceived++
            $this.Performance.LastActivity = Get-Date
            return $result
        }
        catch {
            $this.Performance.ErrorCount++
            throw "Failed to send message to $TargetModule`: $($_.Exception.Message)"
        }
    }

    # Start message processing
    [void] Start() {
        if ($this.IsRunning) {
            Write-Warning "MessageBus is already running"
            return
        }

        $this.IsRunning = $true
        Write-Host "SimpleMessageBus started" -ForegroundColor Green
    }

    # Stop message processing
    [void] Stop() {
        if (-not $this.IsRunning) {
            return
        }

        $this.IsRunning = $false
        Write-Host "SimpleMessageBus stopped" -ForegroundColor Yellow
    }

    # Get system status
    [hashtable] GetStatus() {
        $moduleStatuses = @{}
        foreach ($moduleName in $this.RegisteredModules.Keys) {
            try {
                $module = $this.RegisteredModules[$moduleName]
                $moduleStatuses[$moduleName] = $module.GetStatus()
            }
            catch {
                $moduleStatuses[$moduleName] = @{
                    Error = $_.Exception.Message
                    LastChecked = Get-Date
                }
            }
        }

        return @{
            IsRunning = $this.IsRunning
            RegisteredModules = @($this.RegisteredModules.Keys)
            QueueStats = @{ High = 0; Medium = 0; Low = 0; Total = 0 }
            Performance = $this.Performance
            Configuration = $this.Configuration
            ModuleStatuses = $moduleStatuses
        }
    }

    # Shutdown all modules and stop message bus
    [void] Shutdown() {
        Write-Host "Shutting down SimpleMessageBus..." -ForegroundColor Yellow

        # Stop message processing
        $this.Stop()

        # Shutdown all modules
        foreach ($moduleName in $this.RegisteredModules.Keys) {
            try {
                $module = $this.RegisteredModules[$moduleName]
                $shutdownResult = $module.Shutdown()
                Write-Host "Module $moduleName shutdown: $($shutdownResult.Message)" -ForegroundColor Cyan
            }
            catch {
                Write-Error "Error shutting down module $moduleName`: $($_.Exception.Message)"
            }
        }

        $this.RegisteredModules.Clear()
        $this.Subscribers.Clear()

        Write-Host "SimpleMessageBus shutdown completed" -ForegroundColor Green
    }
}

# Utility functions
function New-MessageBus {
    param([hashtable]$Configuration = @{})

    return [SimpleMessageBus]::new($Configuration)
}

function Test-ModuleCommunication {
    param(
        [string]$SourceModule,
        [string]$TargetModule,
        [string]$Action,
        [object]$TestData = @{},
        [object]$MessageBus = $Global:MessageBus
    )

    $testResult = @{
        Success = $false
        ResponseTime = 0
        Response = $null
        Error = $null
        Timestamp = Get-Date
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $response = $MessageBus.SendMessage($TargetModule, $Action, $TestData)
        $testResult.Response = $response
        $testResult.Success = $true
    }
    catch {
        $testResult.Error = $_.Exception.Message
    }
    finally {
        $stopwatch.Stop()
        $testResult.ResponseTime = $stopwatch.ElapsedMilliseconds
    }

    return $testResult
}

# Export functions
Export-ModuleMember -Function @('New-MessageBus', 'Test-ModuleCommunication')
