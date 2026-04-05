#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Builds a WinRE-based OSDCloud boot image and stamps the GitHub deployment URL into Startnet.cmd.

.DESCRIPTION
    Creates an OSDCloud workspace from a WinRE template, injects Intel WiFi drivers, and stamps
    the live deployment script URL into the boot image. Run this once - the USB never needs to
    be rebuilt when deployment config changes. To change what gets deployed, edit
    Deployment/Deploy-Windows11.ps1 and push to main.

    IMPORTANT: This script must be run on a Windows 10 build machine.
    Windows 11 WinRE is not compatible with older hardware.
    If your build machine runs Windows 11, use a Hyper-V VM with Windows 10 22H2.

.PARAMETER WorkspacePath
    Path where the OSDCloud workspace will be created. Default: C:\OSDCloud\WinRE-WiFi

.PARAMETER TemplateName
    Name for the OSDCloud template. Default: WinRE-WiFi

.PARAMETER Language
    Language code for the WinRE environment. Default: en-us

.PARAMETER SetInputLocale
    Input locale code. Default: 0c09:00000409 (Australian English)

.EXAMPLE
    .\BootImage\Build-WinREBootImage.ps1

.EXAMPLE
    .\BootImage\Build-WinREBootImage.ps1 -WorkspacePath 'C:\OSDCloud\MyBuild' -Language 'en-us'

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: OSDCloud module, Windows ADK, Windows 10 build machine
    Deploy URL: https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$WorkspacePath = 'C:\OSDCloud\WinRE-WiFi',

    [Parameter()]
    [string]$TemplateName = 'WinRE-WiFi',

    [Parameter()]
    [string]$Language = 'en-us',

    [Parameter()]
    [string]$SetInputLocale = '0c09:00000409'
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
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
$logFile = Join-Path $logDir "Build-WinREBootImage_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OSDCloud WinRE Boot Image Builder' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

# OS check
$osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
Write-Status "Build machine OS: $osCaption" -Status 'INFO'
Write-Log "Build machine OS: $osCaption"

if ($osCaption -match 'Windows 11') {
    Write-Host ''
    Write-Status '!! WARNING: Build machine is running Windows 11 !!' -Status 'WARN'
    Write-Status 'Windows 11 WinRE is NOT compatible with older hardware.' -Status 'WARN'
    Write-Status 'For maximum hardware compatibility, build on Windows 10 22H2.' -Status 'WARN'
    Write-Host ''
    $continue = Read-Host 'Continue anyway? Only do this if targeting Windows 11+ hardware exclusively. [Y/N]'
    if ($continue -notmatch '^[Yy]') {
        Write-Status 'Aborted. Please use a Windows 10 build machine or Hyper-V VM.' -Status 'WARN'
        exit 0
    }
    Write-Log 'User acknowledged Windows 11 build machine warning'
}

# Prerequisites check
Write-Status 'Verifying prerequisites...' -Status 'INFO'
$verifyScript = Join-Path $PSScriptRoot '..\Setup\Verify-Environment.ps1'
if (Test-Path $verifyScript) {
    try {
        & $verifyScript
        if ($LASTEXITCODE -ne 0) {
            Write-Status 'Prerequisites check failed. Run Setup\Install-Prerequisites.ps1 first.' -Status 'ERROR'
            exit 1
        }
    } catch {
        Write-Status "Could not run Verify-Environment.ps1: $_" -Status 'WARN'
        Write-Log "WARN: Verify-Environment.ps1 failed: $_"
    }
} else {
    Write-Status 'Verify-Environment.ps1 not found - skipping prereq check.' -Status 'WARN'
}

# OSDCloud module
try {
    Import-Module OSDCloud -Force -ErrorAction Stop
    Write-Status "OSDCloud module loaded: v$((Get-Module OSDCloud).Version)" -Status 'OK'
    Write-Log "OSDCloud module: v$((Get-Module OSDCloud).Version)"
} catch {
    Write-Status "OSDCloud module not found: $_" -Status 'ERROR'
    exit 1
}

# ---------------------------------------------------------------------------
# The deployment URL stamped into Startnet.cmd
# This is the ONLY value baked into the USB. Changing the script at this URL
# changes what all future deployments do - no USB rebuild required.
# ---------------------------------------------------------------------------
$DeployURL = 'https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1'

Write-Host ''
Write-Status "Deploy URL: $DeployURL" -Status 'INFO'
Write-Host ''

# ---------------------------------------------------------------------------
# Pre-Step - Dismount any stale WIM mounts from previous interrupted builds
# ---------------------------------------------------------------------------
Write-Status 'Checking for stale WIM mounts...' -Status 'INFO'
$staleMounts = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue
if ($staleMounts) {
    Write-Status "Found $($staleMounts.Count) stale mount(s) - dismounting..." -Status 'WARN'
    foreach ($mount in $staleMounts) {
        try {
            Dismount-WindowsImage -Path $mount.MountPath -Discard -ErrorAction Stop
            Write-Status "Dismounted: $($mount.MountPath)" -Status 'OK'
            Write-Log "Dismounted stale WIM: $($mount.MountPath)"
        } catch {
            Write-Status "Could not dismount $($mount.MountPath): $_" -Status 'WARN'
            Write-Log "WARN dismounting stale WIM: $_"
        }
    }
    # Clear any remaining mount metadata
    Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue
    Write-Status 'Stale mounts cleared.' -Status 'OK'
} else {
    Write-Status 'No stale mounts found.' -Status 'INFO'
}

# ---------------------------------------------------------------------------
# Steps 1-3 run under Windows PowerShell 5.1
# New-OSDCloudTemplate, New-OSDCloudWorkspace, and Edit-OSDCloudWinPE all
# use DISM COM components that fail under PowerShell 7 ("Class not registered").
# ---------------------------------------------------------------------------
$ps5 = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $ps5)) {
    Write-Status 'Windows PowerShell 5.1 not found - cannot continue.' -Status 'ERROR'
    exit 1
}

$dismScript = @"
# Add PS7 module path so PS5.1 can find modules installed via pwsh
`$ps7ModulePath = 'C:\Program Files\PowerShell\Modules'
if ((Test-Path `$ps7ModulePath) -and (`$env:PSModulePath -notlike "*`$ps7ModulePath*")) {
    `$env:PSModulePath = `$ps7ModulePath + ';' + `$env:PSModulePath
}

Import-Module OSDCloud -Force -ErrorAction Stop

# Step 1 - Create OSDCloud Template (WinRE)
Write-Host '[INFO] Creating OSDCloud template from WinRE...' -ForegroundColor Cyan
New-OSDCloudTemplate -WinRE -Name '$TemplateName' -Verbose
if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit 1 }

# Step 2 - Create OSDCloud Workspace
Write-Host '[INFO] Creating workspace at: $WorkspacePath' -ForegroundColor Cyan
New-OSDCloudWorkspace -WorkspacePath '$WorkspacePath' -Verbose
if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit 2 }

# Step 3 - Inject WiFi drivers and stamp deploy URL
Write-Host '[INFO] Injecting WiFi drivers and stamping deployment URL...' -ForegroundColor Cyan
Edit-OSDCloudWinPE -WorkspacePath '$WorkspacePath' -StartURL '$DeployURL' -CloudDriver WiFi -Verbose
if (`$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit 3 }
"@

Write-Status 'Running DISM operations under Windows PowerShell 5.1...' -Status 'INFO'
Write-Log 'Launching PS5.1 for DISM steps'

& $ps5 -NonInteractive -ExecutionPolicy Bypass -Command $dismScript

switch ($LASTEXITCODE) {
    0 {
        Write-Status 'Template created, workspace built, and deployment URL stamped.' -Status 'OK'
        Write-Log 'PS5.1 DISM steps completed successfully'
    }
    1 {
        Write-Status 'Failed to create OSDCloud template (Step 1).' -Status 'ERROR'
        Write-Log 'ERROR: Step 1 failed in PS5.1'
        exit 1
    }
    2 {
        Write-Status 'Failed to create OSDCloud workspace (Step 2).' -Status 'ERROR'
        Write-Log 'ERROR: Step 2 failed in PS5.1'
        exit 1
    }
    3 {
        Write-Status 'Failed to configure WinPE - WiFi drivers or deploy URL (Step 3).' -Status 'ERROR'
        Write-Log 'ERROR: Step 3 failed in PS5.1'
        exit 1
    }
    default {
        Write-Status "Unexpected exit code from PS5.1: $LASTEXITCODE" -Status 'ERROR'
        Write-Log "ERROR: Unexpected PS5.1 exit code: $LASTEXITCODE"
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  Boot Image Build Complete' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Status "Workspace:    $WorkspacePath" -Status 'INFO'
Write-Status "Deploy URL:   $DeployURL" -Status 'INFO'
Write-Status "Build OS:     $osCaption" -Status 'INFO'
Write-Status "Log:          $logFile" -Status 'INFO'
Write-Host ''
Write-Status 'Next steps:' -Status 'INFO'
Write-Host '  1. Run BootImage\New-OSDCloudISO.ps1 to generate the ISO' -ForegroundColor White
Write-Host '  2. Upload the ISO to Azure Files' -ForegroundColor White
Write-Host '  3. Update VERSION and CHANGELOG.md, then push' -ForegroundColor White
Write-Host ''
Write-Status 'REMINDER: The USB is now static. To change the deployment, edit' -Status 'WARN'
Write-Status "          Deployment\Deploy-Windows11.ps1 and push to main." -Status 'WARN'
Write-Host ''

Write-Log 'Build-WinREBootImage.ps1 completed successfully'
