#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Full rebuild of the OSDCloud WinRE boot image after module or ADK updates.

.DESCRIPTION
    Runs the complete refresh pipeline:
      1. Updates OSD and OSDCloud modules
      2. Removes the existing WinRE workspace
      3. Rebuilds the WinRE boot image (calls Build-WinREBootImage.ps1)
      4. Regenerates the ISO (calls New-OSDCloudISO.ps1)
      5. Outputs ISO location and SHA256 hash
      6. Prompts to update VERSION file with the new version number
      7. Reminds repo owner to upload the new ISO to Azure Files

    Run this after: OSD/OSDCloud module updates, Windows ADK updates,
    or any time the boot image itself needs to change (driver additions, etc.).

.PARAMETER WorkspacePath
    Path to the OSDCloud WinRE workspace. Default: C:\OSDCloud\WinRE-WiFi

.PARAMETER IsoOutputPath
    Directory where the regenerated ISO will be saved. Default: C:\OSDCloud\ISO

.PARAMETER SkipModuleUpdate
    Skip the module update step. Use when modules were already updated manually.

.EXAMPLE
    .\Maintenance\Refresh-BootImage.ps1

.EXAMPLE
    .\Maintenance\Refresh-BootImage.ps1 -SkipModuleUpdate

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: OSDCloud module, Windows ADK, Windows 10 build machine
    WARNING: Deletes and recreates the WinRE workspace at WorkspacePath
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [string]$WorkspacePath = 'C:\OSDCloud\WinRE-WiFi',

    [Parameter()]
    [string]$IsoOutputPath = 'C:\OSDCloud\ISO',

    [Parameter()]
    [switch]$SkipModuleUpdate
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
$logFile = Join-Path $logDir "Refresh-BootImage_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

$scriptRoot = $PSScriptRoot

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OSDCloud Boot Image Refresh' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Log 'Refresh-BootImage.ps1 started'

# Step 1 - Update modules
if (-not $SkipModuleUpdate) {
    Write-Status 'Step 1/4: Updating OSD modules...' -Status 'INFO'
    $updateScript = Join-Path $scriptRoot 'Update-OSDModules.ps1'
    try {
        & $updateScript
        Write-Log 'Module update completed'
    } catch {
        Write-Status "Module update failed: $_" -Status 'WARN'
        Write-Log "WARN: Module update failed: $_"
    }
} else {
    Write-Status 'Step 1/4: Skipping module update (-SkipModuleUpdate).' -Status 'INFO'
}

# Step 2 - Remove old workspace
Write-Status "Step 2/4: Removing existing workspace at: $WorkspacePath" -Status 'INFO'
if (Test-Path $WorkspacePath) {
    if ($PSCmdlet.ShouldProcess($WorkspacePath, 'Remove existing workspace')) {
        try {
            Remove-Item -Path $WorkspacePath -Recurse -Force
            Write-Status 'Old workspace removed.' -Status 'OK'
            Write-Log "Removed workspace: $WorkspacePath"
        } catch {
            Write-Status "Failed to remove workspace: $_" -Status 'ERROR'
            Write-Log "ERROR removing workspace: $_"
            exit 1
        }
    }
} else {
    Write-Status 'No existing workspace found - proceeding with fresh build.' -Status 'INFO'
}

# Step 3 - Rebuild WinRE boot image
Write-Status 'Step 3/4: Rebuilding WinRE boot image...' -Status 'INFO'
$buildScript = Join-Path $scriptRoot '..\BootImage\Build-WinREBootImage.ps1'
if (-not (Test-Path $buildScript)) {
    Write-Status "Build script not found: $buildScript" -Status 'ERROR'
    exit 1
}
try {
    & $buildScript -WorkspacePath $WorkspacePath
    if ($LASTEXITCODE -ne 0) { throw "Build-WinREBootImage.ps1 exited with code $LASTEXITCODE" }
    Write-Status 'WinRE boot image rebuilt.' -Status 'OK'
    Write-Log 'Build-WinREBootImage.ps1 completed'
} catch {
    Write-Status "Boot image rebuild failed: $_" -Status 'ERROR'
    Write-Log "ERROR in Build-WinREBootImage.ps1: $_"
    exit 1
}

# Step 4 - Regenerate ISO
Write-Status 'Step 4/4: Regenerating ISO...' -Status 'INFO'
$isoScript = Join-Path $scriptRoot '..\BootImage\New-OSDCloudISO.ps1'
if (-not (Test-Path $isoScript)) {
    Write-Status "ISO script not found: $isoScript" -Status 'ERROR'
    exit 1
}
try {
    & $isoScript -WorkspacePath $WorkspacePath -OutputPath $IsoOutputPath
    if ($LASTEXITCODE -ne 0) { throw "New-OSDCloudISO.ps1 exited with code $LASTEXITCODE" }
    Write-Status 'ISO regenerated.' -Status 'OK'
    Write-Log 'New-OSDCloudISO.ps1 completed'
} catch {
    Write-Status "ISO generation failed: $_" -Status 'ERROR'
    Write-Log "ERROR in New-OSDCloudISO.ps1: $_"
    exit 1
}

# --- Version bump prompt ---
$versionFile = Join-Path $scriptRoot '..\VERSION'
$currentVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'unknown' }

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  Boot Image Refresh Complete' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Status "Current VERSION: $currentVersion" -Status 'INFO'
Write-Host ''
$newVersion = Read-Host "Enter new version (leave blank to keep '$currentVersion')"

if ($newVersion -and $newVersion -ne $currentVersion) {
    if ($newVersion -match '^\d+\.\d+\.\d+$') {
        Set-Content -Path $versionFile -Value $newVersion
        Write-Status "VERSION updated to: $newVersion" -Status 'OK'
        Write-Log "VERSION updated: $currentVersion -> $newVersion"
    } else {
        Write-Status "Invalid version format '$newVersion' - VERSION not changed. Use MAJOR.MINOR.PATCH." -Status 'WARN'
    }
}

Write-Host ''
Write-Status 'NEXT STEPS:' -Status 'WARN'
Write-Host "  1. Upload the new ISO from $IsoOutputPath to Azure Files" -ForegroundColor White
Write-Host '  2. Update CHANGELOG.md with the new version entry' -ForegroundColor White
Write-Host '  3. Commit VERSION and CHANGELOG.md, then push to main' -ForegroundColor White
Write-Host '  4. Verify https://download.osdcloud.tehpaartos.com/osdcloud/OSDCloud.iso downloads' -ForegroundColor White
Write-Host ''
Write-Status "Log saved to: $logFile" -Status 'INFO'
Write-Log 'Refresh-BootImage.ps1 completed'
