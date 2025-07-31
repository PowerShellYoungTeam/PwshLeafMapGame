# Simple syntax test for DataModels
$script:EntityTypes = @{
    Base = 'Entity'
    Player = 'Player'
    NPC = 'NPC'
    Item = 'Item'
    Location = 'Location'
    Quest = 'Quest'
    Faction = 'Faction'
}

class GameEntity {
    [string]$Id
    [string]$Type
    [string]$Name

    GameEntity() {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Type = $script:EntityTypes.Base
        $this.Name = ''
    }

    GameEntity([hashtable]$Data) {
        $this.Id = if ($Data.Id) { $Data.Id } else { [System.Guid]::NewGuid().ToString() }
        $this.Type = if ($Data.Type) { $Data.Type } else { $script:EntityTypes.Base }
        $this.Name = if ($Data.Name) { $Data.Name } else { '' }
    }
}

Write-Host "Basic class syntax is OK"
