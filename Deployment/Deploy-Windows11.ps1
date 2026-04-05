# Deploy-Windows11.ps1
# Fetched at boot time from: https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1
#
# Edit this file and push to main to change what all future deployments do.
# The USB never needs to be rebuilt - changes take effect immediately.
#
# Use -ZTI to run silently with no disk-wipe confirmation prompt.
#
# NOTE: No #Requires directives - this script runs in WinRE under PowerShell 5.1 as SYSTEM.
# Do not add [CmdletBinding()] or #Requires -Version/#Requires -RunAsAdministrator here.

param (
    [switch]$ZTI   # Silent mode - wipes disk without prompting
)

# =============================================================================
# Deployment Config
# Edit these values to change what gets deployed.
# =============================================================================
$OSVersion    = 'Windows 11'
$OSReleaseID  = '24H2'
$OSEdition    = 'Pro'      # Pro | Education | Enterprise
$OSLanguage   = 'en-au'
$OSActivation = 'Retail'   # Retail | Volume
$Restart      = $true

# =============================================================================
# WiFi Connection
# OSDCloud module downloads from PSGallery on boot - WiFi must be connected first.
# Start-WinREWiFi prompts for SSID and password if not already connected.
# =============================================================================
Write-Host '[OSDCloud] Checking network connectivity...' -ForegroundColor Cyan

$connected = $false
try {
    $testResult = Test-NetConnection -ComputerName 'www.microsoft.com' -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    $connected = $testResult
} catch {
    $connected = $false
}

if (-not $connected) {
    Write-Host '[OSDCloud] No network connection - launching WiFi setup...' -ForegroundColor Yellow
    Start-WinREWiFi
}

# =============================================================================
# Sync Time
# WinRE clock is often wrong; resync before downloading from Microsoft.
# =============================================================================
Write-Host '[OSDCloud] Syncing system clock...' -ForegroundColor Cyan
try {
    w32tm /resync /force 2>&1 | Out-Null
} catch {
    Write-Host '[OSDCloud] Warning: Could not sync time. Continuing anyway.' -ForegroundColor Yellow
}

# =============================================================================
# Deploy
# =============================================================================
Write-Host '[OSDCloud] Loading OSDCloud module...' -ForegroundColor Cyan
try {
    Import-Module OSDCloud -Force -ErrorAction Stop
} catch {
    Write-Host '[OSDCloud] ERROR: Could not load OSDCloud module. Ensure WiFi is connected.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "[OSDCloud] Starting deployment: $OSVersion $OSReleaseID $OSEdition ($OSLanguage)" -ForegroundColor Green

Start-OSDCloud -OSVersion    $OSVersion `
               -OSReleaseID  $OSReleaseID `
               -OSEdition    $OSEdition `
               -OSLanguage   $OSLanguage `
               -OSActivation $OSActivation `
               -ZTI:$ZTI `
               -Restart:$Restart
