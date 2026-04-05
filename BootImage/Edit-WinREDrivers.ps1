#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Injects supplemental drivers into an existing OSDCloud WinRE workspace.

.DESCRIPTION
    Use this script when you need drivers beyond the built-in WiFi CloudDriver - for example,
    vendor-specific storage or NIC drivers for hardware the CloudDriver set does not cover.

    Intel WiFi drivers are already handled by Build-WinREBootImage.ps1 via -CloudDriver WiFi.
    This script is for supplemental drivers only.

.PARAMETER WorkspacePath
    Path to the existing OSDCloud WinRE workspace. Default: C:\OSDCloud\WinRE-WiFi

.PARAMETER CloudDrivers
    Array of CloudDriver sources to add. Options: Dell, HP, Lenovo, Surface, WiFi, Ethernet.
    Example: @('Dell','HP','Surface')

.PARAMETER HardwareID
    Optional specific hardware ID to target from the Microsoft Update Catalog.

.PARAMETER DriverPath
    Optional path to a local folder containing INF/driver files to inject.

.EXAMPLE
    .\BootImage\Edit-WinREDrivers.ps1 -CloudDrivers 'Dell','HP','Surface'

.EXAMPLE
    .\BootImage\Edit-WinREDrivers.ps1 -DriverPath 'C:\Drivers\NIC'

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: OSDCloud module, existing WinRE workspace
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$WorkspacePath = 'C:\OSDCloud\WinRE-WiFi',

    [Parameter()]
    [string[]]$CloudDrivers,

    [Parameter()]
    [string]$HardwareID,

    [Parameter()]
    [string]$DriverPath
)

function Write-Status {
    param([string]$Message, [string]$Status = 'INFO')
    $color = switch ($Status) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'INFO'  { 'Cyan' }
        default { 'White' }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

$logDir = "$env:ProgramData\OSDCloud\Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "Edit-WinREDrivers_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

Write-Log 'Edit-WinREDrivers.ps1 started'

# Validate workspace
if (-not (Test-Path $WorkspacePath)) {
    Write-Status "Workspace not found: $WorkspacePath" -Status 'ERROR'
    Write-Status 'Run BootImage\Build-WinREBootImage.ps1 first.' -Status 'ERROR'
    exit 1
}

# Load module
try {
    Import-Module OSDCloud -Force -ErrorAction Stop
    Write-Status "OSDCloud module loaded: v$((Get-Module OSDCloud).Version)" -Status 'OK'
} catch {
    Write-Status "OSDCloud module not found: $_" -Status 'ERROR'
    exit 1
}

# Validate that at least one driver source was specified
if (-not $CloudDrivers -and -not $HardwareID -and -not $DriverPath) {
    Write-Status 'No driver source specified. Provide -CloudDrivers, -HardwareID, or -DriverPath.' -Status 'WARN'
    Write-Host ''
    Write-Host '  Examples:' -ForegroundColor White
    Write-Host "    .\BootImage\Edit-WinREDrivers.ps1 -CloudDrivers 'Dell','HP'" -ForegroundColor Gray
    Write-Host "    .\BootImage\Edit-WinREDrivers.ps1 -DriverPath 'C:\Drivers\NIC'" -ForegroundColor Gray
    exit 0
}

try {
    $editParams = @{
        WorkspacePath = $WorkspacePath
        Verbose       = $true
    }

    if ($CloudDrivers) {
        Write-Status "Adding CloudDrivers: $($CloudDrivers -join ', ')" -Status 'INFO'
        Write-Log "CloudDrivers: $($CloudDrivers -join ', ')"
        $editParams['CloudDriver'] = $CloudDrivers
    }

    if ($HardwareID) {
        Write-Status "Targeting HardwareID: $HardwareID" -Status 'INFO'
        Write-Log "HardwareID: $HardwareID"
        $editParams['HardwareID'] = $HardwareID
    }

    if ($DriverPath) {
        if (-not (Test-Path $DriverPath)) {
            Write-Status "DriverPath not found: $DriverPath" -Status 'ERROR'
            exit 1
        }
        Write-Status "Injecting local drivers from: $DriverPath" -Status 'INFO'
        Write-Log "DriverPath: $DriverPath"
        $editParams['DriverPath'] = $DriverPath
    }

    Edit-OSDCloudWinPE @editParams
    Write-Status 'Driver injection complete.' -Status 'OK'
    Write-Log 'Driver injection completed'
} catch {
    Write-Status "Driver injection failed: $_" -Status 'ERROR'
    Write-Log "ERROR: $_"
    exit 1
}

Write-Status "Log saved to: $logFile" -Status 'INFO'
Write-Log 'Edit-WinREDrivers.ps1 completed'
