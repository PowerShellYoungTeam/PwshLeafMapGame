# CoreGame Module - Core game engine functionality
# This is the root module that imports all submodules and re-exports their functions

<#
.SYNOPSIS
    Root module for the PowerShell Leafmap RPG Game
    
.DESCRIPTION
    This module serves as the entry point for the game engine.
    All submodules are imported and their functions are re-exported through this module.
    
.NOTES
    Version: 0.2.0
    Load order is critical - base modules must load before dependent modules.
#>

# Import all submodules in dependency order
# The functions will be available because we explicitly Export-ModuleMember at the end
$script:ModulePath = $PSScriptRoot

# Import each module and capture their exported functions
Import-Module (Join-Path $script:ModulePath "GameLogging.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $script:ModulePath "DataModels.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $script:ModulePath "EventSystem.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $script:ModulePath "StateManager.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $script:ModulePath "PathfindingSystem.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $script:ModulePath "CommunicationBridge.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $script:ModulePath "CommandRegistry.psm1") -Force -DisableNameChecking

function Initialize-GameEngine {
    <#
    .SYNOPSIS
        Initializes the complete game engine and all subsystems
        
    .DESCRIPTION
        This function initializes all game subsystems in the correct order:
        1. GameLogging - for diagnostic output
        2. EventSystem - for event-driven communication
        3. StateManager - for game state persistence
        4. PathfindingSystem - for unit movement
        5. CommunicationBridge - for JS/PS communication
        6. CommandRegistry - for command handling
        
    .PARAMETER ConfigPath
        Path to the game configuration file
        
    .PARAMETER DebugMode
        Enable debug logging
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath = ".\Data\config.json",
        [switch]$DebugMode
    )
    
    Write-Host "Initializing game engine..." -ForegroundColor Cyan
    
    # Initialize logging first
    if (Get-Command Initialize-GameLogging -ErrorAction SilentlyContinue) {
        Initialize-GameLogging
        Write-Host "  ✓ GameLogging initialized" -ForegroundColor Green
    }
    
    # Enable debug mode if requested
    if ($DebugMode -and (Get-Command Enable-DebugLogging -ErrorAction SilentlyContinue)) {
        Enable-DebugLogging
    }
    
    # Initialize event system
    if (Get-Command Initialize-EventSystem -ErrorAction SilentlyContinue) {
        Initialize-EventSystem
        Write-Host "  ✓ EventSystem initialized" -ForegroundColor Green
    }
    
    # Initialize state manager
    if (Get-Command Initialize-StateManager -ErrorAction SilentlyContinue) {
        Initialize-StateManager
        Write-Host "  ✓ StateManager initialized" -ForegroundColor Green
    }
    
    # Initialize pathfinding
    if (Get-Command Initialize-PathfindingSystem -ErrorAction SilentlyContinue) {
        Initialize-PathfindingSystem
        Write-Host "  ✓ PathfindingSystem initialized" -ForegroundColor Green
    }
    
    # Initialize communication bridge
    if (Get-Command Initialize-CommunicationBridge -ErrorAction SilentlyContinue) {
        Initialize-CommunicationBridge
        Write-Host "  ✓ CommunicationBridge initialized" -ForegroundColor Green
    }
    
    # Initialize command registry
    if (Get-Command Initialize-CommandRegistry -ErrorAction SilentlyContinue) {
        Initialize-CommandRegistry
        Write-Host "  ✓ CommandRegistry initialized" -ForegroundColor Green
    }
    
    Write-Host "Game engine initialized successfully!" -ForegroundColor Green
    
    # Return engine configuration
    return @{
        Initialized = $true
        DebugMode   = $DebugMode.IsPresent
        ConfigPath  = $ConfigPath
        Version     = '0.2.0'
    }
}
