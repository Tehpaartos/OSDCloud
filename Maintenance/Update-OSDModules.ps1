#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Updates OSD and OSDCloud PowerShell modules to their latest versions.

.DESCRIPTION
    Checks current installed versions, updates both modules from PSGallery,
    and outputs a before/after version table.

    Run this before rebuilding the boot image to ensure the latest OSDCloud
    features and driver support are included.

.EXAMPLE
    .\Maintenance\Update-OSDModules.ps1

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: OSD and OSDCloud modules installed, internet access
#>

[CmdletBinding()]
param ()

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
$logFile = Join-Path $logDir "Update-OSDModules_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

Write-Log 'Update-OSDModules.ps1 started'

# Enforce TLS 1.2 for PSGallery
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Snapshot versions before update
$before = @{}
foreach ($name in @('OSD', 'OSDCloud')) {
    $mod = Get-Module -ListAvailable $name -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    $before[$name] = if ($mod) { $mod.Version.ToString() } else { 'Not installed' }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OSDCloud Module Update' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Status "OSD before:      $($before['OSD'])" -Status 'INFO'
Write-Status "OSDCloud before: $($before['OSDCloud'])" -Status 'INFO'
Write-Host ''

# Update OSD
Write-Status 'Updating OSD module...' -Status 'INFO'
try {
    Update-Module OSD -Force -ErrorAction Stop
    Write-Log 'OSD module updated'
    Write-Status 'OSD module updated.' -Status 'OK'
} catch {
    Write-Status "Failed to update OSD module: $_" -Status 'ERROR'
    Write-Log "ERROR updating OSD: $_"
}

# Update OSDCloud
Write-Status 'Updating OSDCloud module...' -Status 'INFO'
try {
    Update-Module OSDCloud -Force -ErrorAction Stop
    Write-Log 'OSDCloud module updated'
    Write-Status 'OSDCloud module updated.' -Status 'OK'
} catch {
    Write-Status "Failed to update OSDCloud module: $_" -Status 'ERROR'
    Write-Log "ERROR updating OSDCloud: $_"
}

# Snapshot versions after update
$after = @{}
foreach ($name in @('OSD', 'OSDCloud')) {
    $mod = Get-Module -ListAvailable $name -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    $after[$name] = if ($mod) { $mod.Version.ToString() } else { 'Not installed' }
}

# Summary table
Write-Host ''
Write-Host '  Module        Before              After' -ForegroundColor White
Write-Host '  ------------- ------------------- -------------------' -ForegroundColor DarkGray
foreach ($name in @('OSD', 'OSDCloud')) {
    $changed = $before[$name] -ne $after[$name]
    $color = if ($changed) { 'Green' } else { 'Gray' }
    Write-Host ("  {0,-13} {1,-19} {2}" -f $name, $before[$name], $after[$name]) -ForegroundColor $color
    Write-Log "$name: $($before[$name]) -> $($after[$name])"
}
Write-Host ''

Write-Status "Log saved to: $logFile" -Status 'INFO'

if ($before['OSD'] -ne $after['OSD'] -or $before['OSDCloud'] -ne $after['OSDCloud']) {
    Write-Host ''
    Write-Status 'Modules updated. Consider running Maintenance\Refresh-BootImage.ps1 to' -Status 'WARN'
    Write-Status 'rebuild the boot image with the latest module versions.' -Status 'WARN'
}

Write-Log 'Update-OSDModules.ps1 completed'
