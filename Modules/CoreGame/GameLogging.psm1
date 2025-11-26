<#
.SYNOPSIS
    Comprehensive game logging system with multi-output support and verbose logging.

.DESCRIPTION
    This module provides standardized logging functionality for the PowerShell Leafmap Game.
    Supports console output, file logging, structured data logging, and verbose output.
    Includes automatic log rotation, performance monitoring, and debug capabilities.

.NOTES
    Author: PowerShell Leafmap Game Development Team
    Version: 1.0.0
    Created: July 31, 2025
#>

# Module-level configuration
$script:LogLevels = @{
    Debug    = 0
    Info     = 1
    Warning  = 2
    Error    = 3
    Critical = 4
    None     = 5
}

$script:LoggingConfig = @{
    MinimumLevel      = $script:LogLevels.Info
    LogToFile         = $true
    LogFilePath       = ".\Logs\game.log"
    LogToConsole      = $true
    IncludeTimestamp  = $true
    MaxLogSizeMB      = 10
    EnableRotation    = $true
    DebugMode         = $false
    VerboseLogging    = $false
    StructuredLogging = $true
    LogFormat         = "Standard"  # Standard, JSON, Structured
}

$script:LogStats = @{
    TotalLogs        = 0
    ErrorCount       = 0
    WarningCount     = 0
    LastLogTime      = $null
    SessionStartTime = Get-Date
}

# Ensure logs directory exists
$logDir = Split-Path $script:LoggingConfig.LogFilePath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

<#
.SYNOPSIS
    Initializes the game logging system.

.DESCRIPTION
    Prepares the logging system for use. This function ensures the log directory
    exists and resets log statistics. It's automatically called when the module
    is imported, but can be called again to reset the logging system.

.EXAMPLE
    Initialize-GameLogging

.NOTES
    This function is idempotent and safe to call multiple times.
#>
function Initialize-GameLogging {
    [CmdletBinding()]
    param()

    # Ensure logs directory exists
    $logDir = Split-Path $script:LoggingConfig.LogFilePath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Reset statistics
    $script:LogStats.SessionStartTime = Get-Date
    $script:LogStats.LastLogTime = $null

    Write-GameLog -Message "Game logging system initialized" -Level Info -Module "Logging"
}

<#
.SYNOPSIS
    Writes a standardized log message with multiple output options.

.DESCRIPTION
    Central logging function that supports console output, file logging, verbose output,
    and structured data. Automatically handles log rotation and performance tracking.

.PARAMETER Message
    The primary log message to write.

.PARAMETER Level
    The severity level of the log message.

.PARAMETER Module
    The module or component generating the log message.

.PARAMETER Data
    Additional structured data to include with the log message.

.PARAMETER ToFile
    Whether to write this message to the log file.

.PARAMETER ToConsole
    Whether to write this message to the console.

.PARAMETER Exception
    An exception object to include in the log message.

.EXAMPLE
    Write-GameLog -Message "Player connected" -Level Info -Module "ConnectionManager"

.EXAMPLE
    Write-GameLog -Message "Database error" -Level Error -Module "StateManager" -Exception $_ -Data @{PlayerId="123"} -Verbose

.NOTES
    This function is the primary interface for all game logging.
#>
function Write-GameLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Debug", "Info", "Warning", "Error", "Critical")]
        [string]$Level = "Info",

        [Parameter(Mandatory = $false)]
        [string]$Module = "Core",

        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{},

        [Parameter(Mandatory = $false)]
        [switch]$ToFile,

        [Parameter(Mandatory = $false)]
        [switch]$ToConsole,

        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception
    )

    try {
        # Check if we should log this level
        if ($script:LogLevels[$Level] -lt $script:LoggingConfig.MinimumLevel) {
            return
        }

        # Build log entry
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = @{
            Timestamp = $timestamp
            Level     = $Level
            Module    = $Module
            Message   = $Message
            Data      = $Data
            ThreadId  = [System.Threading.Thread]::CurrentThread.ManagedThreadId
            ProcessId = $PID
        }

        # Add exception details if provided
        if ($Exception) {
            $logEntry.Exception = @{
                Type       = $Exception.GetType().Name
                Message    = $Exception.Message
                StackTrace = $Exception.StackTrace
            }
        }

        # Format message for output
        $formattedMessage = Format-LogMessage -LogEntry $logEntry

        # Determine output destinations
        $shouldLogToConsole = $ToConsole -or ($script:LoggingConfig.LogToConsole -and $VerbosePreference -eq 'SilentlyContinue')
        $shouldLogToFile = $ToFile -or $script:LoggingConfig.LogToFile
        $shouldLogVerbose = ($VerbosePreference -ne 'SilentlyContinue') -or $script:LoggingConfig.VerboseLogging

        # Console output
        if ($shouldLogToConsole) {
            Write-LogToConsole -Message $formattedMessage -Level $Level
        }

        # Verbose output
        if ($shouldLogVerbose) {
            Write-Verbose $formattedMessage
        }

        # File output
        if ($shouldLogToFile) {
            Write-LogToFile -LogEntry $logEntry -FormattedMessage $formattedMessage
        }

        # Update statistics
        Update-LogStatistics -Level $Level

    }
    catch {
        # Fallback error handling - avoid infinite recursion
        Write-Error "Logging system error: $_"
    }
}

<#
.SYNOPSIS
    Formats a log entry according to the configured format.

.DESCRIPTION
    Internal function that formats log entries for different output destinations.
#>
function Format-LogMessage {
    param(
        [hashtable]$LogEntry
    )

    switch ($script:LoggingConfig.LogFormat) {
        "JSON" {
            return $LogEntry | ConvertTo-Json -Compress
        }
        "Structured" {
            $dataStr = if ($LogEntry.Data.Count -gt 0) { " | Data: $($LogEntry.Data | ConvertTo-Json -Compress)" } else { "" }
            return "[$($LogEntry.Timestamp)] [$($LogEntry.Level)] [$($LogEntry.Module)] $($LogEntry.Message)$dataStr"
        }
        default {
            return "[$($LogEntry.Timestamp)] [$($LogEntry.Level)] [$($LogEntry.Module)] $($LogEntry.Message)"
        }
    }
}

<#
.SYNOPSIS
    Writes a formatted message to the console with appropriate colors.
#>
function Write-LogToConsole {
    param(
        [string]$Message,
        [string]$Level
    )

    $color = switch ($Level) {
        "Debug" { "Gray" }
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Critical" { "Magenta" }
        default { "White" }
    }

    Write-Host $Message -ForegroundColor $color
}

<#
.SYNOPSIS
    Writes a log entry to the configured log file.
#>
function Write-LogToFile {
    param(
        [hashtable]$LogEntry,
        [string]$FormattedMessage
    )

    try {
        # Check if log rotation is needed
        if ($script:LoggingConfig.EnableRotation) {
            Test-LogRotation
        }

        # Write to file
        $FormattedMessage | Add-Content -Path $script:LoggingConfig.LogFilePath -Encoding UTF8

    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

<#
.SYNOPSIS
    Checks if log rotation is needed and performs it if necessary.
#>
function Test-LogRotation {
    if (-not (Test-Path $script:LoggingConfig.LogFilePath)) {
        return
    }

    $fileInfo = Get-Item $script:LoggingConfig.LogFilePath
    $fileSizeMB = $fileInfo.Length / 1MB

    if ($fileSizeMB -gt $script:LoggingConfig.MaxLogSizeMB) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $directory = Split-Path $script:LoggingConfig.LogFilePath -Parent
        $filename = Split-Path $script:LoggingConfig.LogFilePath -LeafBase
        $extension = Split-Path $script:LoggingConfig.LogFilePath -Extension

        $rotatedName = Join-Path $directory "$filename`_$timestamp$extension"
        Move-Item $script:LoggingConfig.LogFilePath $rotatedName

        Write-GameLog -Message "Log rotated to: $rotatedName" -Level Info -Module "Logging"
    }
}

<#
.SYNOPSIS
    Updates internal logging statistics.
#>
function Update-LogStatistics {
    param([string]$Level)

    $script:LogStats.TotalLogs++
    $script:LogStats.LastLogTime = Get-Date

    switch ($Level) {
        "Error" { $script:LogStats.ErrorCount++ }
        "Critical" { $script:LogStats.ErrorCount++ }
        "Warning" { $script:LogStats.WarningCount++ }
    }
}

<#
.SYNOPSIS
    Configures the logging system settings.

.DESCRIPTION
    Updates the logging configuration with new settings. Allows dynamic
    reconfiguration of logging behavior without restarting the system.

.PARAMETER Config
    A hashtable containing logging configuration settings.

.EXAMPLE
    Set-LoggingConfig -Config @{
        MinimumLevel = "Debug"
        LogToFile = $true
        VerboseLogging = $true
    }
#>
function Set-LoggingConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    foreach ($key in $Config.Keys) {
        if ($script:LoggingConfig.ContainsKey($key)) {
            $script:LoggingConfig[$key] = $Config[$key]
            Write-GameLog -Message "Updated logging config: $key = $($Config[$key])" -Level Debug -Module "Logging"
        }
    }
}

<#
.SYNOPSIS
    Gets current logging configuration and statistics.

.DESCRIPTION
    Returns comprehensive information about the current logging system state.

.EXAMPLE
    $logInfo = Get-LoggingInfo
    Write-Host "Total logs: $($logInfo.Statistics.TotalLogs)"
#>
function Get-LoggingInfo {
    [CmdletBinding()]
    param()

    return @{
        Configuration = $script:LoggingConfig.Clone()
        Statistics    = $script:LogStats.Clone()
        Levels        = $script:LogLevels.Clone()
    }
}

<#
.SYNOPSIS
    Enables debug mode for enhanced logging.
#>
function Enable-DebugLogging {
    [CmdletBinding()]
    param()

    $script:LoggingConfig.MinimumLevel = $script:LogLevels.Debug
    $script:LoggingConfig.DebugMode = $true
    $script:LoggingConfig.VerboseLogging = $true

    Write-GameLog -Message "Debug logging enabled" -Level Info -Module "Logging"
}

<#
.SYNOPSIS
    Disables debug mode and returns to normal logging.
#>
function Disable-DebugLogging {
    [CmdletBinding()]
    param()

    $script:LoggingConfig.MinimumLevel = $script:LogLevels.Info
    $script:LoggingConfig.DebugMode = $false
    $script:LoggingConfig.VerboseLogging = $false

    Write-GameLog -Message "Debug logging disabled" -Level Info -Module "Logging"
}

<#
.SYNOPSIS
    Convenience function for debug logging.
#>
function Write-DebugLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Module = "Core",

        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{}
    )

    Write-GameLog -Message $Message -Level Debug -Module $Module -Data $Data -Verbose
}

<#
.SYNOPSIS
    Convenience function for error logging with exception support.
#>
function Write-ErrorLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Module = "Core",

        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception,

        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{}
    )

    Write-GameLog -Message $Message -Level Error -Module $Module -Exception $Exception -Data $Data -ToConsole -ToFile
}

# Initialize logging on module import
Write-GameLog -Message "Game logging system initialized" -Level Info -Module "Logging" -Data @{
    Version    = "1.0.0"
    ConfigFile = $script:LoggingConfig.LogFilePath
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-GameLogging',
    'Write-GameLog',
    'Set-LoggingConfig',
    'Get-LoggingInfo',
    'Enable-DebugLogging',
    'Disable-DebugLogging',
    'Write-DebugLog',
    'Write-ErrorLog'
)
