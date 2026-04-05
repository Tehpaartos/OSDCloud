#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Applies Out-of-Box (OOB) drivers to the deployed Windows OS after installation.

.DESCRIPTION
    OSDCloud V2 feature (requires module version 25.3.27.1+).
    Run this after OS deployment completes and before the first reboot into Windows,
    to ensure drivers are current on the installed OS.

    This is separate from WinRE environment drivers (which are injected by Build-WinREBootImage.ps1).
    OOB drivers target the installed Windows OS, not the WinPE/WinRE environment.

.PARAMETER WindowsTargetPath
    Mount point of the target Windows installation. Default: C:\

.EXAMPLE
    .\BootImage\Apply-WinOSDrivers.ps1

.EXAMPLE
    .\BootImage\Apply-WinOSDrivers.ps1 -WindowsTargetPath 'C:\'

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: OSDCloud module v25.3.27.1+
    Run after: Start-OSDCloud completes, before first reboot into Windows
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$WindowsTargetPath = 'C:\'
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
$logFile = Join-Path $logDir "Apply-WinOSDrivers_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

Write-Log 'Apply-WinOSDrivers.ps1 started'

# Validate target
if (-not (Test-Path $WindowsTargetPath)) {
    Write-Status "Windows target path not found: $WindowsTargetPath" -Status 'ERROR'
    exit 1
}

# Load module
try {
    Import-Module OSDCloud -Force -ErrorAction Stop
    $moduleVersion = (Get-Module OSDCloud).Version
    Write-Status "OSDCloud module loaded: v$moduleVersion" -Status 'OK'
    Write-Log "OSDCloud module: v$moduleVersion"

    # Version check - OOB driver support requires 25.3.27.1+
    $minVersion = [Version]'25.3.27.1'
    if ($moduleVersion -lt $minVersion) {
        Write-Status "OSDCloud module v$moduleVersion is older than v$minVersion." -Status 'WARN'
        Write-Status 'OOB driver support may not be available. Run Maintenance\Update-OSDModules.ps1 first.' -Status 'WARN'
        Write-Log "WARN: Module version $moduleVersion < $minVersion"
    }
} catch {
    Write-Status "OSDCloud module not found: $_" -Status 'ERROR'
    exit 1
}

# Apply OOB drivers
Write-Status "Applying OOB drivers to Windows installation at: $WindowsTargetPath" -Status 'INFO'
Write-Log "Target: $WindowsTargetPath"

try {
    # OSDCloud V2 - Apply OOB Drivers to WinOS
    # This targets the installed Windows OS, not the WinRE environment
    Invoke-OSDCloudDrivers -WindowsTargetPath $WindowsTargetPath -Verbose
    Write-Status 'OOB drivers applied successfully.' -Status 'OK'
    Write-Log 'OOB drivers applied'
} catch {
    Write-Status "Failed to apply OOB drivers: $_" -Status 'ERROR'
    Write-Log "ERROR applying OOB drivers: $_"
    exit 1
}

Write-Status "Log saved to: $logFile" -Status 'INFO'
Write-Log 'Apply-WinOSDrivers.ps1 completed'
