# PowerShell Leafmap Game - State Management System
# Comprehensive state persistence, save/load, and synchronization architecture

using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.IO.Compression

# Import required modules
Import-Module (Join-Path $PSScriptRoot "DataModels.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "EventSystem.psm1") -Force

# Global state management configuration
$script:StateConfig = @{
    SavesDirectory = ".\Data\Saves"
    BackupsDirectory = ".\Data\Backups"
    TempDirectory = ".\Data\Temp"
    MaxSaveSlots = 10
    MaxBackups = 5
    AutoSaveInterval = 300  # 5 minutes in seconds
    CompressionEnabled = $true
    EncryptionEnabled = $false
    SyncEnabled = $true
    ConflictResolution = "LastWriteWins"  # LastWriteWins, Manual, Merge
    StateValidation = $true
    PerformanceMonitoring = $true
}

# Global state containers
$script:GameState = @{
    Current = @{}
    Previous = @{}
    Snapshots = @{}
    ChangeLog = @()
    SyncQueue = @()
    ValidationErrors = @()
}

# Performance metrics
$script:StateMetrics = @{
    SaveCount = 0
    LoadCount = 0
    SyncCount = 0
    AverageSaveTime = 0
    AverageLoadTime = 0
    LastSaveSize = 0
    TotalDataSize = 0
    ErrorCount = 0
    LastActivity = Get-Date
}

# State change tracking
class StateChangeTracker {
    [string]$EntityId
    [string]$EntityType
    [hashtable]$OriginalState
    [hashtable]$CurrentState
    [System.Collections.Generic.List[hashtable]]$Changes
    [DateTime]$CreatedAt
    [DateTime]$LastModified
    [bool]$IsDirty

    StateChangeTracker([string]$EntityId, [string]$EntityType, [hashtable]$InitialState) {
        $this.EntityId = $EntityId
        $this.EntityType = $EntityType
        $this.OriginalState = $InitialState.Clone()
        $this.CurrentState = $InitialState.Clone()
        $this.Changes = [System.Collections.Generic.List[hashtable]]::new()
        $this.CreatedAt = Get-Date
        $this.LastModified = Get-Date
        $this.IsDirty = $false
    }

    [void] RecordChange([string]$Property, [object]$OldValue, [object]$NewValue, [string]$ChangeType = "Update") {
        $change = @{
            Id = [System.Guid]::NewGuid().ToString()
            Property = $Property
            OldValue = $OldValue
            NewValue = $NewValue
            ChangeType = $ChangeType  # Create, Update, Delete
            Timestamp = Get-Date
            Source = "StateManager"
        }

        $this.Changes.Add($change)
        $this.CurrentState[$Property] = $NewValue
        $this.LastModified = Get-Date
        $this.IsDirty = $true
    }

    [hashtable] GetChangesSince([DateTime]$Since) {
        $recentChanges = $this.Changes | Where-Object { $_.Timestamp -gt $Since }
        return @{
            EntityId = $this.EntityId
            EntityType = $this.EntityType
            Changes = $recentChanges
            ChangeCount = $recentChanges.Count
            LastModified = $this.LastModified
        }
    }

    [void] MarkClean() {
        $this.IsDirty = $false
        $this.OriginalState = $this.CurrentState.Clone()
    }

    [hashtable] GetDiff() {
        $diff = @{
            EntityId = $this.EntityId
            EntityType = $this.EntityType
            Added = @{}
            Modified = @{}
            Removed = @{}
        }

        # Compare current state with original
        foreach ($key in $this.CurrentState.Keys) {
            if (-not $this.OriginalState.ContainsKey($key)) {
                $diff.Added[$key] = $this.CurrentState[$key]
            }
            elseif ($this.OriginalState[$key] -ne $this.CurrentState[$key]) {
                $diff.Modified[$key] = @{
                    OldValue = $this.OriginalState[$key]
                    NewValue = $this.CurrentState[$key]
                }
            }
        }

        foreach ($key in $this.OriginalState.Keys) {
            if (-not $this.CurrentState.ContainsKey($key)) {
                $diff.Removed[$key] = $this.OriginalState[$key]
            }
        }

        return $diff
    }
}

# Core state management class
class GameStateManager {
    [ConcurrentDictionary[string, StateChangeTracker]]$Trackers
    [hashtable]$Configuration
    [hashtable]$LoadedStates
    [System.Timers.Timer]$AutoSaveTimer
    [bool]$IsInitialized
    [object]$SyncLock

    GameStateManager([hashtable]$Config = @{}) {
        $this.Trackers = [ConcurrentDictionary[string, StateChangeTracker]]::new()
        $this.Configuration = $script:StateConfig.Clone()
        # Merge user config with defaults
        foreach ($key in $Config.Keys) {
            $this.Configuration[$key] = $Config[$key]
        }
        $this.LoadedStates = @{}
        $this.IsInitialized = $false
        $this.SyncLock = [object]::new()
        $this.InitializeDirectories()
        $this.SetupAutoSave()
    }

    [void] InitializeDirectories() {
        $directories = @(
            $this.Configuration.SavesDirectory,
            $this.Configuration.BackupsDirectory,
            $this.Configuration.TempDirectory
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Verbose "Created directory: $dir"
            }
        }
    }

    [void] SetupAutoSave() {
        if ($this.Configuration.AutoSaveInterval -gt 0) {
            $this.AutoSaveTimer = New-Object System.Timers.Timer
            $this.AutoSaveTimer.Interval = $this.Configuration.AutoSaveInterval * 1000
            $this.AutoSaveTimer.AutoReset = $true

            Register-ObjectEvent -InputObject $this.AutoSaveTimer -EventName Elapsed -Action {
                try {
                    $Global:StateManager.PerformAutoSave()
                }
                catch {
                    Write-Error "Auto-save failed: $($_.Exception.Message)"
                }
            } | Out-Null

            $this.AutoSaveTimer.Start()
            Write-Verbose "Auto-save timer started (interval: $($this.Configuration.AutoSaveInterval)s)"
        }
    }

    [void] RegisterEntity([string]$EntityId, [string]$EntityType, [hashtable]$InitialState) {
        $tracker = [StateChangeTracker]::new($EntityId, $EntityType, $InitialState)
        $this.Trackers[$EntityId] = $tracker

        Write-Verbose "Registered entity for state tracking: $EntityType ($EntityId)"
    }

    [void] UpdateEntityState([string]$EntityId, [string]$Property, [object]$NewValue, [string]$ChangeType = "Update") {
        if ($this.Trackers.ContainsKey($EntityId)) {
            $tracker = $this.Trackers[$EntityId]
            $oldValue = if ($tracker.CurrentState.ContainsKey($Property)) { $tracker.CurrentState[$Property] } else { $null }
            $tracker.RecordChange($Property, $oldValue, $NewValue, $ChangeType)

            # Update script-level state
            if (-not $script:GameState.Current.ContainsKey($EntityId)) {
                $script:GameState.Current[$EntityId] = @{}
            }
            $script:GameState.Current[$EntityId][$Property] = $NewValue

            Write-Verbose "Updated entity state: $EntityId.$Property = $NewValue"
        }
        else {
            Write-Warning "Entity $EntityId not registered for state tracking"
        }
    }

    [hashtable] GetEntityState([string]$EntityId) {
        if ($this.Trackers.ContainsKey($EntityId)) {
            return $this.Trackers[$EntityId].CurrentState.Clone()
        }
        return @{}
    }

    [hashtable] SaveGameState([string]$SaveName, [hashtable]$AdditionalData = @{}) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $saveData = $this.CompileSaveData($AdditionalData)
            $saveFile = $this.GenerateSaveFilePath($SaveName)

            # Create backup of existing save
            if (Test-Path $saveFile) {
                $this.CreateBackup($saveFile)
            }

            # Save data
            $jsonData = $this.SerializeSaveData($saveData)

            if ($this.Configuration.CompressionEnabled) {
                $this.SaveCompressed($saveFile, $jsonData)
            }
            else {
                $jsonData | Set-Content -Path $saveFile -Encoding UTF8
            }

            # Update metrics
            $this.UpdateSaveMetrics($saveFile, $stopwatch.ElapsedMilliseconds)

            # Mark all trackers as clean
            foreach ($tracker in $this.Trackers.Values) {
                $tracker.MarkClean()
            }

            $script:StateMetrics.SaveCount++
            $script:StateMetrics.LastActivity = Get-Date

            $result = @{
                Success = $true
                SaveFile = $saveFile
                SaveSize = (Get-Item $saveFile).Length
                SaveTime = $stopwatch.ElapsedMilliseconds
                Timestamp = Get-Date
                Entities = $this.Trackers.Count
            }

            # Send save event
            Send-GameEvent -EventType "state.saved" -Data $result

            return $result
        }
        catch {
            $result = @{
                Success = $false
                Error = $_.Exception.Message
                SaveTime = $stopwatch.ElapsedMilliseconds
                Timestamp = Get-Date
            }

            $script:StateMetrics.ErrorCount++
            Send-GameEvent -EventType "state.saveError" -Data $result

            throw "Save failed: $($_.Exception.Message)"
        }
        finally {
            $stopwatch.Stop()
        }
    }

    [hashtable] LoadGameState([string]$SaveName) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $saveFile = $this.GenerateSaveFilePath($SaveName)

            if (-not (Test-Path $saveFile)) {
                throw "Save file not found: $SaveName"
            }

            # Load data
            $jsonData = if ($this.Configuration.CompressionEnabled) {
                $this.LoadCompressed($saveFile)
            }
            else {
                Get-Content -Path $saveFile -Raw -Encoding UTF8
            }

            $saveData = $this.DeserializeSaveData($jsonData)

            # Validate save data
            if ($this.Configuration.StateValidation) {
                $validation = $this.ValidateSaveData($saveData)
                if (-not $validation.IsValid) {
                    throw "Save data validation failed: $($validation.Errors -join '; ')"
                }
            }

            # Load entities into trackers
            $this.LoadEntitiesFromSave($saveData)

            # Update script-level state
            $script:GameState.Current = $saveData.GameState
            $script:GameState.Previous = $script:GameState.Current.Clone()

            $this.UpdateLoadMetrics($saveFile, $stopwatch.ElapsedMilliseconds)
            $script:StateMetrics.LoadCount++
            $script:StateMetrics.LastActivity = Get-Date

            $result = @{
                Success = $true
                SaveFile = $saveFile
                LoadTime = $stopwatch.ElapsedMilliseconds
                Timestamp = Get-Date
                Entities = $saveData.Entities.Count
                SaveData = $saveData
            }

            Send-GameEvent -EventType "state.loaded" -Data $result

            return $result
        }
        catch {
            $result = @{
                Success = $false
                Error = $_.Exception.Message
                LoadTime = $stopwatch.ElapsedMilliseconds
                Timestamp = Get-Date
            }

            $script:StateMetrics.ErrorCount++
            Send-GameEvent -EventType "state.loadError" -Data $result

            throw "Load failed: $($_.Exception.Message)"
        }
        finally {
            $stopwatch.Stop()
        }
    }

    [hashtable] CompileSaveData([hashtable]$AdditionalData) {
        $entities = @{}

        foreach ($tracker in $this.Trackers.Values) {
            $entities[$tracker.EntityId] = @{
                EntityType = $tracker.EntityType
                State = $tracker.CurrentState
                Changes = $tracker.Changes
                LastModified = $tracker.LastModified
                IsDirty = $tracker.IsDirty
            }
        }

        return @{
            Version = "1.0.0"
            GameState = $script:GameState.Current.Clone()
            Entities = $entities
            Metadata = @{
                SavedAt = Get-Date
                GameVersion = "1.0.0"
                Platform = "PowerShell"
                PlayerCount = ($entities.Values | Where-Object { $_.EntityType -eq "Player" }).Count
                TotalEntities = $entities.Count
            }
            AdditionalData = $AdditionalData
            Performance = $script:StateMetrics.Clone()
        }
    }

    [string] SerializeSaveData([hashtable]$SaveData) {
        return $SaveData | ConvertTo-Json -Depth 20 -Compress
    }

    [hashtable] DeserializeSaveData([string]$JsonData) {
        return $JsonData | ConvertFrom-Json -AsHashtable
    }

    [void] SaveCompressed([string]$FilePath, [string]$Data) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
        $compressedPath = "$FilePath.gz"

        $fileStream = [System.IO.File]::Create($compressedPath)
        $gzipStream = [System.IO.Compression.GZipStream]::new($fileStream, [System.IO.Compression.CompressionMode]::Compress)

        try {
            $gzipStream.Write($bytes, 0, $bytes.Length)
        }
        finally {
            $gzipStream.Close()
            $fileStream.Close()
        }

        # Replace original with compressed
        if (Test-Path $FilePath) {
            Remove-Item $FilePath -Force
        }
        Move-Item $compressedPath $FilePath
    }

    [string] LoadCompressed([string]$FilePath) {
        $fileStream = [System.IO.File]::OpenRead($FilePath)
        $gzipStream = [System.IO.Compression.GZipStream]::new($fileStream, [System.IO.Compression.CompressionMode]::Decompress)
        $reader = [System.IO.StreamReader]::new($gzipStream)

        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Close()
            $gzipStream.Close()
            $fileStream.Close()
        }
    }

    [string] GenerateSaveFilePath([string]$SaveName) {
        $fileName = "$SaveName.json"
        return Join-Path $this.Configuration.SavesDirectory $fileName
    }

    [void] CreateBackup([string]$SaveFile) {
        $backupName = "$(Split-Path $SaveFile -LeafBase)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $backupPath = Join-Path $this.Configuration.BackupsDirectory $backupName
        Copy-Item $SaveFile $backupPath -Force

        # Clean up old backups
        $this.CleanupOldBackups()
    }

    [void] CleanupOldBackups() {
        $backups = Get-ChildItem $this.Configuration.BackupsDirectory -Filter "*.json" |
                   Sort-Object LastWriteTime -Descending

        if ($backups.Count -gt $this.Configuration.MaxBackups) {
            $backupsToRemove = $backups | Select-Object -Skip $this.Configuration.MaxBackups
            foreach ($backup in $backupsToRemove) {
                Remove-Item $backup.FullName -Force
                Write-Verbose "Removed old backup: $($backup.Name)"
            }
        }
    }

    [void] LoadEntitiesFromSave([hashtable]$SaveData) {
        $this.Trackers.Clear()

        foreach ($entityId in $SaveData.Entities.Keys) {
            $entityData = $SaveData.Entities[$entityId]
            $tracker = [StateChangeTracker]::new($entityId, $entityData.EntityType, $entityData.State)

            # Restore change history if available
            if ($entityData.Changes) {
                foreach ($change in $entityData.Changes) {
                    $tracker.Changes.Add($change)
                }
            }

            $tracker.LastModified = if ($entityData.LastModified) {
                [DateTime]$entityData.LastModified
            } else {
                Get-Date
            }

            $tracker.IsDirty = if ($null -ne $entityData.IsDirty) {
                $entityData.IsDirty
            } else {
                $false
            }

            $this.Trackers[$entityId] = $tracker
        }

        Write-Verbose "Loaded $($this.Trackers.Count) entities from save data"
    }

    [hashtable] ValidateSaveData([hashtable]$SaveData) {
        $validation = @{
            IsValid = $true
            Errors = @()
            Warnings = @()
        }

        # Check required fields
        $requiredFields = @('Version', 'GameState', 'Entities', 'Metadata')
        foreach ($field in $requiredFields) {
            if (-not $SaveData.ContainsKey($field)) {
                $validation.IsValid = $false
                $validation.Errors += "Missing required field: $field"
            }
        }

        # Validate entities
        if ($SaveData.Entities) {
            foreach ($entityId in $SaveData.Entities.Keys) {
                $entity = $SaveData.Entities[$entityId]
                if (-not $entity.EntityType) {
                    $validation.Warnings += "Entity $entityId missing EntityType"
                }
                if (-not $entity.State) {
                    $validation.Warnings += "Entity $entityId missing State"
                }
            }
        }

        return $validation
    }

    [void] UpdateSaveMetrics([string]$SaveFile, [double]$SaveTime) {
        $script:StateMetrics.AverageSaveTime = (
            ($script:StateMetrics.AverageSaveTime * $script:StateMetrics.SaveCount) + $SaveTime
        ) / ($script:StateMetrics.SaveCount + 1)

        $script:StateMetrics.LastSaveSize = (Get-Item $SaveFile).Length
        $script:StateMetrics.TotalDataSize += $script:StateMetrics.LastSaveSize
    }

    [void] UpdateLoadMetrics([string]$SaveFile, [double]$LoadTime) {
        $script:StateMetrics.AverageLoadTime = (
            ($script:StateMetrics.AverageLoadTime * $script:StateMetrics.LoadCount) + $LoadTime
        ) / ($script:StateMetrics.LoadCount + 1)
    }

    [void] PerformAutoSave() {
        try {
            # Check if any entities are dirty
            $dirtyEntities = $this.Trackers.Values | Where-Object { $_.IsDirty }

            if ($dirtyEntities.Count -gt 0) {
                $autoSaveName = "autosave_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                $result = $this.SaveGameState($autoSaveName, @{ AutoSave = $true })

                Write-Verbose "Auto-save completed: $($result.SaveFile) ($($dirtyEntities.Count) dirty entities)"
                Send-GameEvent -EventType "state.autoSaved" -Data $result
            }
        }
        catch {
            Write-Error "Auto-save failed: $($_.Exception.Message)"
            Send-GameEvent -EventType "state.autoSaveError" -Data @{ Error = $_.Exception.Message }
        }
    }

    [hashtable] GetStateStatistics() {
        $stats = @{
            TrackedEntities = $this.Trackers.Count
            DirtyEntities = ($this.Trackers.Values | Where-Object { $_.IsDirty }).Count
            TotalChanges = ($this.Trackers.Values | ForEach-Object { $_.Changes.Count } | Measure-Object -Sum).Sum
            Performance = $script:StateMetrics.Clone()
            Configuration = $this.Configuration.Clone()
            LastActivity = $script:StateMetrics.LastActivity
        }

        return $stats
    }

    [void] Cleanup() {
        if ($this.AutoSaveTimer) {
            $this.AutoSaveTimer.Stop()
            $this.AutoSaveTimer.Dispose()
        }

        # Perform final auto-save
        try {
            $this.PerformAutoSave()
        }
        catch {
            Write-Warning "Final auto-save failed: $($_.Exception.Message)"
        }

        Write-Verbose "State manager cleanup completed"
    }
}

# Browser-PowerShell synchronization functions
function Sync-StateWithBrowser {
    param(
        [hashtable]$BrowserState,
        [string]$SyncMode = "Merge"  # Merge, Overwrite, Validate
    )

    try {
        $syncResult = @{
            Success = $true
            ConflictCount = 0
            UpdatedEntities = @()
            Errors = @()
            SyncTime = 0
            Timestamp = Get-Date
        }

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        switch ($SyncMode) {
            "Merge" {
                $syncResult = Merge-BrowserState -BrowserState $BrowserState
            }
            "Overwrite" {
                $syncResult = Overwrite-WithBrowserState -BrowserState $BrowserState
            }
            "Validate" {
                $syncResult = Validate-BrowserState -BrowserState $BrowserState
            }
        }

        $stopwatch.Stop()
        $syncResult.SyncTime = $stopwatch.ElapsedMilliseconds
        $script:StateMetrics.SyncCount++

        Send-GameEvent -EventType "state.browserSynced" -Data $syncResult

        return $syncResult
    }
    catch {
        $errorResult = @{
            Success = $false
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }

        Send-GameEvent -EventType "state.browserSyncError" -Data $errorResult
        throw
    }
}

function Export-StateForBrowser {
    param(
        [string[]]$EntityIds = @(),
        [string]$Format = "JSON"  # JSON, Compressed
    )

    try {
        $exportData = @{
            Version = "1.0.0"
            Timestamp = Get-Date
            Entities = @{}
            GameState = @{}
            Metadata = @{
                ExportedAt = Get-Date
                EntityCount = 0
                Platform = "PowerShell"
            }
        }

        # Export specific entities or all
        $targetEntities = if ($EntityIds.Count -gt 0) {
            $Global:StateManager.Trackers.Keys | Where-Object { $_ -in $EntityIds }
        }
        else {
            $Global:StateManager.Trackers.Keys
        }

        foreach ($entityId in $targetEntities) {
            $tracker = $Global:StateManager.Trackers[$entityId]
            $exportData.Entities[$entityId] = @{
                EntityType = $tracker.EntityType
                State = $tracker.CurrentState
                LastModified = $tracker.LastModified
                IsDirty = $tracker.IsDirty
            }
        }

        $exportData.GameState = $script:GameState.Current.Clone()
        $exportData.Metadata.EntityCount = $exportData.Entities.Count

        $jsonData = $exportData | ConvertTo-Json -Depth 20 -Compress

        if ($Format -eq "Compressed") {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonData)
            $compressedData = [System.Convert]::ToBase64String(
                [System.IO.Compression.GZipStream]::new(
                    [System.IO.MemoryStream]::new($bytes),
                    [System.IO.Compression.CompressionMode]::Compress
                ).ToArray()
            )
            return $compressedData
        }

        return $jsonData
    }
    catch {
        Write-Error "Failed to export state for browser: $($_.Exception.Message)"
        throw
    }
}

function Import-StateFromBrowser {
    param(
        [string]$BrowserData,
        [string]$Format = "JSON",  # JSON, Compressed
        [bool]$ValidateBeforeImport = $true
    )

    try {
        # Decompress if needed
        $jsonData = if ($Format -eq "Compressed") {
            $compressedBytes = [System.Convert]::FromBase64String($BrowserData)
            $decompressedBytes = [System.IO.Compression.GZipStream]::new(
                [System.IO.MemoryStream]::new($compressedBytes),
                [System.IO.Compression.CompressionMode]::Decompress
            ).ToArray()
            [System.Text.Encoding]::UTF8.GetString($decompressedBytes)
        }
        else {
            $BrowserData
        }

        $importData = $jsonData | ConvertFrom-Json -AsHashtable

        # Validate imported data
        if ($ValidateBeforeImport) {
            $validation = $Global:StateManager.ValidateSaveData($importData)
            if (-not $validation.IsValid) {
                throw "Browser data validation failed: $($validation.Errors -join '; ')"
            }
        }

        # Import entities
        $importedCount = 0
        foreach ($entityId in $importData.Entities.Keys) {
            $entityData = $importData.Entities[$entityId]

            if ($Global:StateManager.Trackers.ContainsKey($entityId)) {
                # Update existing entity
                $tracker = $Global:StateManager.Trackers[$entityId]
                foreach ($property in $entityData.State.Keys) {
                    $Global:StateManager.UpdateEntityState($entityId, $property, $entityData.State[$property], "BrowserSync")
                }
            }
            else {
                # Register new entity
                $Global:StateManager.RegisterEntity($entityId, $entityData.EntityType, $entityData.State)
            }

            $importedCount++
        }

        # Update game state
        if ($importData.GameState) {
            foreach ($key in $importData.GameState.Keys) {
                $script:GameState.Current[$key] = $importData.GameState[$key]
            }
        }

        $result = @{
            Success = $true
            ImportedEntities = $importedCount
            Timestamp = Get-Date
        }

        Send-GameEvent -EventType "state.browserImported" -Data $result

        return $result
    }
    catch {
        $errorResult = @{
            Success = $false
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }

        Send-GameEvent -EventType "state.browserImportError" -Data $errorResult
        throw
    }
}

# Helper functions
function Merge-BrowserState {
    param([hashtable]$BrowserState)

    $result = @{
        Success = $true
        ConflictCount = 0
        UpdatedEntities = @()
        Errors = @()
    }

    foreach ($entityId in $BrowserState.Entities.Keys) {
        try {
            $browserEntity = $BrowserState.Entities[$entityId]

            if ($Global:StateManager.Trackers.ContainsKey($entityId)) {
                $tracker = $Global:StateManager.Trackers[$entityId]
                $conflicts = @()

                # Check for conflicts
                foreach ($property in $browserEntity.State.Keys) {
                    $browserValue = $browserEntity.State[$property]
                    $currentValue = $tracker.CurrentState[$property]

                    if ($currentValue -ne $browserValue) {
                        $conflicts += @{
                            Property = $property
                            BrowserValue = $browserValue
                            PowerShellValue = $currentValue
                        }
                    }
                }

                if ($conflicts.Count -gt 0) {
                    $result.ConflictCount += $conflicts.Count

                    # Apply conflict resolution strategy
                    switch ($script:StateConfig.ConflictResolution) {
                        "LastWriteWins" {
                            # Browser wins if it has a more recent timestamp
                            $browserTime = [DateTime]$browserEntity.LastModified
                            if ($browserTime -gt $tracker.LastModified) {
                                foreach ($conflict in $conflicts) {
                                    $Global:StateManager.UpdateEntityState($entityId, $conflict.Property, $conflict.BrowserValue, "ConflictResolution")
                                }
                                $result.UpdatedEntities += $entityId
                            }
                        }
                        "Manual" {
                            # Store conflicts for manual resolution
                            $script:GameState.ValidationErrors += @{
                                EntityId = $entityId
                                Conflicts = $conflicts
                                Timestamp = Get-Date
                            }
                        }
                    }
                }
            }
            else {
                # New entity from browser
                $Global:StateManager.RegisterEntity($entityId, $browserEntity.EntityType, $browserEntity.State)
                $result.UpdatedEntities += $entityId
            }
        }
        catch {
            $result.Errors += "Error processing entity $entityId`: $($_.Exception.Message)"
        }
    }

    return $result
}

function Overwrite-WithBrowserState {
    param([hashtable]$BrowserState)

    $result = @{
        Success = $true
        ConflictCount = 0
        UpdatedEntities = @()
        Errors = @()
    }

    foreach ($entityId in $BrowserState.Entities.Keys) {
        try {
            $browserEntity = $BrowserState.Entities[$entityId]

            # Overwrite completely
            $Global:StateManager.RegisterEntity($entityId, $browserEntity.EntityType, $browserEntity.State)
            $result.UpdatedEntities += $entityId
        }
        catch {
            $result.Errors += "Error overwriting entity $entityId`: $($_.Exception.Message)"
        }
    }

    return $result
}

function Validate-BrowserState {
    param([hashtable]$BrowserState)

    $result = @{
        Success = $true
        ConflictCount = 0
        UpdatedEntities = @()
        Errors = @()
        ValidationResult = @{}
    }

    $result.ValidationResult = $Global:StateManager.ValidateSaveData($BrowserState)
    $result.Success = $result.ValidationResult.IsValid

    if (-not $result.Success) {
        $result.Errors = $result.ValidationResult.Errors
    }

    return $result
}

# Public API functions
function Initialize-StateManager {
    param([hashtable]$Configuration = @{})

    try {
        $Global:StateManager = [GameStateManager]::new($Configuration)
        $Global:StateManager.IsInitialized = $true

        Write-Host "State Manager initialized successfully" -ForegroundColor Green

        # Register for shutdown cleanup
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            if ($Global:StateManager) {
                $Global:StateManager.Cleanup()
            }
        }

        return @{
            Success = $true
            Message = "State Manager initialized"
            Configuration = $Global:StateManager.Configuration
        }
    }
    catch {
        Write-Error "Failed to initialize State Manager: $($_.Exception.Message)"
        throw
    }
}

function Register-GameEntity {
    param(
        [string]$EntityId,
        [string]$EntityType,
        [hashtable]$InitialState
    )

    if (-not $Global:StateManager) {
        throw "State Manager not initialized. Call Initialize-StateManager first."
    }

    $Global:StateManager.RegisterEntity($EntityId, $EntityType, $InitialState)

    return @{
        Success = $true
        EntityId = $EntityId
        EntityType = $EntityType
        Timestamp = Get-Date
    }
}

function Update-GameEntityState {
    param(
        [string]$EntityId,
        [string]$Property,
        [object]$Value,
        [string]$ChangeType = "Update"
    )

    if (-not $Global:StateManager) {
        throw "State Manager not initialized. Call Initialize-StateManager first."
    }

    $Global:StateManager.UpdateEntityState($EntityId, $Property, $Value, $ChangeType)

    return @{
        Success = $true
        EntityId = $EntityId
        Property = $Property
        Value = $Value
        Timestamp = Get-Date
    }
}

function Save-GameState {
    param(
        [string]$SaveName = "default",
        [hashtable]$AdditionalData = @{}
    )

    if (-not $Global:StateManager) {
        throw "State Manager not initialized. Call Initialize-StateManager first."
    }

    return $Global:StateManager.SaveGameState($SaveName, $AdditionalData)
}

function Load-GameState {
    param([string]$SaveName = "default")

    if (-not $Global:StateManager) {
        throw "State Manager not initialized. Call Initialize-StateManager first."
    }

    return $Global:StateManager.LoadGameState($SaveName)
}

function Get-StateStatistics {
    if (-not $Global:StateManager) {
        throw "State Manager not initialized. Call Initialize-StateManager first."
    }

    return $Global:StateManager.GetStateStatistics()
}

function Get-SaveFiles {
    $savesDir = $script:StateConfig.SavesDirectory

    if (-not (Test-Path $savesDir)) {
        return @()
    }

    $saveFiles = Get-ChildItem $savesDir -Filter "*.json" | ForEach-Object {
        @{
            Name = $_.BaseName
            FullPath = $_.FullName
            Size = $_.Length
            Created = $_.CreationTime
            Modified = $_.LastWriteTime
        }
    }

    return $saveFiles
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-StateManager',
    'Register-GameEntity',
    'Update-GameEntityState',
    'Save-GameState',
    'Load-GameState',
    'Get-StateStatistics',
    'Get-SaveFiles',
    'Sync-StateWithBrowser',
    'Export-StateForBrowser',
    'Import-StateFromBrowser'
)

# Module initialization
Write-Host "StateManager module loaded. Call Initialize-StateManager to begin." -ForegroundColor Cyan
