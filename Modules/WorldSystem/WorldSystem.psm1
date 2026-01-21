# WorldSystem Module - Comprehensive world and map management for cyberpunk RPG
# Provides: Locations, Districts, Time/Weather, Travel, World State, POIs
# Depends on: CoreGame (StateManager, EventSystem)

# ============================================
# Module Variables
# ============================================
$script:WorldSystemInitialized = $false
$script:WorldConfig = @{
    DefaultMapType = "Outdoor"
    MaxMapPoints = 1000
    MaxLayers = 50
    TimeScale = 60              # 1 real second = 60 game seconds (1 minute)
    DayStartHour = 6
    NightStartHour = 20
    WeatherChangeProbability = 0.1
    RandomEncounterProbability = 0.15
    TravelSpeedKmPerHour = 30   # Default walking/public transport speed
}

# World state
$script:WorldState = @{
    CurrentTime = $null
    CurrentWeather = 'Clear'
    ActiveDistricts = @{}
    LoadedMaps = @{}
    Locations = @{}
    ActiveEvents = @()
    TravelQueue = @()
}

# Weather types with effects
$script:WeatherTypes = @{
    Clear = @{
        Name = 'Clear'
        Description = 'Clear skies with light pollution haze'
        VisibilityModifier = 1.0
        MovementModifier = 1.0
        StealthModifier = 0.9
        MoodModifier = 'Neutral'
    }
    Rain = @{
        Name = 'Rain'
        Description = 'Steady rain reflecting neon lights'
        VisibilityModifier = 0.7
        MovementModifier = 0.9
        StealthModifier = 1.1
        MoodModifier = 'Melancholy'
    }
    HeavyRain = @{
        Name = 'HeavyRain'
        Description = 'Torrential downpour, streets flooding'
        VisibilityModifier = 0.4
        MovementModifier = 0.7
        StealthModifier = 1.3
        MoodModifier = 'Tense'
    }
    Fog = @{
        Name = 'Fog'
        Description = 'Thick smog rolling through the streets'
        VisibilityModifier = 0.5
        MovementModifier = 0.95
        StealthModifier = 1.4
        MoodModifier = 'Mysterious'
    }
    AcidRain = @{
        Name = 'AcidRain'
        Description = 'Toxic precipitation - stay indoors'
        VisibilityModifier = 0.6
        MovementModifier = 0.5
        StealthModifier = 1.0
        MoodModifier = 'Dangerous'
        DamagePerMinute = 1
    }
    Sandstorm = @{
        Name = 'Sandstorm'
        Description = 'Dust and debris from the wastelands'
        VisibilityModifier = 0.3
        MovementModifier = 0.6
        StealthModifier = 1.2
        MoodModifier = 'Apocalyptic'
    }
}

# District templates
$script:DistrictTypes = @{
    Corporate = @{
        SecurityLevel = 'High'
        WealthLevel = 'Rich'
        PolicePresence = 'Heavy'
        GangPresence = 'None'
        ShopPriceModifier = 1.5
        RandomEncounterTypes = @('Corporate Security', 'Street Preacher', 'Protestor')
    }
    Residential = @{
        SecurityLevel = 'Medium'
        WealthLevel = 'Middle'
        PolicePresence = 'Moderate'
        GangPresence = 'Low'
        ShopPriceModifier = 1.0
        RandomEncounterTypes = @('Street Vendor', 'Mugger', 'Lost Tourist')
    }
    Industrial = @{
        SecurityLevel = 'Low'
        WealthLevel = 'Poor'
        PolicePresence = 'Rare'
        GangPresence = 'High'
        ShopPriceModifier = 0.8
        RandomEncounterTypes = @('Gang Patrol', 'Scavenger', 'Smuggler')
    }
    Slum = @{
        SecurityLevel = 'None'
        WealthLevel = 'Destitute'
        PolicePresence = 'None'
        GangPresence = 'Very High'
        ShopPriceModifier = 0.6
        RandomEncounterTypes = @('Gang Ambush', 'Desperate Beggar', 'Black Market Dealer')
    }
    Entertainment = @{
        SecurityLevel = 'Medium'
        WealthLevel = 'Mixed'
        PolicePresence = 'Moderate'
        GangPresence = 'Moderate'
        ShopPriceModifier = 1.2
        RandomEncounterTypes = @('Drunk Patron', 'Street Performer', 'Fixer', 'Joytoy')
    }
    Docks = @{
        SecurityLevel = 'Low'
        WealthLevel = 'Poor'
        PolicePresence = 'Rare'
        GangPresence = 'High'
        ShopPriceModifier = 0.7
        RandomEncounterTypes = @('Smuggler', 'Dockworker', 'Customs Agent')
    }
}

# Location types
$script:LocationTypes = @{
    SafeHouse = @{
        CanRest = $true
        CanStore = $true
        CanCraft = $false
        IsPublic = $false
    }
    Shop = @{
        CanRest = $false
        CanStore = $false
        CanCraft = $false
        IsPublic = $true
        HasInventory = $true
    }
    Bar = @{
        CanRest = $false
        CanStore = $false
        CanCraft = $false
        IsPublic = $true
        HasNPCs = $true
        CanGatherInfo = $true
    }
    Clinic = @{
        CanRest = $true
        CanStore = $false
        CanCraft = $false
        IsPublic = $true
        CanHeal = $true
    }
    Workshop = @{
        CanRest = $false
        CanStore = $true
        CanCraft = $true
        IsPublic = $false
    }
    MissionSite = @{
        CanRest = $false
        CanStore = $false
        CanCraft = $false
        IsPublic = $false
        IsDangerous = $true
    }
    Street = @{
        CanRest = $false
        CanStore = $false
        CanCraft = $false
        IsPublic = $true
        HasRandomEncounters = $true
    }
    Hideout = @{
        CanRest = $true
        CanStore = $true
        CanCraft = $true
        IsPublic = $false
        IsHidden = $true
    }
}

# ============================================
# Initialization
# ============================================
function Initialize-WorldSystem {
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{},
        [datetime]$StartTime = (Get-Date "2042-06-15 18:00:00")
    )
    
    # Merge custom configuration
    foreach ($key in $Configuration.Keys) {
        if ($script:WorldConfig.ContainsKey($key)) {
            $script:WorldConfig[$key] = $Configuration[$key]
        }
    }
    
    # Initialize world time
    $script:WorldState.CurrentTime = $StartTime
    $script:WorldState.CurrentWeather = 'Clear'
    $script:WorldState.ActiveDistricts = @{}
    $script:WorldState.Locations = @{}
    
    $script:WorldSystemInitialized = $true
    
    # Fire initialization event
    if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'world.initialized' -Data @{
            StartTime = $StartTime
            Weather = 'Clear'
        }
    }
    
    Write-Verbose "WorldSystem initialized at game time: $StartTime"
    
    return @{
        Initialized = $true
        ModuleName = 'WorldSystem'
        Configuration = $script:WorldConfig
        GameTime = $StartTime
    }
}

# ============================================
# Time System Functions
# ============================================
function Get-GameTime {
    <#
    .SYNOPSIS
        Gets the current in-game time
    #>
    [CmdletBinding()]
    param()
    
    return $script:WorldState.CurrentTime
}

function Set-GameTime {
    <#
    .SYNOPSIS
        Sets the current in-game time
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [datetime]$Time
    )
    
    $oldTime = $script:WorldState.CurrentTime
    $script:WorldState.CurrentTime = $Time
    
    # Check for day/night transition
    $wasNight = ($oldTime.Hour -ge $script:WorldConfig.NightStartHour -or $oldTime.Hour -lt $script:WorldConfig.DayStartHour)
    $isNight = ($Time.Hour -ge $script:WorldConfig.NightStartHour -or $Time.Hour -lt $script:WorldConfig.DayStartHour)
    
    if ($wasNight -ne $isNight) {
        $transitionType = if ($isNight) { 'NightFall' } else { 'Dawn' }
        if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
            $null = Send-GameEvent -EventType 'world.timeTransition' -Data @{
                TransitionType = $transitionType
                NewTime = $Time
            }
        }
    }
    
    return $Time
}

function Advance-GameTime {
    <#
    .SYNOPSIS
        Advances game time by specified amount
    #>
    [CmdletBinding()]
    param(
        [int]$Minutes = 0,
        [int]$Hours = 0,
        [int]$Days = 0
    )
    
    $newTime = $script:WorldState.CurrentTime.AddMinutes($Minutes).AddHours($Hours).AddDays($Days)
    
    # Check for weather changes during time advance
    $hoursAdvanced = ($newTime - $script:WorldState.CurrentTime).TotalHours
    if ($hoursAdvanced -ge 1 -and (Get-Random -Minimum 0.0 -Maximum 1.0) -lt $script:WorldConfig.WeatherChangeProbability) {
        $null = Set-Weather -Random
    }
    
    return Set-GameTime -Time $newTime
}

function Get-TimeOfDay {
    <#
    .SYNOPSIS
        Gets the current time of day period
    #>
    [CmdletBinding()]
    param()
    
    $hour = $script:WorldState.CurrentTime.Hour
    
    $period = switch ($hour) {
        { $_ -ge 5 -and $_ -lt 8 } { 'Dawn' }
        { $_ -ge 8 -and $_ -lt 12 } { 'Morning' }
        { $_ -ge 12 -and $_ -lt 14 } { 'Noon' }
        { $_ -ge 14 -and $_ -lt 17 } { 'Afternoon' }
        { $_ -ge 17 -and $_ -lt 20 } { 'Evening' }
        { $_ -ge 20 -and $_ -lt 23 } { 'Night' }
        default { 'LateNight' }
    }
    
    return @{
        Period = $period
        Hour = $hour
        IsNight = ($hour -ge $script:WorldConfig.NightStartHour -or $hour -lt $script:WorldConfig.DayStartHour)
        LightLevel = [Math]::Max(0.2, 1.0 - [Math]::Abs($hour - 12) / 12.0)
    }
}

# ============================================
# Weather System Functions
# ============================================
function Get-Weather {
    <#
    .SYNOPSIS
        Gets the current weather conditions
    #>
    [CmdletBinding()]
    param()
    
    $weatherName = $script:WorldState.CurrentWeather
    $weatherData = $script:WeatherTypes[$weatherName]
    
    return @{
        Name = $weatherName
        Description = $weatherData.Description
        VisibilityModifier = $weatherData.VisibilityModifier
        MovementModifier = $weatherData.MovementModifier
        StealthModifier = $weatherData.StealthModifier
        MoodModifier = $weatherData.MoodModifier
        DamagePerMinute = if ($weatherData.DamagePerMinute) { $weatherData.DamagePerMinute } else { 0 }
    }
}

function Set-Weather {
    <#
    .SYNOPSIS
        Sets the current weather
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='Specific')]
        [ValidateSet('Clear', 'Rain', 'HeavyRain', 'Fog', 'AcidRain', 'Sandstorm')]
        [string]$Weather,
        
        [Parameter(ParameterSetName='Random')]
        [switch]$Random
    )
    
    $newWeather = $Weather
    
    if ($Random) {
        # Weighted random - clear is more common
        $roll = Get-Random -Minimum 0 -Maximum 100
        $newWeather = switch ($roll) {
            { $_ -lt 40 } { 'Clear'; break }
            { $_ -lt 65 } { 'Rain'; break }
            { $_ -lt 75 } { 'Fog'; break }
            { $_ -lt 85 } { 'HeavyRain'; break }
            { $_ -lt 95 } { 'Sandstorm'; break }
            default { 'AcidRain' }
        }
    }
    
    $oldWeather = $script:WorldState.CurrentWeather
    $script:WorldState.CurrentWeather = $newWeather
    
    if ($oldWeather -ne $newWeather) {
        if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
            $null = Send-GameEvent -EventType 'world.weatherChanged' -Data @{
                OldWeather = $oldWeather
                NewWeather = $newWeather
                Time = $script:WorldState.CurrentTime
            }
        }
    }
    
    return Get-Weather
}

# ============================================
# District Functions
# ============================================
function New-District {
    <#
    .SYNOPSIS
        Creates a new district in the world
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateSet('Corporate', 'Residential', 'Industrial', 'Slum', 'Entertainment', 'Docks')]
        [string]$Type,
        
        [string]$Description = '',
        
        [hashtable]$Boundaries = @{
            North = 0; South = 0; East = 0; West = 0
        },
        
        [string]$ControllingFaction = 'None',
        
        [int]$DangerLevel = 1,  # 1-10 scale
        
        [hashtable]$CustomProperties = @{}
    )
    
    $typeDefaults = $script:DistrictTypes[$Type]
    
    $district = @{
        Id = $Id
        Name = $Name
        Type = $Type
        Description = $Description
        Boundaries = $Boundaries
        ControllingFaction = $ControllingFaction
        DangerLevel = [Math]::Min(10, [Math]::Max(1, $DangerLevel))
        SecurityLevel = $typeDefaults.SecurityLevel
        WealthLevel = $typeDefaults.WealthLevel
        PolicePresence = $typeDefaults.PolicePresence
        GangPresence = $typeDefaults.GangPresence
        ShopPriceModifier = $typeDefaults.ShopPriceModifier
        RandomEncounterTypes = $typeDefaults.RandomEncounterTypes
        Locations = @()
        IsDiscovered = $false
        VisitCount = 0
        CreatedAt = Get-Date
        Properties = $CustomProperties
    }
    
    $script:WorldState.ActiveDistricts[$Id] = $district
    
    if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'district.created' -Data @{
            DistrictId = $Id
            Name = $Name
            Type = $Type
        }
    }
    
    return $district
}

function Get-District {
    <#
    .SYNOPSIS
        Gets a district by ID or returns all districts
    #>
    [CmdletBinding()]
    param(
        [string]$Id,
        [switch]$All
    )
    
    if ($All) {
        return $script:WorldState.ActiveDistricts.Values
    }
    
    if ($script:WorldState.ActiveDistricts.ContainsKey($Id)) {
        return $script:WorldState.ActiveDistricts[$Id]
    }
    
    return $null
}

function Set-DistrictControl {
    <#
    .SYNOPSIS
        Changes the controlling faction of a district
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DistrictId,
        
        [Parameter(Mandatory)]
        [string]$FactionId
    )
    
    $district = Get-District -Id $DistrictId
    if (-not $district) {
        Write-Warning "District '$DistrictId' not found"
        return $null
    }
    
    $oldFaction = $district.ControllingFaction
    $district.ControllingFaction = $FactionId
    
    if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'district.controlChanged' -Data @{
            DistrictId = $DistrictId
            OldFaction = $oldFaction
            NewFaction = $FactionId
        }
    }
    
    return $district
}

# ============================================
# Location Functions
# ============================================
function New-Location {
    <#
    .SYNOPSIS
        Creates a new location/POI in the world
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateSet('SafeHouse', 'Shop', 'Bar', 'Clinic', 'Workshop', 'MissionSite', 'Street', 'Hideout')]
        [string]$Type,
        
        [string]$DistrictId,
        
        [string]$Description = '',
        
        [double]$Latitude = 0,
        [double]$Longitude = 0,
        
        [string]$OwnerId = '',
        
        [hashtable]$CustomProperties = @{}
    )
    
    $typeDefaults = $script:LocationTypes[$Type]
    
    $location = @{
        Id = $Id
        Name = $Name
        Type = $Type
        DistrictId = $DistrictId
        Description = $Description
        Latitude = $Latitude
        Longitude = $Longitude
        OwnerId = $OwnerId
        CanRest = $typeDefaults.CanRest
        CanStore = $typeDefaults.CanStore
        CanCraft = $typeDefaults.CanCraft
        IsPublic = $typeDefaults.IsPublic
        IsDiscovered = $false
        IsAccessible = $true
        VisitCount = 0
        NPCs = @()
        Items = @()
        Connections = @()  # Connected locations for travel
        CreatedAt = Get-Date
        Properties = $CustomProperties
    }
    
    # Add type-specific properties
    if ($typeDefaults.HasInventory) { $location.Inventory = @() }
    if ($typeDefaults.HasNPCs) { $location.HasNPCs = $true }
    if ($typeDefaults.CanGatherInfo) { $location.CanGatherInfo = $true }
    if ($typeDefaults.CanHeal) { $location.CanHeal = $true }
    if ($typeDefaults.IsDangerous) { $location.IsDangerous = $true }
    if ($typeDefaults.HasRandomEncounters) { $location.HasRandomEncounters = $true }
    if ($typeDefaults.IsHidden) { $location.IsHidden = $true }
    
    $script:WorldState.Locations[$Id] = $location
    
    # Add to district if specified
    if ($DistrictId -and $script:WorldState.ActiveDistricts.ContainsKey($DistrictId)) {
        $script:WorldState.ActiveDistricts[$DistrictId].Locations += $Id
    }
    
    if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'location.created' -Data @{
            LocationId = $Id
            Name = $Name
            Type = $Type
            DistrictId = $DistrictId
        }
    }
    
    return $location
}

function Get-Location {
    <#
    .SYNOPSIS
        Gets a location by ID or returns all locations
    #>
    [CmdletBinding()]
    param(
        [string]$Id,
        [string]$DistrictId,
        [string]$Type,
        [switch]$All,
        [switch]$DiscoveredOnly
    )
    
    $locations = $script:WorldState.Locations.Values
    
    if ($Id) {
        return $script:WorldState.Locations[$Id]
    }
    
    if ($DistrictId) {
        $locations = $locations | Where-Object { $_.DistrictId -eq $DistrictId }
    }
    
    if ($Type) {
        $locations = $locations | Where-Object { $_.Type -eq $Type }
    }
    
    if ($DiscoveredOnly) {
        $locations = $locations | Where-Object { $_.IsDiscovered }
    }
    
    if ($All -or $DistrictId -or $Type) {
        return @($locations)
    }
    
    return $null
}

function Set-LocationDiscovered {
    <#
    .SYNOPSIS
        Marks a location as discovered
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LocationId
    )
    
    $location = Get-Location -Id $LocationId
    if (-not $location) {
        Write-Warning "Location '$LocationId' not found"
        return $null
    }
    
    if (-not $location.IsDiscovered) {
        $location.IsDiscovered = $true
        
        if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
            $null = Send-GameEvent -EventType 'location.discovered' -Data @{
                LocationId = $LocationId
                Name = $location.Name
                Type = $location.Type
            }
        }
    }
    
    return $location
}

function Connect-Locations {
    <#
    .SYNOPSIS
        Creates a connection between two locations for travel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FromLocationId,
        
        [Parameter(Mandatory)]
        [string]$ToLocationId,
        
        [double]$Distance = 1.0,  # km
        
        [string]$TravelMethod = 'Walk',
        
        [switch]$OneWay
    )
    
    $fromLocation = Get-Location -Id $FromLocationId
    $toLocation = Get-Location -Id $ToLocationId
    
    if (-not $fromLocation -or -not $toLocation) {
        Write-Warning "One or both locations not found"
        return $false
    }
    
    $connection = @{
        TargetId = $ToLocationId
        Distance = $Distance
        TravelMethod = $TravelMethod
    }
    
    $fromLocation.Connections += $connection
    
    if (-not $OneWay) {
        $reverseConnection = @{
            TargetId = $FromLocationId
            Distance = $Distance
            TravelMethod = $TravelMethod
        }
        $toLocation.Connections += $reverseConnection
    }
    
    return $true
}

# ============================================
# Travel System Functions
# ============================================
function Start-Travel {
    <#
    .SYNOPSIS
        Initiates travel from current location to destination
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FromLocationId,
        
        [Parameter(Mandatory)]
        [string]$ToLocationId,
        
        [string]$CharacterId,
        
        [ValidateSet('Walk', 'Vehicle', 'FastTravel', 'Stealth')]
        [string]$Method = 'Walk'
    )
    
    $fromLocation = Get-Location -Id $FromLocationId
    $toLocation = Get-Location -Id $ToLocationId
    
    if (-not $fromLocation -or -not $toLocation) {
        return @{
            Success = $false
            Error = "Invalid location(s)"
        }
    }
    
    if (-not $toLocation.IsAccessible) {
        return @{
            Success = $false
            Error = "Destination is not accessible"
        }
    }
    
    # Calculate distance
    $connection = $fromLocation.Connections | Where-Object { $_.TargetId -eq $ToLocationId } | Select-Object -First 1
    
    if ($connection) {
        $distance = $connection.Distance
    } else {
        # Calculate straight-line distance if no connection
        $latDiff = $toLocation.Latitude - $fromLocation.Latitude
        $lonDiff = $toLocation.Longitude - $fromLocation.Longitude
        $distance = [Math]::Sqrt($latDiff * $latDiff + $lonDiff * $lonDiff) * 111  # rough km conversion
        $distance = [Math]::Max(0.5, $distance)  # minimum 0.5 km
    }
    
    # Calculate travel time based on method
    $speedModifier = switch ($Method) {
        'Walk' { 1.0 }
        'Vehicle' { 3.0 }
        'FastTravel' { 10.0 }
        'Stealth' { 0.5 }
    }
    
    $weatherMod = (Get-Weather).MovementModifier
    $travelTimeHours = $distance / ($script:WorldConfig.TravelSpeedKmPerHour * $speedModifier * $weatherMod)
    $travelTimeMinutes = [Math]::Ceiling($travelTimeHours * 60)
    
    # Check for random encounters
    $encounter = $null
    if ($Method -ne 'FastTravel' -and (Get-Random -Minimum 0.0 -Maximum 1.0) -lt $script:WorldConfig.RandomEncounterProbability) {
        $fromDistrict = Get-District -Id $fromLocation.DistrictId
        if ($fromDistrict -and $fromDistrict.RandomEncounterTypes.Count -gt 0) {
            $encounterType = $fromDistrict.RandomEncounterTypes | Get-Random
            $encounter = @{
                Type = $encounterType
                DistrictId = $fromLocation.DistrictId
                Location = "En route to $($toLocation.Name)"
            }
        }
    }
    
    # Advance game time
    $null = Advance-GameTime -Minutes $travelTimeMinutes
    
    # Update visit count
    $toLocation.VisitCount++
    
    # Mark as discovered if first visit
    if (-not $toLocation.IsDiscovered) {
        $null = Set-LocationDiscovered -LocationId $ToLocationId
    }
    
    # Mark district as discovered
    if ($toLocation.DistrictId) {
        $district = Get-District -Id $toLocation.DistrictId
        if ($district -and -not $district.IsDiscovered) {
            $district.IsDiscovered = $true
            $district.VisitCount++
            
            if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
                $null = Send-GameEvent -EventType 'district.discovered' -Data @{
                    DistrictId = $toLocation.DistrictId
                    Name = $district.Name
                }
            }
        }
    }
    
    if (Get-Command -Name 'Send-GameEvent' -ErrorAction SilentlyContinue) {
        $null = Send-GameEvent -EventType 'travel.completed' -Data @{
            FromLocationId = $FromLocationId
            ToLocationId = $ToLocationId
            Distance = $distance
            TravelTime = $travelTimeMinutes
            Method = $Method
            Encounter = $encounter
        }
    }
    
    return @{
        Success = $true
        FromLocation = $fromLocation.Name
        ToLocation = $toLocation.Name
        Distance = [Math]::Round($distance, 2)
        TravelTimeMinutes = $travelTimeMinutes
        ArrivalTime = $script:WorldState.CurrentTime
        Encounter = $encounter
        Weather = (Get-Weather).Name
    }
}

# ============================================
# Map Functions (Legacy + Enhanced)
# ============================================
function New-GameMap {
    <#
    .SYNOPSIS
        Creates a new game map container
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [string]$Type = "Outdoor",
        
        [hashtable]$Boundaries = @{
            North = 40.7812
            South = 40.7012
            East = -73.9442
            West = -74.0212
        }
    )

    $map = @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = $Name
        Type = $Type
        Boundaries = $Boundaries
        Layers = @()
        Points = @()
        Districts = @()
        CreatedAt = Get-Date
    }

    $script:WorldState.LoadedMaps[$map.Id] = $map
    
    return $map
}

function Add-MapLayer {
    <#
    .SYNOPSIS
        Adds a layer to a game map
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Map,

        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Type = "Default",
        [hashtable]$Properties = @{}
    )

    $layer = @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = $Name
        Type = $Type
        Properties = $Properties
        Features = @()
    }

    $Map.Layers += $layer
    return $Map
}

function Add-MapPoint {
    <#
    .SYNOPSIS
        Adds a point of interest to a game map
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Map,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [double]$Latitude,

        [Parameter(Mandatory)]
        [double]$Longitude,

        [string]$Type = "Default",
        [hashtable]$Properties = @{}
    )

    $point = @{
        Id = [System.Guid]::NewGuid().ToString()
        Name = $Name
        Type = $Type
        Latitude = $Latitude
        Longitude = $Longitude
        Properties = $Properties
    }

    $Map.Points += $point
    return $Map
}

function Export-GameMap {
    <#
    .SYNOPSIS
        Exports a game map to file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Map,

        [string]$OutputPath = ".\Data\Maps",
        [switch]$AsGeoJSON
    )

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $fileName = $Map.Name -replace '[^a-zA-Z0-9]', '_'

    if ($AsGeoJSON) {
        $geoJson = @{
            type = "FeatureCollection"
            features = @()
        }

        foreach ($point in $Map.Points) {
            $feature = @{
                type = "Feature"
                geometry = @{
                    type = "Point"
                    coordinates = @($point.Longitude, $point.Latitude)
                }
                properties = $point.Properties.Clone()
            }
            $feature.properties['name'] = $point.Name
            $feature.properties['type'] = $point.Type
            $geoJson.features += $feature
        }

        $outputFile = Join-Path -Path $OutputPath -ChildPath "$fileName.geojson"
        $geoJson | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile
    }
    else {
        $outputFile = Join-Path -Path $OutputPath -ChildPath "$fileName.json"
        $Map | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile
    }

    return $outputFile
}

function Import-GameMap {
    <#
    .SYNOPSIS
        Imports a game map from file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path $Path) {
        $content = Get-Content -Path $Path -Raw
        $map = $content | ConvertFrom-Json -AsHashtable
        
        if ($map.Id) {
            $script:WorldState.LoadedMaps[$map.Id] = $map
        }
        
        return $map
    }

    return $null
}

# ============================================
# World State Query Functions
# ============================================
function Get-WorldState {
    <#
    .SYNOPSIS
        Gets a summary of the current world state
    #>
    [CmdletBinding()]
    param()
    
    $timeOfDay = Get-TimeOfDay
    $weather = Get-Weather
    
    return @{
        GameTime = $script:WorldState.CurrentTime
        TimeOfDay = $timeOfDay.Period
        IsNight = $timeOfDay.IsNight
        LightLevel = $timeOfDay.LightLevel
        Weather = $weather.Name
        WeatherDescription = $weather.Description
        DistrictCount = $script:WorldState.ActiveDistricts.Count
        LocationCount = $script:WorldState.Locations.Count
        DiscoveredLocations = ($script:WorldState.Locations.Values | Where-Object { $_.IsDiscovered }).Count
        LoadedMaps = $script:WorldState.LoadedMaps.Count
    }
}

function Get-NearbyLocations {
    <#
    .SYNOPSIS
        Gets locations near a specific point or within a district
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName='Coords')]
        [double]$Latitude,
        
        [Parameter(ParameterSetName='Coords')]
        [double]$Longitude,
        
        [Parameter(ParameterSetName='Coords')]
        [double]$RadiusKm = 1.0,
        
        [Parameter(ParameterSetName='District')]
        [string]$DistrictId,
        
        [Parameter(ParameterSetName='Location')]
        [string]$FromLocationId,
        
        [switch]$DiscoveredOnly
    )
    
    $locations = @()
    
    if ($DistrictId) {
        $locations = Get-Location -DistrictId $DistrictId
    }
    elseif ($FromLocationId) {
        $fromLocation = Get-Location -Id $FromLocationId
        if ($fromLocation) {
            # Get connected locations
            foreach ($conn in $fromLocation.Connections) {
                $loc = Get-Location -Id $conn.TargetId
                if ($loc) { $locations += $loc }
            }
        }
    }
    elseif ($Latitude -and $Longitude) {
        foreach ($loc in $script:WorldState.Locations.Values) {
            $latDiff = $loc.Latitude - $Latitude
            $lonDiff = $loc.Longitude - $Longitude
            $distance = [Math]::Sqrt($latDiff * $latDiff + $lonDiff * $lonDiff) * 111
            
            if ($distance -le $RadiusKm) {
                $locations += $loc
            }
        }
    }
    
    if ($DiscoveredOnly) {
        $locations = $locations | Where-Object { $_.IsDiscovered }
    }
    
    return @($locations)
}

# ============================================
# Utility Functions
# ============================================
function Get-DistrictTypes {
    <#
    .SYNOPSIS
        Gets all available district types
    #>
    return $script:DistrictTypes.Keys
}

function Get-LocationTypes {
    <#
    .SYNOPSIS
        Gets all available location types
    #>
    return $script:LocationTypes.Keys
}

function Get-WeatherTypes {
    <#
    .SYNOPSIS
        Gets all available weather types
    #>
    return $script:WeatherTypes.Keys
}

# ============================================
# Module Exports
# ============================================
Export-ModuleMember -Function @(
    # Initialization
    'Initialize-WorldSystem'
    
    # Time System
    'Get-GameTime'
    'Set-GameTime'
    'Advance-GameTime'
    'Get-TimeOfDay'
    
    # Weather System
    'Get-Weather'
    'Set-Weather'
    
    # Districts
    'New-District'
    'Get-District'
    'Set-DistrictControl'
    
    # Locations
    'New-Location'
    'Get-Location'
    'Set-LocationDiscovered'
    'Connect-Locations'
    
    # Travel
    'Start-Travel'
    
    # Maps (Legacy)
    'New-GameMap'
    'Add-MapLayer'
    'Add-MapPoint'
    'Export-GameMap'
    'Import-GameMap'
    
    # World State
    'Get-WorldState'
    'Get-NearbyLocations'
    
    # Utilities
    'Get-DistrictTypes'
    'Get-LocationTypes'
    'Get-WeatherTypes'
)
