# WorldSystem Module - Map and world management

function New-GameMap {
    param(
        [string]$Name,
        [string]$Type = "Outdoor",
        [hashtable]$Boundaries = @{
            North = 40.7812
            South = 40.7012 
            East = -73.9442
            West = -74.0212
        }
    )
    
    # Create a new map object
    $map = @{
        Name = $Name
        Type = $Type
        Boundaries = $Boundaries
        Layers = @()
        Points = @()
        CreatedAt = Get-Date
    }
    
    return $map
}

function Add-MapLayer {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Map,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [string]$Type = "Default",
        [hashtable]$Properties = @{}
    )
    
    $layer = @{
        Name = $Name
        Type = $Type
        Properties = $Properties
        Features = @()
    }
    
    $Map.Layers += $layer
    return $Map
}

function Add-MapPoint {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Map,
        
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [double]$Latitude,
        
        [Parameter(Mandatory=$true)]
        [double]$Longitude,
        
        [string]$Type = "Default",
        [hashtable]$Properties = @{}
    )
    
    $point = @{
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
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Map,
        
        [string]$OutputPath = ".\Data\Maps",
        [switch]$AsGeoJSON
    )
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    $fileName = $Map.Name -replace '[^a-zA-Z0-9]', '_'
    
    if ($AsGeoJSON) {
        # Convert to GeoJSON format
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
                properties = $point.Properties
                properties['name'] = $point.Name
                properties['type'] = $point.Type
            }
            $geoJson.features += $feature
        }
        
        $outputFile = Join-Path -Path $OutputPath -ChildPath "$fileName.geojson"
        $geoJson | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile
    } else {
        $outputFile = Join-Path -Path $OutputPath -ChildPath "$fileName.json"
        $Map | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile
    }
    
    return $outputFile
}

function Import-GameMap {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (Test-Path $Path) {
        $content = Get-Content -Path $Path -Raw
        $map = $content | ConvertFrom-Json -AsHashtable
        return $map
    }
    
    return $null
}

# Export all functions
Export-ModuleMember -Function New-GameMap, Add-MapLayer, Add-MapPoint, Export-GameMap, Import-GameMap
