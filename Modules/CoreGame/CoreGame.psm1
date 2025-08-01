# CoreGame Module - Core game engine functionality

# Event management system
$Global:GameEvents = @{}

function Initialize-GameEngine {
    param(
        [string]$ConfigPath = ".\Data\config.json",
        [switch]$DebugMode
    )
    
    Write-Host "Initializing game engine..."
    # Implementation will go here
    
    # Initialize event system
    $Global:GameEvents = @{}
    
    # Return engine configuration
    return @{
        Initialized = $true
        DebugMode = $DebugMode
        ConfigPath = $ConfigPath
    }
}

function Register-GameEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EventName,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$Handler
    )
    
    if (-not $Global:GameEvents.ContainsKey($EventName)) {
        $Global:GameEvents[$EventName] = @()
    }
    
    $Global:GameEvents[$EventName] += $Handler
    return $Handler
}

function Invoke-GameEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EventName,
        
        [hashtable]$EventData = @{}
    )
    
    if ($Global:GameEvents.ContainsKey($EventName)) {
        foreach ($handler in $Global:GameEvents[$EventName]) {
            $handler.Invoke($EventData)
        }
    }
}

function Save-GameState {
    param(
        [string]$SaveName = "default",
        [hashtable]$GameState
    )
    
    $savePath = ".\Data\Saves"
    if (-not (Test-Path $savePath)) {
        New-Item -ItemType Directory -Path $savePath -Force | Out-Null
    }
    
    $saveFile = Join-Path -Path $savePath -ChildPath "$SaveName.json"
    $GameState | ConvertTo-Json -Depth 10 | Out-File -FilePath $saveFile
    return $saveFile
}

function Get-GameState {
    param(
        [string]$SaveName = "default"
    )
    
    $savePath = ".\Data\Saves"
    $saveFile = Join-Path -Path $savePath -ChildPath "$SaveName.json"
    
    if (Test-Path $saveFile) {
        $content = Get-Content -Path $saveFile -Raw
        return $content | ConvertFrom-Json -AsHashtable
    }
    
    return $null
}

# Export all functions
Export-ModuleMember -Function Initialize-GameEngine, Register-GameEvent, Invoke-GameEvent, Save-GameState, Get-GameState
