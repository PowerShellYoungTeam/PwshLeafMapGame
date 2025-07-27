# Module Communication System
# Implements the MessageBus and IGameModule interface for inter-module communication

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent

# Import required modules
Import-Module (Join-Path $PSScriptRoot "DataModels.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "EventSystem.psm1") -Force

# Base interface for all game modules
class IGameModule {
    [string]$ModuleName
    [string]$Version
    [hashtable]$Dependencies
    [hashtable]$Capabilities
    [object]$MessageBus
    [hashtable]$Config
    [bool]$IsInitialized
    [DateTime]$LastActivity

    IGameModule() {
        $this.ModuleName = "BaseModule"
        $this.Version = "1.0.0"
        $this.Dependencies = @{}
        $this.Capabilities = @{}
        $this.Config = @{}
        $this.IsInitialized = $false
        $this.LastActivity = Get-Date
    }

    # Initialize module with message bus and configuration
    [hashtable] Initialize([object]$MessageBus, [hashtable]$Config) {
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

    # Handle incoming messages
    [object] HandleMessage([string]$Action, [object]$Data, [string]$Source) {
        $this.LastActivity = Get-Date

        switch ($Action) {
            "GetStatus" {
                return $this.GetStatus()
            }
            "GetCapabilities" {
                return $this.GetCapabilities()
            }
            "UpdateConfiguration" {
                return $this.UpdateConfiguration($Data)
            }
            default {
                throw "Unknown action: $Action"
            }
        }
    }

    # Get module status
    [hashtable] GetStatus() {
        return @{
            ModuleName = $this.ModuleName
            Version = $this.Version
            IsInitialized = $this.IsInitialized
            LastActivity = $this.LastActivity
            Capabilities = $this.Capabilities
            Dependencies = $this.Dependencies
        }
    }

    # Get module capabilities
    [hashtable] GetCapabilities() {
        return $this.Capabilities
    }

    # Update module configuration
    [hashtable] UpdateConfiguration([hashtable]$NewConfig) {
        foreach ($key in $NewConfig.Keys) {
            $this.Config[$key] = $NewConfig[$key]
        }

        return @{
            Success = $true
            Message = "Configuration updated"
            Config = $this.Config
        }
    }

    # Validate dependencies are available
    [hashtable] ValidateDependencies() {
        $result = @{
            IsValid = $true
            MissingDependencies = @()
            Errors = @()
        }

        foreach ($dependency in $this.Dependencies.Keys) {
            if (-not $this.MessageBus.IsModuleRegistered($dependency)) {
                $result.IsValid = $false
                $result.MissingDependencies += $dependency
                $result.Errors += "Missing dependency: $dependency"
            }
        }

        return $result
    }

    # Shutdown module
    [hashtable] Shutdown() {
        $this.IsInitialized = $false
        return @{
            Success = $true
            Message = "Module $($this.ModuleName) shutdown completed"
            Timestamp = Get-Date
        }
    }
}

# Priority queue for message processing
class PriorityMessageQueue {
    [ConcurrentDictionary[int, ConcurrentQueue[object]]]$Queues
    [object]$Lock

    PriorityMessageQueue() {
        $this.Queues = [ConcurrentDictionary[int, ConcurrentQueue[object]]]::new()
        $this.Lock = [object]::new()

        # Initialize priority levels (1=High, 2=Medium, 3=Low)
        for ($i = 1; $i -le 3; $i++) {
            $this.Queues[$i] = [ConcurrentQueue[object]]::new()
        }
    }

    [void] Enqueue([object]$Message, [int]$Priority = 2) {
        if ($Priority -lt 1 -or $Priority -gt 3) {
            $Priority = 2  # Default to medium priority
        }
        $this.Queues[$Priority].Enqueue($Message)
    }

    [object] Dequeue() {
        # Process messages in priority order
        for ($priority = 1; $priority -le 3; $priority++) {
            $message = $null
            if ($this.Queues[$priority].TryDequeue([ref]$message)) {
                return $message
            }
        }
        return $null
    }

    [int] GetTotalCount() {
        $total = 0
        for ($priority = 1; $priority -le 3; $priority++) {
            $total += $this.Queues[$priority].Count
        }
        return $total
    }

    [hashtable] GetQueueStats() {
        return @{
            High = $this.Queues[1].Count
            Medium = $this.Queues[2].Count
            Low = $this.Queues[3].Count
            Total = $this.GetTotalCount()
        }
    }
}

# Circuit breaker for module resilience
class CircuitBreaker {
    [string]$ModuleName
    [int]$FailureThreshold
    [int]$TimeoutSeconds
    [int]$FailureCount
    [DateTime]$LastFailure
    [string]$State  # Closed, Open, HalfOpen
    [object]$Lock

    CircuitBreaker([string]$ModuleName, [int]$FailureThreshold = 5, [int]$TimeoutSeconds = 60) {
        $this.ModuleName = $ModuleName
        $this.FailureThreshold = $FailureThreshold
        $this.TimeoutSeconds = $TimeoutSeconds
        $this.FailureCount = 0
        $this.State = "Closed"
        $this.Lock = [object]::new()
    }

    [object] Execute([scriptblock]$Operation) {
        [System.Threading.Monitor]::Enter($this.Lock)
        try {
            if ($this.State -eq "Open") {
                if ((Get-Date) - $this.LastFailure -gt [TimeSpan]::FromSeconds($this.TimeoutSeconds)) {
                    $this.State = "HalfOpen"
                    Write-Verbose "Circuit breaker for $($this.ModuleName) transitioning to HalfOpen"
                } else {
                    throw "Circuit breaker is OPEN for module $($this.ModuleName)"
                }
            }

            $result = & $Operation

            if ($this.State -eq "HalfOpen") {
                $this.State = "Closed"
                $this.FailureCount = 0
                Write-Verbose "Circuit breaker for $($this.ModuleName) CLOSED - module recovered"
            }

            return $result
        }
        catch {
            $this.FailureCount++
            $this.LastFailure = Get-Date

            if ($this.FailureCount -ge $this.FailureThreshold) {
                $this.State = "Open"
                Write-Warning "Circuit breaker OPEN for module $($this.ModuleName) after $($this.FailureCount) failures"
            }
            throw
        }
        finally {
            [System.Threading.Monitor]::Exit($this.Lock)
        }
    }

    [hashtable] GetStatus() {
        return @{
            ModuleName = $this.ModuleName
            State = $this.State
            FailureCount = $this.FailureCount
            FailureThreshold = $this.FailureThreshold
            LastFailure = $this.LastFailure
            TimeoutSeconds = $this.TimeoutSeconds
        }
    }
}

# Main MessageBus implementation
class MessageBus {
    [ConcurrentDictionary[string, object]]$RegisteredModules
    [ConcurrentDictionary[string, ConcurrentBag[object]]]$Subscribers
    [PriorityMessageQueue]$MessageQueue
    [ConcurrentDictionary[string, object]]$DataStreams
    [ConcurrentDictionary[string, CircuitBreaker]]$CircuitBreakers
    [hashtable]$Performance
    [hashtable]$Configuration
    [bool]$IsRunning
    [object]$ProcessingTimer
    [object]$Lock

    MessageBus([hashtable]$Config = @{}) {
        $this.RegisteredModules = [ConcurrentDictionary[string, object]]::new()
        $this.Subscribers = [ConcurrentDictionary[string, ConcurrentBag[object]]]::new()
        $this.MessageQueue = [PriorityMessageQueue]::new()
        $this.DataStreams = [ConcurrentDictionary[string, object]]::new()
        $this.CircuitBreakers = [ConcurrentDictionary[string, CircuitBreaker]]::new()
        $this.Performance = @{}
        $this.Configuration = $this.GetDefaultConfiguration() + $Config
        $this.IsRunning = $false
        $this.Lock = [object]::new()

        $this.InitializePerformanceMetrics()
    }

    [hashtable] GetDefaultConfiguration() {
        return @{
            MaxQueueSize = 10000
            ProcessingIntervalMs = 50
            EnableBatching = $true
            BatchSize = 25
            DefaultRequestTimeout = 30
            EnableCircuitBreaker = $true
            CircuitBreakerFailureThreshold = 5
            CircuitBreakerTimeoutSeconds = 60
            EnablePerformanceMetrics = $true
            EnableMessageTracing = $false
            MaxRetries = 3
            RetryDelayMs = 1000
            RetryBackoffMultiplier = 2.0
        }
    }

    [void] InitializePerformanceMetrics() {
        $this.Performance = @{
            MessagesSent = 0
            MessagesReceived = 0
            MessagesProcessed = 0
            ErrorCount = 0
            AverageProcessingTime = 0
            StartTime = Get-Date
            LastActivity = Get-Date
        }
    }

    # Register a module with the bus
    [hashtable] RegisterModule([string]$ModuleName, [IGameModule]$ModuleInstance) {
        if ($this.RegisteredModules.ContainsKey($ModuleName)) {
            throw "Module $ModuleName is already registered"
        }

        # Initialize circuit breaker for module
        if ($this.Configuration.EnableCircuitBreaker) {
            $circuitBreaker = [CircuitBreaker]::new(
                $ModuleName,
                $this.Configuration.CircuitBreakerFailureThreshold,
                $this.Configuration.CircuitBreakerTimeoutSeconds
            )
            $this.CircuitBreakers[$ModuleName] = $circuitBreaker
        }

        # Register the module
        $this.RegisteredModules[$ModuleName] = $ModuleInstance

        # Initialize module
        $initResult = $ModuleInstance.Initialize($this, $this.Configuration)

        # Validate dependencies
        $depValidation = $ModuleInstance.ValidateDependencies()

        Write-Host "Registered module: $ModuleName" -ForegroundColor Green
        if (-not $depValidation.IsValid) {
            Write-Warning "Module $ModuleName has missing dependencies: $($depValidation.MissingDependencies -join ', ')"
        }

        return @{
            Success = $true
            ModuleName = $ModuleName
            InitializationResult = $initResult
            DependencyValidation = $depValidation
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
            $this.Subscribers[$MessageType] = [ConcurrentBag[object]]::new()
        }

        $subscription = @{
            ModuleName = $ModuleName
            Handler = $Handler
            SubscribedAt = Get-Date
        }

        $this.Subscribers[$MessageType].Add($subscription)
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

        $this.MessageQueue.Enqueue($message, $Priority)
        $this.Performance.MessagesSent++
        $this.Performance.LastActivity = Get-Date

        Write-Verbose "Published $MessageType message from $Source (Priority: $Priority)"
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
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $result = if ($this.Configuration.EnableCircuitBreaker -and $this.CircuitBreakers.ContainsKey($TargetModule)) {
                $this.CircuitBreakers[$TargetModule].Execute({
                    return $module.HandleMessage($Action, $Data, "DirectMessage")
                })
            } else {
                $module.HandleMessage($Action, $Data, "DirectMessage")
            }

            $this.UpdatePerformanceMetrics($TargetModule, "SendMessage", $stopwatch.ElapsedMilliseconds, $true)
            return $result
        }
        catch {
            $this.UpdatePerformanceMetrics($TargetModule, "SendMessage", $stopwatch.ElapsedMilliseconds, $false)
            throw "Failed to send message to $TargetModule`: $($_.Exception.Message)"
        }
        finally {
            $stopwatch.Stop()
        }
    }

    # Process queued messages
    [void] ProcessMessages() {
        $processed = 0
        $batchSize = $this.Configuration.BatchSize

        while ($processed -lt $batchSize) {
            $message = $this.MessageQueue.Dequeue()
            if ($null -eq $message) {
                break
            }

            $this.ProcessSingleMessage($message)
            $processed++
        }

        if ($processed -gt 0) {
            $this.Performance.MessagesProcessed += $processed
            Write-Verbose "Processed $processed messages"
        }
    }

    [void] ProcessSingleMessage([object]$Message) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            if ($this.Subscribers.ContainsKey($Message.Type)) {
                $subscribers = $this.Subscribers[$Message.Type]

                foreach ($subscription in $subscribers) {
                    try {
                        & $subscription.Handler $Message
                    }
                    catch {
                        Write-Error "Error in subscriber $($subscription.ModuleName) for message type $($Message.Type): $($_.Exception.Message)"
                        $this.Performance.ErrorCount++
                    }
                }
            }

            $this.UpdateAverageProcessingTime($stopwatch.ElapsedMilliseconds)
        }
        catch {
            Write-Error "Error processing message $($Message.Id): $($_.Exception.Message)"
            $this.Performance.ErrorCount++
        }
        finally {
            $stopwatch.Stop()
        }
    }

    [void] UpdatePerformanceMetrics([string]$ModuleName, [string]$Operation, [double]$Duration, [bool]$Success) {
        if (-not $this.Configuration.EnablePerformanceMetrics) {
            return
        }

        if (-not $this.Performance.ContainsKey($ModuleName)) {
            $this.Performance[$ModuleName] = @{
                MessagesSent = 0
                MessagesReceived = 0
                AverageResponseTime = 0
                ErrorCount = 0
                LastActivity = Get-Date
            }
        }

        $moduleMetrics = $this.Performance[$ModuleName]

        switch ($Operation) {
            "SendMessage" { $moduleMetrics.MessagesSent++ }
            "ReceiveMessage" { $moduleMetrics.MessagesReceived++ }
        }

        if ($Duration -gt 0) {
            $totalMessages = $moduleMetrics.MessagesSent + $moduleMetrics.MessagesReceived
            if ($totalMessages -gt 0) {
                $currentAvg = $moduleMetrics.AverageResponseTime
                $moduleMetrics.AverageResponseTime = (($currentAvg * ($totalMessages - 1)) + $Duration) / $totalMessages
            }
        }

        if (-not $Success) {
            $moduleMetrics.ErrorCount++
        }

        $moduleMetrics.LastActivity = Get-Date
    }

    [void] UpdateAverageProcessingTime([double]$Duration) {
        $currentAvg = $this.Performance.AverageProcessingTime
        $totalProcessed = $this.Performance.MessagesProcessed

        if ($totalProcessed -gt 0) {
            $this.Performance.AverageProcessingTime = (($currentAvg * ($totalProcessed - 1)) + $Duration) / $totalProcessed
        } else {
            $this.Performance.AverageProcessingTime = $Duration
        }
    }

    # Start message processing
    [void] Start() {
        if ($this.IsRunning) {
            Write-Warning "MessageBus is already running"
            return
        }

        $this.IsRunning = $true

        # Create timer for message processing
        $this.ProcessingTimer = New-Object System.Timers.Timer
        $this.ProcessingTimer.Interval = $this.Configuration.ProcessingIntervalMs
        $this.ProcessingTimer.AutoReset = $true

        Register-ObjectEvent -InputObject $this.ProcessingTimer -EventName Elapsed -Action {
            try {
                $Global:MessageBus.ProcessMessages()
            }
            catch {
                Write-Error "Error in message processing timer: $($_.Exception.Message)"
            }
        } | Out-Null

        $this.ProcessingTimer.Start()
        Write-Host "MessageBus started with processing interval: $($this.Configuration.ProcessingIntervalMs)ms" -ForegroundColor Green
    }

    # Stop message processing
    [void] Stop() {
        if (-not $this.IsRunning) {
            return
        }

        $this.IsRunning = $false

        if ($this.ProcessingTimer) {
            $this.ProcessingTimer.Stop()
            $this.ProcessingTimer.Dispose()
            $this.ProcessingTimer = $null
        }

        # Process remaining messages
        while ($this.MessageQueue.GetTotalCount() -gt 0) {
            $this.ProcessMessages()
        }

        Write-Host "MessageBus stopped" -ForegroundColor Yellow
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
            RegisteredModules = $this.RegisteredModules.Keys
            QueueStats = $this.MessageQueue.GetQueueStats()
            Performance = $this.Performance
            Configuration = $this.Configuration
            ModuleStatuses = $moduleStatuses
            CircuitBreakerStates = if ($this.Configuration.EnableCircuitBreaker) {
                $states = @{}
                foreach ($cb in $this.CircuitBreakers.Keys) {
                    $states[$cb] = $this.CircuitBreakers[$cb].GetStatus()
                }
                $states
            } else { @{} }
        }
    }

    # Shutdown all modules and stop message bus
    [void] Shutdown() {
        Write-Host "Shutting down MessageBus..." -ForegroundColor Yellow

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

        Write-Host "MessageBus shutdown completed" -ForegroundColor Green
    }
}

# Utility functions for module communication
function New-MessageBus {
    param([hashtable]$Configuration = @{})

    return [MessageBus]::new($Configuration)
}

function Invoke-WithRetry {
    param(
        [scriptblock]$Operation,
        [int]$MaxRetries = 3,
        [int]$DelayMs = 1000,
        [double]$BackoffMultiplier = 2.0
    )

    $attempt = 0
    $delay = $DelayMs

    while ($attempt -lt $MaxRetries) {
        try {
            return & $Operation
        }
        catch {
            $attempt++
            if ($attempt -eq $MaxRetries) {
                throw "Operation failed after $MaxRetries attempts: $($_.Exception.Message)"
            }

            Write-Warning "Attempt $attempt failed, retrying in $delay ms: $($_.Exception.Message)"
            Start-Sleep -Milliseconds $delay
            $delay = [int]($delay * $BackoffMultiplier)
        }
    }
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

# Export functions and classes
Export-ModuleMember -Function @(
    'New-MessageBus',
    'Invoke-WithRetry',
    'Test-ModuleCommunication'
)

# Make classes available globally for inheritance
$Global:IGameModule = [IGameModule]
$Global:MessageBus = [MessageBus]
$Global:CircuitBreaker = [CircuitBreaker]
$Global:PriorityMessageQueue = [PriorityMessageQueue]
