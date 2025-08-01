# Enhanced Modules Migration Guide

## Quick Migration Checklist

This guide helps you migrate from the previous module versions to the enhanced versions with improved verbose handling, cross-module communication, and proper entity management.

### ✅ **Required Changes**

#### 1. Verbose Parameter Migration

**❌ Old (will cause errors):**
```powershell
Initialize-EventSystem -GamePath "." -Verbose
Register-GameEvent -EventType "test" -ScriptBlock { } -Verbose
Send-GameEvent -EventType "test" -Data @{} -Verbose
Initialize-CommandRegistry -Configuration @{} -Verbose
```

**✅ New (correct approach):**
```powershell
# Option 1: Global verbose preference
$VerbosePreference = 'Continue'
Initialize-EventSystem -GamePath "."
Register-GameEvent -EventType "test" -ScriptBlock { }
Send-GameEvent -EventType "test" -Data @{}
Initialize-CommandRegistry -Configuration @{}

# Option 2: Scoped verbose preference
& {
    $VerbosePreference = 'Continue'
    Initialize-EventSystem -GamePath "."
    Register-GameEvent -EventType "test" -ScriptBlock { }
}

# Option 3: Module-specific verbose
$oldVerbose = $VerbosePreference
$VerbosePreference = 'Continue'
Initialize-EventSystem -GamePath "."
$VerbosePreference = $oldVerbose
```

#### 2. StateManager Entity Requirements

**❌ Old (will cause errors):**
```powershell
# Direct hashtable registration - NO LONGER SUPPORTED
Register-Entity -Entity @{
    id = "player1"
    type = "player"
    data = @{ name = "John" }
}
```

**✅ New (required approach):**
```powershell
# Must import DataModels and create proper entities
Import-Module .\Modules\CoreGame\DataModels.psm1

$entity = New-GameEntity @{
    id = "player1"
    type = "player"
    data = @{ name = "John" }
}

Register-Entity -Entity $entity
```

#### 3. Helper Function Array Handling

**❌ Old (might cause issues):**
```powershell
$cmd = New-CommandDefinition -Name "test" -Module "test" -Handler { }
$cmd.AddParameter($param)  # Might fail if $cmd is an array
```

**✅ New (explicit handling):**
```powershell
$cmd = New-CommandDefinition -Name "test" -Module "test" -Handler { }
$cmd = @($cmd)[0]  # Force single object if returned as array

$param = New-CommandParameter -Name "TestParam" -Type "String"
$param = @($param)[0]  # Force single object if returned as array

$cmd.AddParameter($param)
```

### 🔄 **Enhanced Features to Leverage**

#### 1. Structured Logging with Data
```powershell
# Enhanced logging with structured data
Write-GameLog -Message "Player action" -Level Info -Module "PlayerSystem" -Data @{
    PlayerId = "player1"
    Action = "move"
    Position = @{ X = 10; Y = 20 }
    Timestamp = Get-Date
}
```

#### 2. Event Deduplication
```powershell
# Prevent duplicate events
Send-GameEvent -EventType "player.status" -Data @{ HP = 100 } -Deduplicate
Send-GameEvent -EventType "player.status" -Data @{ HP = 100 } -Deduplicate  # Ignored
```

#### 3. Priority Events
```powershell
# High priority for critical events
Send-GameEvent -EventType "error.critical" -Data @{ Error = "Database down" } -Priority High

# Normal priority for standard events
Send-GameEvent -EventType "player.action" -Data @{ Action = "move" } -Priority Normal
```

#### 4. Cross-Module Communication
```powershell
# Set up cross-module event handling
Register-GameEvent -EventType "command.*" -ScriptBlock {
    param($Data, $Event)
    Write-GameLog -Message "Command event: $($Event.EventType)" -Level Debug -Module "CommandTracker"
}

# Commands automatically trigger events
Invoke-GameCommand -CommandName "player.heal" -Parameters @{ Amount = 50 }
```

### 📋 **Module-by-Module Changes**

#### GameLogging.psm1
- ✅ **No function signature changes** - fully backward compatible
- ✅ **Enhanced:** Multi-output support (console, file, events)
- ✅ **Enhanced:** Structured data logging with `-Data` parameter
- ✅ **Enhanced:** VerbosePreference support

#### EventSystem.psm1
- ⚠️ **Changed:** Removed `-Verbose` parameters from all functions
- ✅ **Enhanced:** Event deduplication with `-Deduplicate`
- ✅ **Enhanced:** Priority events with `-Priority`
- ✅ **Enhanced:** JavaScript communication bridge

#### CommandRegistry.psm1
- ⚠️ **Changed:** Removed `-Verbose` parameters from all functions
- ⚠️ **Changed:** Helper functions may return arrays requiring explicit handling
- ✅ **Enhanced:** Built-in documentation commands
- ✅ **Enhanced:** Performance monitoring and statistics

#### StateManager.psm1
- ⚠️ **Breaking:** Now requires GameEntity objects (use `New-GameEntity`)
- ⚠️ **Breaking:** Must import DataModels module
- ✅ **Enhanced:** Improved entity persistence and loading
- ✅ **Enhanced:** Better error handling and validation

### 🧪 **Testing Your Migration**

#### Quick Test Script
```powershell
# Test basic functionality after migration
try {
    # Test verbose handling
    $VerbosePreference = 'Continue'
    Import-Module .\Modules\CoreGame\EventSystem.psm1 -Force
    Initialize-EventSystem -GamePath "."

    # Test entity creation
    Import-Module .\Modules\CoreGame\DataModels.psm1 -Force
    $entity = New-GameEntity @{ id = "test"; type = "test"; data = @{} }

    # Test logging
    Import-Module .\Modules\CoreGame\GameLogging.psm1 -Force
    Write-GameLog -Message "Migration test" -Level Info -Module "Test" -Data @{ Test = $true }

    Write-Host "✅ Migration successful!" -ForegroundColor Green

} catch {
    Write-Host "❌ Migration issue: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check the migration guide for fixes." -ForegroundColor Yellow
}
```

#### Run Full Test Suite
```powershell
# Comprehensive testing
& .\Test-EnhancedModules.ps1
```

### 🚨 **Common Migration Issues**

#### Issue 1: "Parameter set cannot be resolved"
```
Error: A parameter cannot be found that matches parameter name 'Verbose'
```
**Fix:** Remove `-Verbose` parameters and use `$VerbosePreference = 'Continue'`

#### Issue 2: "Cannot register entity"
```
Error: Cannot process argument transformation on parameter 'Entity'
```
**Fix:** Import DataModels and use `New-GameEntity` instead of hashtables

#### Issue 3: "You cannot call a method on a null-valued expression"
```
Error: When calling AddParameter on command definition
```
**Fix:** Force single object: `$cmd = @($cmd)[0]`

#### Issue 4: "Module not found"
```
Error: The specified module 'DataModels' was not loaded
```
**Fix:** Import required modules: `Import-Module .\Modules\CoreGame\DataModels.psm1`

### 📚 **Additional Resources**

- **Full Documentation:** `Modules\CoreGame\README.md`
- **Architecture Guide:** `Docs\EnhancedModulesGuide.md`
- **Test Examples:** `Test-EnhancedModules.ps1`
- **PowerShell Help:** `Get-Help <FunctionName> -Full`

### 🎯 **Migration Priority**

1. **High Priority:** Fix verbose parameter calls (breaks functionality)
2. **High Priority:** Update StateManager entity creation (breaks persistence)
3. **Medium Priority:** Handle helper function arrays (improves reliability)
4. **Low Priority:** Leverage new features (enhances capabilities)

---

**Need Help?**
- Check error messages against common issues above
- Run the test script to validate changes
- Review the full test suite for working examples
