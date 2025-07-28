# PowerShell Leafmap Game - Command Registry System
# Advanced command registration and execution framework for modular game architecture

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.ComponentModel.DataAnnotations

# Import required modules
Import-Module (Join-Path $PSScriptRoot "EventSystem.psm1") -Force

# Command parameter validation attributes
enum ParameterType {
    String
    Integer
    Float
    Boolean
    Object
    Array
    Enum
    DateTime
    Guid
}

# Parameter validation constraint types
enum ConstraintType {
    Required
    MinLength
    MaxLength
    MinValue
    MaxValue
    Pattern
    Enum
    Custom
}

# Command access levels
enum AccessLevel {
    Public
    Protected
    Admin
    System
}

# Parameter constraint class
class ParameterConstraint {
    [ConstraintType]$Type
    [object]$Value
    [string]$ErrorMessage
    [scriptblock]$CustomValidator

    ParameterConstraint([ConstraintType]$Type, [object]$Value, [string]$ErrorMessage = "") {
        $this.Type = $Type
        $this.Value = $Value
        $this.ErrorMessage = $ErrorMessage
    }

    ParameterConstraint([scriptblock]$CustomValidator, [string]$ErrorMessage = "") {
        $this.Type = [ConstraintType]::Custom
        $this.CustomValidator = $CustomValidator
        $this.ErrorMessage = $ErrorMessage
    }

    [bool] Validate([object]$ParameterValue) {
        try {
            switch ($this.Type) {
                "Required" {
                    return $null -ne $ParameterValue -and $ParameterValue -ne ""
                }
                "MinLength" {
                    return $ParameterValue.ToString().Length -ge $this.Value
                }
                "MaxLength" {
                    return $ParameterValue.ToString().Length -le $this.Value
                }
                "MinValue" {
                    return $ParameterValue -ge $this.Value
                }
                "MaxValue" {
                    return $ParameterValue -le $this.Value
                }
                "Pattern" {
                    return $ParameterValue -match $this.Value
                }
                "Enum" {
                    return $ParameterValue -in $this.Value
                }
                "Custom" {
                    if ($this.CustomValidator) {
                        return & $this.CustomValidator $ParameterValue
                    }
                    return $true
                }
                default {
                    return $true
                }
            }
        }
        catch {
            return $false
        }
        return $true
    }
}

# Command parameter definition
class CommandParameter {
    [string]$Name
    [ParameterType]$Type
    [string]$Description
    [bool]$Required
    [object]$DefaultValue
    [List[ParameterConstraint]]$Constraints
    [hashtable]$Metadata

    CommandParameter([string]$Name, [ParameterType]$Type, [string]$Description) {
        $this.Name = $Name
        $this.Type = $Type
        $this.Description = $Description
        $this.Required = $false
        $this.Constraints = [List[ParameterConstraint]]::new()
        $this.Metadata = @{}
    }

    [CommandParameter] SetRequired([bool]$IsRequired = $true) {
        $this.Required = $IsRequired
        if ($IsRequired) {
            $this.AddConstraint([ParameterConstraint]::new([ConstraintType]::Required, $true, "Parameter '$($this.Name)' is required"))
        }
        return $this
    }

    [CommandParameter] SetDefault([object]$DefaultValue) {
        $this.DefaultValue = $DefaultValue
        return $this
    }

    [CommandParameter] AddConstraint([ParameterConstraint]$Constraint) {
        $this.Constraints.Add($Constraint)
        return $this
    }

    [CommandParameter] AddMetadata([string]$Key, [object]$Value) {
        $this.Metadata[$Key] = $Value
        return $this
    }

    [hashtable] Validate([object]$Value) {
        $result = @{
            IsValid = $true
            Errors = @()
            Value = $Value
        }

        # Apply default value if parameter is null/empty and not required
        if (($null -eq $Value -or $Value -eq "") -and $null -ne $this.DefaultValue) {
            $result.Value = $this.DefaultValue
            $Value = $this.DefaultValue
        }

        # Validate constraints
        foreach ($constraint in $this.Constraints) {
            if (-not $constraint.Validate($Value)) {
                $result.IsValid = $false
                $errorMsg = if ($constraint.ErrorMessage) {
                    $constraint.ErrorMessage
                } else {
                    "Parameter '$($this.Name)' failed validation: $($constraint.Type)"
                }
                $result.Errors += $errorMsg
            }
        }

        # Type validation
        if ($null -ne $Value -and $Value -ne "") {
            $typeValid = $this.ValidateType($Value)
            if (-not $typeValid.IsValid) {
                $result.IsValid = $false
                $result.Errors += $typeValid.Error
            } else {
                $result.Value = $typeValid.ConvertedValue
            }
        }

        return $result
    }

    [hashtable] ValidateType([object]$Value) {
        $result = @{
            IsValid = $true
            ConvertedValue = $Value
            Error = $null
        }

        try {
            switch ($this.Type) {
                "String" {
                    $result.ConvertedValue = $Value.ToString()
                }
                "Integer" {
                    $result.ConvertedValue = [int]$Value
                }
                "Float" {
                    $result.ConvertedValue = [double]$Value
                }
                "Boolean" {
                    $result.ConvertedValue = [bool]$Value
                }
                "DateTime" {
                    $result.ConvertedValue = [datetime]$Value
                }
                "Guid" {
                    $result.ConvertedValue = [guid]$Value
                }
                "Object" {
                    # Objects pass through as-is
                    $result.ConvertedValue = $Value
                }
                "Array" {
                    if ($Value -is [array]) {
                        $result.ConvertedValue = $Value
                    } else {
                        $result.ConvertedValue = @($Value)
                    }
                }
            }
        }
        catch {
            $result.IsValid = $false
            $result.Error = "Cannot convert parameter '$($this.Name)' to type $($this.Type): $($_.Exception.Message)"
        }

        return $result
    }
}

# Command middleware interface
class CommandMiddleware {
    [string]$Name
    [int]$Priority
    [scriptblock]$PreExecute
    [scriptblock]$PostExecute
    [scriptblock]$OnError

    CommandMiddleware([string]$Name, [int]$Priority = 100) {
        $this.Name = $Name
        $this.Priority = $Priority
    }

    [CommandMiddleware] SetPreExecute([scriptblock]$PreExecute) {
        $this.PreExecute = $PreExecute
        return $this
    }

    [CommandMiddleware] SetPostExecute([scriptblock]$PostExecute) {
        $this.PostExecute = $PostExecute
        return $this
    }

    [CommandMiddleware] SetErrorHandler([scriptblock]$OnError) {
        $this.OnError = $OnError
        return $this
    }
}

# Command definition class
class CommandDefinition {
    [string]$Name
    [string]$FullName
    [string]$Module
    [string]$Description
    [string]$Category
    [AccessLevel]$AccessLevel
    [List[CommandParameter]]$Parameters
    [scriptblock]$Handler
    [List[CommandMiddleware]]$Middleware
    [hashtable]$Metadata
    [hashtable]$Examples
    [string]$Version
    [datetime]$RegisteredAt
    [bool]$IsEnabled

    CommandDefinition([string]$Name, [string]$Module, [scriptblock]$Handler) {
        $this.Name = $Name
        $this.Module = $Module
        $this.FullName = "$Module.$Name"
        $this.Handler = $Handler
        $this.Parameters = [List[CommandParameter]]::new()
        $this.Middleware = [List[CommandMiddleware]]::new()
        $this.Metadata = @{}
        $this.Examples = @{}
        $this.AccessLevel = [AccessLevel]::Public
        $this.Version = "1.0.0"
        $this.RegisteredAt = Get-Date
        $this.IsEnabled = $true
    }

    [CommandDefinition] SetDescription([string]$Description) {
        $this.Description = $Description
        return $this
    }

    [CommandDefinition] SetCategory([string]$Category) {
        $this.Category = $Category
        return $this
    }

    [CommandDefinition] SetAccessLevel([AccessLevel]$AccessLevel) {
        $this.AccessLevel = $AccessLevel
        return $this
    }

    [CommandDefinition] SetVersion([string]$Version) {
        $this.Version = $Version
        return $this
    }

    [CommandDefinition] AddParameter([CommandParameter]$Parameter) {
        $this.Parameters.Add($Parameter)
        return $this
    }

    [CommandDefinition] AddMiddleware([CommandMiddleware]$Middleware) {
        $this.Middleware.Add($Middleware)
        # Sort middleware by priority
        $this.Middleware = [List[CommandMiddleware]]($this.Middleware | Sort-Object Priority)
        return $this
    }

    [CommandDefinition] AddExample([string]$Name, [hashtable]$Example) {
        $this.Examples[$Name] = $Example
        return $this
    }

    [CommandDefinition] AddMetadata([string]$Key, [object]$Value) {
        $this.Metadata[$Key] = $Value
        return $this
    }

    [CommandDefinition] SetEnabled([bool]$Enabled) {
        $this.IsEnabled = $Enabled
        return $this
    }

    [hashtable] ValidateParameters([hashtable]$InputParameters) {
        $result = @{
            IsValid = $true
            ValidatedParameters = @{}
            Errors = @()
        }

        # Validate each defined parameter
        foreach ($paramDef in $this.Parameters) {
            $inputValue = $InputParameters[$paramDef.Name]
            $validation = $paramDef.Validate($inputValue)

            if ($validation.IsValid) {
                $result.ValidatedParameters[$paramDef.Name] = $validation.Value
            } else {
                $result.IsValid = $false
                $result.Errors += $validation.Errors
            }
        }

        # Check for unexpected parameters
        foreach ($inputParam in $InputParameters.Keys) {
            $isDefined = $this.Parameters | Where-Object { $_.Name -eq $inputParam }
            if (-not $isDefined) {
                $result.Errors += "Unknown parameter: $inputParam"
                # Don't mark as invalid for unknown parameters, just warn
            }
        }

        return $result
    }

    [hashtable] GetDocumentation() {
        return @{
            Name = $this.Name
            FullName = $this.FullName
            Module = $this.Module
            Description = $this.Description
            Category = $this.Category
            AccessLevel = $this.AccessLevel.ToString()
            Version = $this.Version
            Parameters = $this.Parameters | ForEach-Object {
                @{
                    Name = $_.Name
                    Type = $_.Type.ToString()
                    Description = $_.Description
                    Required = $_.Required
                    DefaultValue = $_.DefaultValue
                    Constraints = $_.Constraints | ForEach-Object {
                        @{
                            Type = $_.Type.ToString()
                            Value = $_.Value
                            ErrorMessage = $_.ErrorMessage
                        }
                    }
                    Metadata = $_.Metadata
                }
            }
            Examples = $this.Examples
            Metadata = $this.Metadata
            RegisteredAt = $this.RegisteredAt
            IsEnabled = $this.IsEnabled
        }
    }
}

# Main command registry class
class CommandRegistry {
    [ConcurrentDictionary[string, CommandDefinition]]$Commands
    [ConcurrentDictionary[string, List[CommandMiddleware]]]$GlobalMiddleware
    [hashtable]$Configuration
    [hashtable]$Statistics

    CommandRegistry([hashtable]$Config = @{}) {
        $this.Commands = [ConcurrentDictionary[string, CommandDefinition]]::new()
        $this.GlobalMiddleware = [ConcurrentDictionary[string, List[CommandMiddleware]]]::new()
        $this.Configuration = @{
            EnableAccessControl = $true
            EnableTelemetry = $true
            EnableValidation = $true
            MaxExecutionTime = 30000  # 30 seconds
            EnableCaching = $false
        }

        # Merge provided config
        foreach ($key in $Config.Keys) {
            $this.Configuration[$key] = $Config[$key]
        }

        $this.Statistics = @{
            TotalCommands = 0
            CommandsExecuted = 0
            ExecutionErrors = 0
            AverageExecutionTime = 0
            LastExecutionTime = $null
            ModuleStats = @{}
        }

        $this.InitializeBuiltInMiddleware()
    }

    [void] InitializeBuiltInMiddleware() {
        # Telemetry middleware
        if ($this.Configuration.EnableTelemetry) {
            $telemetryMiddleware = [CommandMiddleware]::new("Telemetry", 10)
            $telemetryMiddleware.SetPreExecute({
                param($Context)
                $Context.StartTime = Get-Date
                $Context.ExecutionId = [System.Guid]::NewGuid().ToString()
            })
            $telemetryMiddleware.SetPostExecute({
                param($Context, $Result)
                $executionTime = ((Get-Date) - $Context.StartTime).TotalMilliseconds
                $this.UpdateStatistics($Context.Command.FullName, $executionTime, $true)

                Publish-GameEvent -EventType "command.executed" -Data @{
                    Command = $Context.Command.FullName
                    ExecutionTime = $executionTime
                    Success = $Result.Success
                    ExecutionId = $Context.ExecutionId
                }
            })
            $telemetryMiddleware.SetErrorHandler({
                param($Context, $ErrorInfo)
                $executionTime = ((Get-Date) - $Context.StartTime).TotalMilliseconds
                $this.UpdateStatistics($Context.Command.FullName, $executionTime, $false)

                Publish-GameEvent -EventType "command.error" -Data @{
                    Command = $Context.Command.FullName
                    ExecutionTime = $executionTime
                    Error = $ErrorInfo.Exception.Message
                    ExecutionId = $Context.ExecutionId
                }
            })

            $this.AddGlobalMiddleware("Telemetry", $telemetryMiddleware)
        }

        # Validation middleware
        if ($this.Configuration.EnableValidation) {
            $validationMiddleware = [CommandMiddleware]::new("Validation", 20)
            $validationMiddleware.SetPreExecute({
                param($Context)
                $validation = $Context.Command.ValidateParameters($Context.Parameters)
                if (-not $validation.IsValid) {
                    throw "Parameter validation failed: $($validation.Errors -join ', ')"
                }
                $Context.ValidatedParameters = $validation.ValidatedParameters
            })

            $this.AddGlobalMiddleware("Validation", $validationMiddleware)
        }

        # Access control middleware
        if ($this.Configuration.EnableAccessControl) {
            $accessMiddleware = [CommandMiddleware]::new("AccessControl", 5)
            $accessMiddleware.SetPreExecute({
                param($Context)
                # Implement access control logic here
                # For now, allow all public commands
                if ($Context.Command.AccessLevel -ne [AccessLevel]::Public) {
                    # Check user permissions (implement based on your auth system)
                    # throw "Access denied to command: $($Context.Command.FullName)"
                }
            })

            $this.AddGlobalMiddleware("AccessControl", $accessMiddleware)
        }
    }

    [bool] RegisterCommand([CommandDefinition]$Command) {
        try {
            if ($this.Commands.ContainsKey($Command.FullName)) {
                Write-Warning "Command '$($Command.FullName)' is already registered. Updating existing registration."
            }

            $this.Commands[$Command.FullName] = $Command
            $this.Statistics.TotalCommands = $this.Commands.Count

            # Update module statistics
            if (-not $this.Statistics.ModuleStats.ContainsKey($Command.Module)) {
                $this.Statistics.ModuleStats[$Command.Module] = @{
                    CommandCount = 0
                    ExecutionCount = 0
                    ErrorCount = 0
                }
            }
            $this.Statistics.ModuleStats[$Command.Module].CommandCount++

            Publish-GameEvent -EventType "command.registered" -Data @{
                Command = $Command.FullName
                Module = $Command.Module
                Description = $Command.Description
            }

            Write-Verbose "Command registered: $($Command.FullName)"
            return $true
        }
        catch {
            Write-Error "Failed to register command '$($Command.FullName)': $($_.Exception.Message)"
            return $false
        }
    }

    [bool] UnregisterCommand([string]$CommandName) {
        try {
            $removed = $this.Commands.TryRemove($CommandName, [ref]$null)
            if ($removed) {
                $this.Statistics.TotalCommands = $this.Commands.Count
                Publish-GameEvent -EventType "command.unregistered" -Data @{ Command = $CommandName }
                Write-Verbose "Command unregistered: $CommandName"
            }
            return $removed
        }
        catch {
            Write-Error "Failed to unregister command '$CommandName': $($_.Exception.Message)"
            return $false
        }
    }

    [CommandDefinition] GetCommand([string]$CommandName) {
        $command = $null
        $this.Commands.TryGetValue($CommandName, [ref]$command)
        return $command
    }

    [List[CommandDefinition]] GetCommandsByModule([string]$ModuleName) {
        $moduleCommands = [List[CommandDefinition]]::new()
        foreach ($command in $this.Commands.Values) {
            if ($command.Module -eq $ModuleName) {
                $moduleCommands.Add($command)
            }
        }
        return $moduleCommands
    }

    [List[CommandDefinition]] GetCommandsByCategory([string]$Category) {
        $categoryCommands = [List[CommandDefinition]]::new()
        foreach ($command in $this.Commands.Values) {
            if ($command.Category -eq $Category) {
                $categoryCommands.Add($command)
            }
        }
        return $categoryCommands
    }

    [List[string]] GetAvailableCommands([AccessLevel]$MaxAccessLevel = [AccessLevel]::Public) {
        $commandNames = [List[string]]::new()
        foreach ($command in $this.Commands.Values) {
            if ($command.IsEnabled -and $command.AccessLevel -le $MaxAccessLevel) {
                $commandNames.Add($command.FullName)
            }
        }
        return $commandNames
    }

    [void] AddGlobalMiddleware([string]$Category, [CommandMiddleware]$Middleware) {
        if (-not $this.GlobalMiddleware.ContainsKey($Category)) {
            $this.GlobalMiddleware[$Category] = [List[CommandMiddleware]]::new()
        }
        $this.GlobalMiddleware[$Category].Add($Middleware)
    }

    [hashtable] ExecuteCommand([string]$CommandName, [hashtable]$Parameters = @{}, [hashtable]$Context = @{}) {
        $command = $this.GetCommand($CommandName)
        if (-not $command) {
            throw "Command not found: $CommandName"
        }

        if (-not $command.IsEnabled) {
            throw "Command is disabled: $CommandName"
        }

        # Create execution context
        $execContext = @{
            Command = $command
            Parameters = $Parameters
            Context = $Context
            StartTime = Get-Date
            ExecutionId = [System.Guid]::NewGuid().ToString()
            ValidatedParameters = @{}
        }

        # Collect all middleware (global + command-specific)
        $allMiddleware = [List[CommandMiddleware]]::new()
        foreach ($globalCategory in $this.GlobalMiddleware.Values) {
            $allMiddleware.AddRange($globalCategory)
        }
        $allMiddleware.AddRange($command.Middleware)
        $allMiddleware = $allMiddleware | Sort-Object Priority

        $result = @{
            Success = $false
            Data = $null
            Error = $null
            ExecutionTime = 0
            CommandName = $CommandName
            ExecutionId = $execContext.ExecutionId
            Timestamp = Get-Date
        }

        try {
            # Execute pre-execution middleware
            foreach ($middleware in $allMiddleware) {
                if ($middleware.PreExecute) {
                    & $middleware.PreExecute $execContext
                }
            }

            # Execute the command
            $commandResult = & $command.Handler $execContext.ValidatedParameters $execContext

            $result.Success = $true
            $result.Data = $commandResult

            # Execute post-execution middleware
            foreach ($middleware in $allMiddleware) {
                if ($middleware.PostExecute) {
                    & $middleware.PostExecute $execContext $result
                }
            }
        }
        catch {
            $result.Error = $_.Exception.Message
            $this.Statistics.ExecutionErrors++

            # Execute error middleware
            foreach ($middleware in $allMiddleware) {
                if ($middleware.OnError) {
                    try {
                        & $middleware.OnError $execContext $_
                    }
                    catch {
                        Write-Warning "Middleware error handler failed: $($_.Exception.Message)"
                    }
                }
            }

            throw
        }
        finally {
            $result.ExecutionTime = ((Get-Date) - $execContext.StartTime).TotalMilliseconds
            $this.Statistics.CommandsExecuted++
            $this.Statistics.LastExecutionTime = Get-Date
        }

        return $result
    }

    [void] UpdateStatistics([string]$CommandName, [double]$ExecutionTime, [bool]$Success) {
        # Update average execution time
        $this.Statistics.AverageExecutionTime = (
            ($this.Statistics.AverageExecutionTime * ($this.Statistics.CommandsExecuted - 1)) + $ExecutionTime
        ) / $this.Statistics.CommandsExecuted

        # Update module statistics
        $command = $this.GetCommand($CommandName)
        if ($command) {
            $this.Statistics.ModuleStats[$command.Module].ExecutionCount++
            if (-not $Success) {
                $this.Statistics.ModuleStats[$command.Module].ErrorCount++
            }
        }
    }

    [hashtable] GetRegistryStatistics() {
        return $this.Statistics.Clone()
    }

    [hashtable] GenerateDocumentation([string]$ModuleName = "", [string]$Format = "JSON") {
        $commandsToDocument = if ($ModuleName) {
            $this.GetCommandsByModule($ModuleName)
        } else {
            $this.Commands.Values
        }

        $documentation = @{
            GeneratedAt = Get-Date
            TotalCommands = $commandsToDocument.Count
            Modules = @{}
            Commands = @{}
        }

        foreach ($command in $commandsToDocument) {
            if (-not $documentation.Modules.ContainsKey($command.Module)) {
                $documentation.Modules[$command.Module] = @{
                    Commands = @()
                    Categories = @{}
                }
            }

            $commandDoc = $command.GetDocumentation()
            $documentation.Commands[$command.FullName] = $commandDoc
            $documentation.Modules[$command.Module].Commands += $command.FullName

            if ($command.Category) {
                if (-not $documentation.Modules[$command.Module].Categories.ContainsKey($command.Category)) {
                    $documentation.Modules[$command.Module].Categories[$command.Category] = @()
                }
                $documentation.Modules[$command.Module].Categories[$command.Category] += $command.FullName
            }
        }

        return $documentation
    }
}

# Global registry instance
$script:GlobalCommandRegistry = $null

# Helper functions for command registration
function New-CommandParameter {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ParameterType]$Type,

        [string]$Description = "",
        [bool]$Required = $false,
        [object]$DefaultValue = $null
    )

    $param = [CommandParameter]::new($Name, $Type, $Description)

    if ($Required) {
        $param.SetRequired($true)
    }

    if ($null -ne $DefaultValue) {
        $param.SetDefault($DefaultValue)
    }

    return $param
}

function New-CommandDefinition {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [scriptblock]$Handler,

        [string]$Description = "",
        [string]$Category = "",
        [AccessLevel]$AccessLevel = [AccessLevel]::Public,
        [string]$Version = "1.0.0"
    )

    $command = [CommandDefinition]::new($Name, $Module, $Handler)

    if ($Description) {
        $command.SetDescription($Description)
    }

    if ($Category) {
        $command.SetCategory($Category)
    }

    $command.SetAccessLevel($AccessLevel)
    $command.SetVersion($Version)

    return $command
}

function New-ParameterConstraint {
    param(
        [Parameter(Mandatory, ParameterSetName = "Standard")]
        [ConstraintType]$Type,

        [Parameter(Mandatory, ParameterSetName = "Standard")]
        [object]$Value,

        [Parameter(ParameterSetName = "Standard")]
        [string]$ErrorMessage = "",

        [Parameter(Mandatory, ParameterSetName = "Custom")]
        [scriptblock]$CustomValidator,

        [Parameter(ParameterSetName = "Custom")]
        [string]$CustomErrorMessage = ""
    )

    if ($PSCmdlet.ParameterSetName -eq "Custom") {
        return [ParameterConstraint]::new($CustomValidator, $CustomErrorMessage)
    } else {
        return [ParameterConstraint]::new($Type, $Value, $ErrorMessage)
    }
}

function New-CommandMiddleware {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [int]$Priority = 100,
        [scriptblock]$PreExecute = $null,
        [scriptblock]$PostExecute = $null,
        [scriptblock]$OnError = $null
    )

    $middleware = [CommandMiddleware]::new($Name, $Priority)

    if ($PreExecute) {
        $middleware.SetPreExecute($PreExecute)
    }

    if ($PostExecute) {
        $middleware.SetPostExecute($PostExecute)
    }

    if ($OnError) {
        $middleware.SetErrorHandler($OnError)
    }

    return $middleware
}

# Public API functions
function Initialize-CommandRegistry {
    param([hashtable]$Configuration = @{})

    if ($script:GlobalCommandRegistry) {
        Write-Warning "Command Registry is already initialized"
        return $script:GlobalCommandRegistry
    }

    try {
        $script:GlobalCommandRegistry = [CommandRegistry]::new($Configuration)
        Write-Host "Command Registry initialized successfully" -ForegroundColor Green

        # Register built-in commands
        Register-BuiltInCommands

        return $script:GlobalCommandRegistry
    }
    catch {
        Write-Error "Failed to initialize Command Registry: $($_.Exception.Message)"
        throw
    }
}

function Register-BuiltInCommands {
    # Registry management commands
    $listCommandsCmd = New-CommandDefinition -Name "listCommands" -Module "registry" -Handler {
        param($Parameters, $Context)

        $accessLevel = [AccessLevel]::Public
        if ($Parameters.IncludeProtected) {
            $accessLevel = [AccessLevel]::Protected
        }
        if ($Parameters.IncludeAdmin) {
            $accessLevel = [AccessLevel]::Admin
        }

        $commands = $script:GlobalCommandRegistry.GetAvailableCommands($accessLevel)

        if ($Parameters.Module) {
            $commands = $commands | Where-Object { $_ -like "$($Parameters.Module).*" }
        }

        return @{
            Commands = $commands
            TotalCount = $commands.Count
        }
    } -Description "List all available commands" -Category "Registry"

    $listCommandsCmd.AddParameter((New-CommandParameter -Name "Module" -Type ([ParameterType]::String) -Description "Filter by module name"))
    $listCommandsCmd.AddParameter((New-CommandParameter -Name "IncludeProtected" -Type ([ParameterType]::Boolean) -Description "Include protected commands" -DefaultValue $false))
    $listCommandsCmd.AddParameter((New-CommandParameter -Name "IncludeAdmin" -Type ([ParameterType]::Boolean) -Description "Include admin commands" -DefaultValue $false))

    $script:GlobalCommandRegistry.RegisterCommand($listCommandsCmd)

    # Command documentation
    $getDocCmd = New-CommandDefinition -Name "getDocumentation" -Module "registry" -Handler {
        param($Parameters, $Context)

        if ($Parameters.CommandName) {
            $command = $script:GlobalCommandRegistry.GetCommand($Parameters.CommandName)
            if ($command) {
                return $command.GetDocumentation()
            } else {
                throw "Command not found: $($Parameters.CommandName)"
            }
        } else {
            return $script:GlobalCommandRegistry.GenerateDocumentation($Parameters.Module, $Parameters.Format)
        }
    } -Description "Get command documentation" -Category "Registry"

    $getDocCmd.AddParameter((New-CommandParameter -Name "CommandName" -Type ([ParameterType]::String) -Description "Specific command to document"))
    $getDocCmd.AddParameter((New-CommandParameter -Name "Module" -Type ([ParameterType]::String) -Description "Module to document"))
    $getDocCmd.AddParameter((New-CommandParameter -Name "Format" -Type ([ParameterType]::String) -Description "Documentation format" -DefaultValue "JSON"))

    $script:GlobalCommandRegistry.RegisterCommand($getDocCmd)

    # Registry statistics
    $getStatsCmd = New-CommandDefinition -Name "getStatistics" -Module "registry" -Handler {
        param($Parameters, $Context)
        return $script:GlobalCommandRegistry.GetRegistryStatistics()
    } -Description "Get registry statistics" -Category "Registry"

    $script:GlobalCommandRegistry.RegisterCommand($getStatsCmd)
}

function Register-GameCommand {
    param(
        [Parameter(Mandatory)]
        [CommandDefinition]$Command
    )

    if (-not $script:GlobalCommandRegistry) {
        throw "Command Registry not initialized. Call Initialize-CommandRegistry first."
    }

    return $script:GlobalCommandRegistry.RegisterCommand($Command)
}

function Unregister-GameCommand {
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    if (-not $script:GlobalCommandRegistry) {
        throw "Command Registry not initialized."
    }

    return $script:GlobalCommandRegistry.UnregisterCommand($CommandName)
}

function Invoke-GameCommand {
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [hashtable]$Parameters = @{},
        [hashtable]$Context = @{}
    )

    if (-not $script:GlobalCommandRegistry) {
        throw "Command Registry not initialized."
    }

    return $script:GlobalCommandRegistry.ExecuteCommand($CommandName, $Parameters, $Context)
}

function Get-GameCommand {
    param([string]$CommandName)

    if (-not $script:GlobalCommandRegistry) {
        throw "Command Registry not initialized."
    }

    if ($CommandName) {
        return $script:GlobalCommandRegistry.GetCommand($CommandName)
    } else {
        return $script:GlobalCommandRegistry.Commands.Values
    }
}

function Get-CommandRegistryStatistics {
    if ($script:GlobalCommandRegistry) {
        return $script:GlobalCommandRegistry.GetRegistryStatistics()
    }
    return @{}
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-CommandRegistry',
    'Register-GameCommand',
    'Unregister-GameCommand',
    'Invoke-GameCommand',
    'Get-GameCommand',
    'Get-CommandRegistryStatistics',
    'New-CommandDefinition',
    'New-CommandParameter',
    'New-ParameterConstraint',
    'New-CommandMiddleware'
) -Variable @()

# Module initialization
Write-Host "CommandRegistry module loaded. Call Initialize-CommandRegistry to begin." -ForegroundColor Cyan
