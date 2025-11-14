# CommunicationBridge.psm1
# Handles bidirectional communication between PowerShell and JavaScript

using module .\GameLogging.psm1
using module .\EventSystem.psm1

# Bridge configuration
$script:BridgeConfig = @{
    CommandsDirectory = '.\Data\Bridge'
    ProcessedDirectory = '.\Data\Bridge\Processed'
    EventsDirectory = '.\Data\Bridge\Events'
    PollInterval = 100 # milliseconds
    MaxCommandAge = 300 # seconds
    IsInitialized = $false
}

function Initialize-CommunicationBridge {
    <#
    .SYNOPSIS
    Initializes the communication bridge
    #>
    [CmdletBinding()]
    param()

    Write-GameLog -Level Info -Message "Initializing CommunicationBridge"

    # Create directories
    $dirs = @(
        $script:BridgeConfig.CommandsDirectory,
        $script:BridgeConfig.ProcessedDirectory,
        $script:BridgeConfig.EventsDirectory
    )

    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    $script:BridgeConfig.IsInitialized = $true
    Write-GameLog -Level Info -Message "CommunicationBridge initialized successfully"
}

function Send-BridgeCommand {
    <#
    .SYNOPSIS
    Sends a command to the JavaScript frontend
    
    .PARAMETER Command
    Hashtable containing command data
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Command
    )

    try {
        if (-not $script:BridgeConfig.IsInitialized) {
            Initialize-CommunicationBridge
        }

        $commandJson = $Command | ConvertTo-Json -Depth 10 -Compress
        $commandFile = Join-Path $script:BridgeConfig.EventsDirectory "cmd_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff').json"
        $commandJson | Out-File -FilePath $commandFile -Encoding utf8 -NoNewline

        Write-GameLog -Level Debug -Message "Sent bridge command: $($Command.Type)"
        return $true

    } catch {
        Write-GameLog -Level Error -Message "Failed to send bridge command: $_"
        return $false
    }
}

function Receive-BridgeCommands {
    <#
    .SYNOPSIS
    Receives commands from the JavaScript frontend
    
    .OUTPUTS
    Array of command objects
    #>
    [CmdletBinding()]
    param()

    try {
        if (-not $script:BridgeConfig.IsInitialized) {
            Initialize-CommunicationBridge
        }

        $commands = @()
        $commandFiles = Get-ChildItem -Path $script:BridgeConfig.CommandsDirectory -Filter "cmd_*.json" -ErrorAction SilentlyContinue

        foreach ($file in $commandFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
                $command = $content | ConvertFrom-Json -AsHashtable -ErrorAction Stop

                # Check command age
                $fileAge = (Get-Date) - $file.CreationTime
                if ($fileAge.TotalSeconds -lt $script:BridgeConfig.MaxCommandAge) {
                    $commands += $command
                }

                # Move to processed
                $processedPath = Join-Path $script:BridgeConfig.ProcessedDirectory $file.Name
                Move-Item -Path $file.FullName -Destination $processedPath -Force -ErrorAction SilentlyContinue

            } catch {
                Write-GameLog -Level Warning -Message "Failed to process command file $($file.Name): $_"
            }
        }

        return $commands

    } catch {
        Write-GameLog -Level Error -Message "Failed to receive bridge commands: $_"
        return @()
    }
}

function Send-BridgeEvent {
    <#
    .SYNOPSIS
    Sends an event to the JavaScript frontend
    
    .PARAMETER EventType
    Type of event
    
    .PARAMETER Data
    Event data
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventType,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    $event = @{
        Type = $EventType
        Data = $Data
        Timestamp = Get-Date -Format 'o'
    }

    return Send-BridgeCommand -Command $event
}

function Clear-OldBridgeFiles {
    <#
    .SYNOPSIS
    Clears old bridge files to prevent buildup
    
    .PARAMETER MaxAgeMinutes
    Maximum age in minutes for files to keep
    #>
    [CmdletBinding()]
    param(
        [int]$MaxAgeMinutes = 60
    )

    try {
        $cutoffTime = (Get-Date).AddMinutes(-$MaxAgeMinutes)

        $dirs = @(
            $script:BridgeConfig.CommandsDirectory,
            $script:BridgeConfig.ProcessedDirectory,
            $script:BridgeConfig.EventsDirectory
        )

        foreach ($dir in $dirs) {
            if (Test-Path $dir) {
                Get-ChildItem -Path $dir -File | 
                    Where-Object { $_.CreationTime -lt $cutoffTime } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }

        Write-GameLog -Level Debug -Message "Cleared old bridge files"

    } catch {
        Write-GameLog -Level Warning -Message "Failed to clear old bridge files: $_"
    }
}

Export-ModuleMember -Function @(
    'Initialize-CommunicationBridge',
    'Send-BridgeCommand',
    'Receive-BridgeCommands',
    'Send-BridgeEvent',
    'Clear-OldBridgeFiles'
)
