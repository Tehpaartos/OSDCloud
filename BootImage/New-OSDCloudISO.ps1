#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a bootable ISO from the OSDCloud WinRE workspace.

.DESCRIPTION
    Creates two ISO variants from the active workspace:
      - Standard:   Prompts for a keypress on boot before starting WinPE.
      - NoPrompt:   Boots directly into WinPE without any keypress prompt.

    The ISO filename includes the version from the VERSION file in the repo root,
    e.g. OSDCloud-v1.0.0.iso, so it is clear which version to upload to Azure Files.

.PARAMETER WorkspacePath
    Path to the OSDCloud WinRE workspace. Default: C:\OSDCloud\WinRE-WiFi

.PARAMETER OutputPath
    Directory where ISOs will be saved. Default: C:\OSDCloud\ISO

.PARAMETER VersionFilePath
    Path to the VERSION file. Default: auto-detected relative to this script.

.EXAMPLE
    .\BootImage\New-OSDCloudISO.ps1

.EXAMPLE
    .\BootImage\New-OSDCloudISO.ps1 -WorkspacePath 'C:\OSDCloud\WinRE-WiFi' -OutputPath 'D:\ISO'

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: OSDCloud module, completed WinRE workspace (run Build-WinREBootImage.ps1 first)
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$WorkspacePath = 'C:\OSDCloud\WinRE-WiFi',

    [Parameter()]
    [string]$OutputPath = 'C:\OSDCloud\ISO',

    [Parameter()]
    [string]$VersionFilePath
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
$logFile = Join-Path $logDir "New-OSDCloudISO_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

Write-Log 'New-OSDCloudISO.ps1 started'

# --- Read VERSION ---
if (-not $VersionFilePath) {
    $VersionFilePath = Join-Path $PSScriptRoot '..\VERSION'
}

$version = '0.0.0'
if (Test-Path $VersionFilePath) {
    $version = (Get-Content $VersionFilePath -Raw).Trim()
    Write-Status "ISO version: $version (from VERSION file)" -Status 'INFO'
    Write-Log "Version: $version"
} else {
    Write-Status "VERSION file not found at $VersionFilePath - using 0.0.0" -Status 'WARN'
    Write-Log "WARN: VERSION file not found, defaulting to 0.0.0"
}

# --- Validate workspace ---
if (-not (Test-Path $WorkspacePath)) {
    Write-Status "Workspace not found: $WorkspacePath" -Status 'ERROR'
    Write-Status 'Run BootImage\Build-WinREBootImage.ps1 first.' -Status 'ERROR'
    exit 1
}

# --- Output directory ---
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Log "Created output directory: $OutputPath"
}

# --- Load module ---
try {
    Import-Module OSDCloud -Force -ErrorAction Stop
    Write-Status "OSDCloud module loaded: v$((Get-Module OSDCloud).Version)" -Status 'OK'
} catch {
    Write-Status "OSDCloud module not found: $_" -Status 'ERROR'
    exit 1
}

$isoStandard = Join-Path $OutputPath "OSDCloud-v${version}.iso"

# --- Generate ISO ---
# New-OSDCloudISO writes to a fixed location inside the workspace.
# We generate it then move it to the versioned output path.
Write-Status 'Generating ISO...' -Status 'INFO'
Write-Log 'Calling New-OSDCloudISO'
try {
    New-OSDCloudISO -WorkspacePath $WorkspacePath -Verbose
    Write-Status 'ISO created.' -Status 'OK'
    Write-Log 'New-OSDCloudISO completed'
} catch {
    Write-Status "Failed to create ISO: $_" -Status 'ERROR'
    Write-Log "ERROR creating ISO: $_"
    exit 1
}

# --- Find and move generated ISOs ---
# OSDCloud generates both standard and NoPrompt ISOs in a fixed location.
# Search the workspace and its parent for any ISOs created in the last 10 minutes.
if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }

$searchPaths = @($WorkspacePath, (Split-Path $WorkspacePath))
$cutoff = (Get-Date).AddMinutes(-10)
$generatedISOs = $searchPaths | ForEach-Object {
    Get-ChildItem -Path $_ -Filter '*.iso' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $cutoff }
} | Sort-Object { $_.Name -notlike '*NoPrompt*' }  # standard first

$isoStandard = $null
$isoNoPrompt = $null

foreach ($iso in $generatedISOs) {
    if (-not (Test-Path $iso.FullName)) {
        Write-Log "SKIP: $($iso.FullName) no longer exists (already moved)"
        continue
    }
    if ($iso.Name -like '*NoPrompt*') {
        $dest = Join-Path $OutputPath "OSDCloud-v${version}-NoPrompt.iso"
        Move-Item -Path $iso.FullName -Destination $dest -Force
        $isoNoPrompt = $dest
        Write-Status "NoPrompt ISO moved to: $dest" -Status 'OK'
        Write-Log "NoPrompt ISO moved: $($iso.FullName) -> $dest"
    } else {
        $dest = Join-Path $OutputPath "OSDCloud-v${version}.iso"
        Move-Item -Path $iso.FullName -Destination $dest -Force
        $isoStandard = $dest
        Write-Status "Standard ISO moved to: $dest" -Status 'OK'
        Write-Log "Standard ISO moved: $($iso.FullName) -> $dest"
    }
}

if (-not $isoStandard -and -not $isoNoPrompt) {
    Write-Status 'ISOs were generated but could not be located. Check the workspace folder.' -Status 'WARN'
    Write-Log 'WARN: Could not locate generated ISOs'
}

# --- SHA256 hashes ---
Write-Host ''
Write-Status 'SHA256 Hashes (for verification):' -Status 'INFO'
foreach ($iso in @($isoStandard, $isoNoPrompt) | Where-Object { $_ -and (Test-Path $_) }) {
    $hash = (Get-FileHash -Path $iso -Algorithm SHA256).Hash
    $size = [math]::Round((Get-Item $iso).Length / 1MB, 1)
    Write-Host "  $([System.IO.Path]::GetFileName($iso))" -ForegroundColor White
    Write-Host "    SHA256: $hash" -ForegroundColor Gray
    Write-Host "    Size:   ${size} MB" -ForegroundColor Gray
    Write-Log "$([System.IO.Path]::GetFileName($iso)) SHA256=$hash Size=${size}MB"
}

# --- Summary ---
Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  ISO Generation Complete' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Status "Output directory: $OutputPath" -Status 'INFO'
Write-Status "Log: $logFile" -Status 'INFO'
Write-Host ''
Write-Status 'Next steps:' -Status 'INFO'
Write-Host "  1. Upload OSDCloud-v${version}.iso to Azure Files" -ForegroundColor White
Write-Host '  2. Verify https://download.osdcloud.tehpaartos.com/osdcloud/OSDCloud.iso downloads' -ForegroundColor White
Write-Host "  3. Update VERSION file to: $version" -ForegroundColor White
Write-Host '  4. Add entry to CHANGELOG.md and push' -ForegroundColor White
Write-Host ''

Write-Log 'New-OSDCloudISO.ps1 completed'
