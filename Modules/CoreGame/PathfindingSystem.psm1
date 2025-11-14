# PathfindingSystem.psm1
# Manages unit pathfinding and movement state

using module .\EventSystem.psm1
using module .\StateManager.psm1
using module .\DataModels.psm1
using module .\GameLogging.psm1

# Active movements tracking
$script:ActiveMovements = @{}

function Initialize-PathfindingSystem {
    <#
    .SYNOPSIS
    Initializes the pathfinding system
    #>
    [CmdletBinding()]
    param()

    Write-GameLog -Level Info -Message "Initializing PathfindingSystem"
    $script:ActiveMovements = @{}
    
    # Register events
    Register-GameEvent -EventType 'movement.started' -ScriptBlock {
        param($Data)
        Write-GameLog -Level Info -Message "Movement started: Unit $($Data.UnitId)"
    }
    
    Register-GameEvent -EventType 'movement.completed' -ScriptBlock {
        param($Data)
        Write-GameLog -Level Info -Message "Movement completed: Unit $($Data.UnitId)"
        if ($script:ActiveMovements.ContainsKey($Data.UnitId)) {
            $script:ActiveMovements.Remove($Data.UnitId)
        }
    }
    
    Write-GameLog -Level Info -Message "PathfindingSystem initialized successfully"
}

function Start-UnitMovement {
    <#
    .SYNOPSIS
    Initiates unit movement to a destination
    
    .PARAMETER UnitId
    The ID of the unit to move
    
    .PARAMETER Destination
    Hashtable with Lat and Lng keys
    
    .PARAMETER TravelMode
    How the unit is traveling (foot, car, motorcycle, van, aerial)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UnitId,

        [Parameter(Mandatory)]
        [hashtable]$Destination,

        [ValidateSet('foot', 'car', 'motorcycle', 'van', 'aerial')]
        [string]$TravelMode = 'foot'
    )

    try {
        # Get unit entity
        $unit = Get-GameEntity -Id $UnitId
        
        if (-not $unit) {
            Write-GameLog -Level Error -Message "Unit not found: $UnitId"
            return $false
        }

        # Ensure unit has position
        if (-not $unit.Position) {
            Write-GameLog -Level Warning -Message "Unit $UnitId has no position, cannot move"
            return $false
        }

        # Calculate distance (rough approximation)
        $latDiff = $Destination.Lat - $unit.Position.Lat
        $lngDiff = $Destination.Lng - $unit.Position.Lng
        $distance = [Math]::Sqrt([Math]::Pow($latDiff, 2) + [Math]::Pow($lngDiff, 2)) * 111320 # ~meters

        # Determine pathfinding method
        $pathfindingType = if ($distance -lt 500) {
            'direct' # Short distance: straight line
        } elseif ($TravelMode -eq 'aerial') {
            'direct' # Aerial ignores roads
        } elseif ($TravelMode -eq 'foot' -and $distance -gt 2000) {
            'warning' # Warn about long foot journey
        } else {
            'road' # Use road network
        }

        # Track active movement
        $movement = @{
            UnitId = $UnitId
            Start = $unit.Position
            Destination = $Destination
            TravelMode = $TravelMode
            PathfindingType = $pathfindingType
            StartTime = Get-Date
            Distance = $distance
        }
        
        $script:ActiveMovements[$UnitId] = $movement

        # Send command to frontend for pathfinding
        $command = @{
            Type = 'StartMovement'
            UnitId = $UnitId
            Start = @{
                Lat = $unit.Position.Lat
                Lng = $unit.Position.Lng
            }
            Destination = $Destination
            TravelMode = $TravelMode
            PathfindingType = $pathfindingType
            Distance = $distance
        }

        # Write command to bridge
        $commandJson = $command | ConvertTo-Json -Depth 10 -Compress
        $bridgeDir = Join-Path $PSScriptRoot '..\..\Data\Bridge'
        if (-not (Test-Path $bridgeDir)) {
            New-Item -ItemType Directory -Path $bridgeDir -Force | Out-Null
        }
        
        $commandFile = Join-Path $bridgeDir "cmd_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff').json"
        $commandJson | Out-File -FilePath $commandFile -Encoding utf8 -NoNewline

        # Emit event
        Invoke-GameEvent -EventType 'movement.started' -Data @{
            UnitId = $UnitId
            Destination = $Destination
            TravelMode = $TravelMode
            PathfindingType = $pathfindingType
            Distance = $distance
        }

        Write-GameLog -Level Info -Message "Unit $UnitId moving to [$($Destination.Lat), $($Destination.Lng)] via $TravelMode ($pathfindingType pathfinding, ${distance}m)"
        
        return $true

    } catch {
        Write-GameLog -Level Error -Message "Failed to start movement for unit $UnitId : $_"
        return $false
    }
}

function Update-UnitPosition {
    <#
    .SYNOPSIS
    Updates a unit's position on the map
    
    .PARAMETER UnitId
    The ID of the unit to update
    
    .PARAMETER Position
    Hashtable with Lat and Lng keys
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UnitId,

        [Parameter(Mandatory)]
        [hashtable]$Position
    )

    try {
        # Get unit entity
        $unit = Get-GameEntity -Id $UnitId
        
        if (-not $unit) {
            Write-GameLog -Level Error -Message "Unit not found: $UnitId"
            return $false
        }

        $oldPosition = $unit.Position

        # Update position
        $unit.Position = @{
            Lat = [double]$Position.Lat
            Lng = [double]$Position.Lng
        }

        # Save updated entity
        Set-GameEntity -Entity $unit

        # Emit event
        Invoke-GameEvent -EventType 'unit.positionUpdated' -Data @{
            UnitId = $UnitId
            OldPosition = $oldPosition
            NewPosition = $unit.Position
        }

        Write-GameLog -Level Debug -Message "Unit $UnitId position updated to [$($Position.Lat), $($Position.Lng)]"
        
        return $true

    } catch {
        Write-GameLog -Level Error -Message "Failed to update position for unit $UnitId : $_"
        return $false
    }
}

function Complete-UnitMovement {
    <#
    .SYNOPSIS
    Marks a unit's movement as complete
    
    .PARAMETER UnitId
    The ID of the unit
    
    .PARAMETER FinalPosition
    The final position reached
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UnitId,

        [Parameter(Mandatory)]
        [hashtable]$FinalPosition
    )

    try {
        # Update final position
        $updated = Update-UnitPosition -UnitId $UnitId -Position $FinalPosition
        
        if ($updated) {
            # Remove from active movements
            if ($script:ActiveMovements.ContainsKey($UnitId)) {
                $movement = $script:ActiveMovements[$UnitId]
                $duration = ((Get-Date) - $movement.StartTime).TotalSeconds
                
                Write-GameLog -Level Info -Message "Unit $UnitId completed movement (${duration}s, $($movement.Distance)m)"
                
                $script:ActiveMovements.Remove($UnitId)
            }
            
            # Emit completion event
            Invoke-GameEvent -EventType 'movement.completed' -Data @{
                UnitId = $UnitId
                Position = $FinalPosition
            }
            
            # Check for location-based events
            Test-LocationEvents -UnitId $UnitId -Position $FinalPosition
            
            return $true
        }
        
        return $false

    } catch {
        Write-GameLog -Level Error -Message "Failed to complete movement for unit $UnitId : $_"
        return $false
    }
}

function Test-LocationEvents {
    <#
    .SYNOPSIS
    Checks for events triggered by arriving at a location
    
    .PARAMETER UnitId
    The unit that arrived
    
    .PARAMETER Position
    The position arrived at
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UnitId,

        [Parameter(Mandatory)]
        [hashtable]$Position
    )

    try {
        # Get all locations
        $locations = Get-GameEntity -Type 'Location'
        
        if (-not $locations) {
            return
        }

        # Check for nearby locations (within 50 meters)
        $nearbyLocations = $locations | Where-Object {
            if (-not $_.Position) { return $false }
            
            $latDiff = $Position.Lat - $_.Position.Lat
            $lngDiff = $Position.Lng - $_.Position.Lng
            $dist = [Math]::Sqrt([Math]::Pow($latDiff, 2) + [Math]::Pow($lngDiff, 2)) * 111320
            
            $dist -lt 50
        }

        foreach ($location in $nearbyLocations) {
            Invoke-GameEvent -EventType 'location.entered' -Data @{
                UnitId = $UnitId
                LocationId = $location.Id
                LocationName = $location.Name
                Position = $Position
            }
            
            Write-GameLog -Level Info -Message "Unit $UnitId entered location: $($location.Name)"
        }

        # Random encounter check (5% chance)
        if ((Get-Random -Minimum 0 -Maximum 100) -lt 5) {
            $encounterTypes = @('enemy', 'loot', 'npc', 'event')
            $encounterType = Get-Random -InputObject $encounterTypes
            
            Invoke-GameEvent -EventType 'encounter.random' -Data @{
                UnitId = $UnitId
                Position = $Position
                EncounterType = $encounterType
            }
            
            Write-GameLog -Level Info -Message "Random encounter triggered: $encounterType"
        }

    } catch {
        Write-GameLog -Level Warning -Message "Failed to check location events: $_"
    }
}

function Get-ActiveMovements {
    <#
    .SYNOPSIS
    Gets all currently active unit movements
    #>
    [CmdletBinding()]
    param()

    return $script:ActiveMovements
}

function Stop-UnitMovement {
    <#
    .SYNOPSIS
    Cancels an active unit movement
    
    .PARAMETER UnitId
    The unit to stop
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UnitId
    )

    try {
        if ($script:ActiveMovements.ContainsKey($UnitId)) {
            $script:ActiveMovements.Remove($UnitId)
            
            # Send cancel command to frontend
            $command = @{
                Type = 'StopMovement'
                UnitId = $UnitId
            }
            
            $commandJson = $command | ConvertTo-Json -Depth 10 -Compress
            $bridgeDir = Join-Path $PSScriptRoot '..\..\Data\Bridge'
            $commandFile = Join-Path $bridgeDir "cmd_$(Get-Date -Format 'yyyyMMdd_HHmmss_fff').json"
            $commandJson | Out-File -FilePath $commandFile -Encoding utf8 -NoNewline
            
            Invoke-GameEvent -EventType 'movement.cancelled' -Data @{
                UnitId = $UnitId
            }
            
            Write-GameLog -Level Info -Message "Movement cancelled for unit $UnitId"
            return $true
        }
        
        return $false

    } catch {
        Write-GameLog -Level Error -Message "Failed to stop movement for unit $UnitId : $_"
        return $false
    }
}

Export-ModuleMember -Function @(
    'Initialize-PathfindingSystem',
    'Start-UnitMovement',
    'Update-UnitPosition',
    'Complete-UnitMovement',
    'Test-LocationEvents',
    'Get-ActiveMovements',
    'Stop-UnitMovement'
)
