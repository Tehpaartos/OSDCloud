#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Installs all prerequisites required to build the OSDCloud WinRE boot image.

.DESCRIPTION
    Two-phase approach:
      Phase 1 - Scans the system and reports what is installed vs missing.
      Phase 2 - Installs any missing components in the correct order.

    Run on a Windows 10 build machine. Windows 11 WinRE is not compatible with older hardware.
    If your build machine runs Windows 11, use a Hyper-V VM running Windows 10 22H2.

.EXAMPLE
    .\Setup\Install-Prerequisites.ps1

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: Windows 10 build machine, internet access
#>

[CmdletBinding()]
param ()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('OK','WARN','ERROR','INFO','SKIP')]
        [string]$Status = 'INFO'
    )
    $color = switch ($Status) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'INFO'  { 'Cyan' }
        'SKIP'  { 'DarkGray' }
        default { 'White' }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

function Test-ADKInstalled {
    $adkPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    if (Test-Path $adkPath) {
        $root = (Get-ItemProperty $adkPath -ErrorAction SilentlyContinue).KitsRoot10
        return ($null -ne $root -and (Test-Path $root))
    }
    return $false
}

function Get-ADKVersion {
    $adkPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    if (Test-Path $adkPath) {
        return (Get-ItemProperty $adkPath -ErrorAction SilentlyContinue).KitsRoot10
    }
    return $null
}

function Test-ModuleInstalled {
    param([string]$Name)
    return $null -ne (Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1)
}

# ---------------------------------------------------------------------------
# Phase 1 - Scan
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OSDCloud Prerequisites - Phase 1: Environment Scan' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

$scan = @()

# Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$scan += [PSCustomObject]@{ Component = 'Administrator'; Status = if ($isAdmin) { 'OK' } else { 'MISSING' }; Detail = if ($isAdmin) { 'Running as Administrator' } else { 'Must re-run as Administrator' } }

# PowerShell 7
$ps7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
$scan += [PSCustomObject]@{ Component = 'PowerShell 7'; Status = if ($ps7) { 'OK' } else { 'MISSING' }; Detail = if ($ps7) { $ps7.Version.ToString() } else { 'Not found in PATH' } }

# TLS 1.2
$tlsOk = ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) -ne 0
$scan += [PSCustomObject]@{ Component = 'TLS 1.2'; Status = if ($tlsOk) { 'OK' } else { 'MISSING' }; Detail = if ($tlsOk) { 'Enabled' } else { 'Not enforced' } }

# NuGet provider
$nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
$scan += [PSCustomObject]@{ Component = 'NuGet Provider'; Status = if ($nuget) { 'OK' } else { 'MISSING' }; Detail = if ($nuget) { $nuget.Version.ToString() } else { 'Not installed' } }

# PSGallery trusted
$gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
$galleryTrusted = $gallery -and $gallery.InstallationPolicy -eq 'Trusted'
$scan += [PSCustomObject]@{ Component = 'PSGallery Trusted'; Status = if ($galleryTrusted) { 'OK' } else { 'MISSING' }; Detail = if ($galleryTrusted) { 'Trusted' } else { 'Not trusted' } }

# PowerShellGet
$psget = Get-Module -ListAvailable PowerShellGet -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
$scan += [PSCustomObject]@{ Component = 'PowerShellGet'; Status = if ($psget) { 'OK' } else { 'MISSING' }; Detail = if ($psget) { $psget.Version.ToString() } else { 'Not found' } }

# Windows ADK
$adkOk = Test-ADKInstalled
$scan += [PSCustomObject]@{ Component = 'Windows ADK'; Status = if ($adkOk) { 'OK' } else { 'MISSING' }; Detail = if ($adkOk) { Get-ADKVersion } else { 'Not installed' } }

# OSD module
$osdOk = Test-ModuleInstalled -Name 'OSD'
$scan += [PSCustomObject]@{ Component = 'OSD Module'; Status = if ($osdOk) { 'OK' } else { 'MISSING' }; Detail = if ($osdOk) { (Get-Module -ListAvailable OSD | Sort-Object Version -Descending | Select-Object -First 1).Version.ToString() } else { 'Not installed' } }

# OSDCloud module
$osdCloudOk = Test-ModuleInstalled -Name 'OSDCloud'
$scan += [PSCustomObject]@{ Component = 'OSDCloud Module'; Status = if ($osdCloudOk) { 'OK' } else { 'MISSING' }; Detail = if ($osdCloudOk) { (Get-Module -ListAvailable OSDCloud | Sort-Object Version -Descending | Select-Object -First 1).Version.ToString() } else { 'Not installed' } }

# Print scan table
$scan | Format-Table -Property Component, Status, Detail -AutoSize

$missing = $scan | Where-Object { $_.Status -eq 'MISSING' }
if ($missing.Count -eq 0) {
    Write-Status 'All prerequisites are already installed.' -Status 'OK'
    Write-Host ''
    Write-Status 'Run Setup\Verify-Environment.ps1 to confirm the environment is ready.' -Status 'INFO'
    exit 0
}

Write-Host ''
Write-Host "Found $($missing.Count) missing component(s)." -ForegroundColor Yellow
Write-Host ''

$confirm = Read-Host 'Install missing components now? [Y/N]'
if ($confirm -notmatch '^[Yy]') {
    Write-Status 'Aborted by user.' -Status 'SKIP'
    exit 0
}

# ---------------------------------------------------------------------------
# Phase 2 - Install
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OSDCloud Prerequisites - Phase 2: Installation' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

$logDir = "$env:ProgramData\OSDCloud\Logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "Install-Prerequisites_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

Write-Log 'Install-Prerequisites.ps1 started'

# 1. PowerShell 7
if (-not $ps7) {
    Write-Status 'Installing PowerShell 7...' -Status 'INFO'
    try {
        $ps7InstallerUrl = 'https://aka.ms/install-powershell.ps1'
        Invoke-Expression "& { $(Invoke-RestMethod $ps7InstallerUrl) } -UseMSI -Quiet"
        Write-Log 'PowerShell 7 installed'
        Write-Status 'PowerShell 7 installed. Please re-run this script in a new PowerShell 7 session.' -Status 'WARN'
        Write-Host ''
        Write-Host '  pwsh.exe .\Setup\Install-Prerequisites.ps1' -ForegroundColor White
        exit 0
    } catch {
        Write-Status "Failed to install PowerShell 7: $_" -Status 'ERROR'
        Write-Log "ERROR installing PowerShell 7: $_"
        exit 1
    }
}

# 2. Execution policy
Write-Status 'Setting execution policy to RemoteSigned (CurrentUser)...' -Status 'INFO'
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Log 'Execution policy set to RemoteSigned'
    Write-Status 'Execution policy set.' -Status 'OK'
} catch {
    Write-Status "Could not set execution policy: $_" -Status 'WARN'
    Write-Log "WARN setting execution policy: $_"
}

# 3. TLS 1.2
if (-not $tlsOk) {
    Write-Status 'Enforcing TLS 1.2...' -Status 'INFO'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Log 'TLS 1.2 enforced'
    Write-Status 'TLS 1.2 enforced.' -Status 'OK'
} else {
    Write-Status 'TLS 1.2 already enforced.' -Status 'OK'
}

# 4. NuGet provider
if (-not $nuget) {
    Write-Status 'Installing NuGet package provider...' -Status 'INFO'
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        Write-Log 'NuGet provider installed'
        Write-Status 'NuGet provider installed.' -Status 'OK'
    } catch {
        Write-Status "Failed to install NuGet: $_" -Status 'ERROR'
        Write-Log "ERROR installing NuGet: $_"
        exit 1
    }
}

# 5. PSGallery trusted
if (-not $galleryTrusted) {
    Write-Status 'Registering PSGallery as trusted...' -Status 'INFO'
    try {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Write-Log 'PSGallery set to Trusted'
        Write-Status 'PSGallery trusted.' -Status 'OK'
    } catch {
        Write-Status "Could not trust PSGallery: $_" -Status 'WARN'
        Write-Log "WARN trusting PSGallery: $_"
    }
}

# 6. PowerShellGet
Write-Status 'Updating PowerShellGet...' -Status 'INFO'
try {
    Install-Module PowerShellGet -Force -AllowClobber -Scope AllUsers
    Write-Log 'PowerShellGet updated'
    Write-Status 'PowerShellGet updated.' -Status 'OK'
} catch {
    Write-Status "Could not update PowerShellGet: $_" -Status 'WARN'
    Write-Log "WARN updating PowerShellGet: $_"
}

# 7. Windows ADK
if (-not $adkOk) {
    Write-Status 'Windows ADK is not installed.' -Status 'WARN'
    Write-Host ''
    Write-Host '  Download Windows ADK (Deployment Tools only) from:' -ForegroundColor White
    Write-Host '  https://go.microsoft.com/fwlink/?linkid=2289980' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Install with: adksetup.exe /features OptionId.DeploymentTools /quiet /norestart' -ForegroundColor White
    Write-Host ''
    Write-Status 'Please install Windows ADK manually, then re-run this script.' -Status 'WARN'
    Write-Log 'ADK not installed - prompted user to install manually'
}

# 8. OSD module
if (-not $osdOk) {
    Write-Status 'Installing OSD module...' -Status 'INFO'
    try {
        Install-Module OSD -Force -Scope AllUsers
        Write-Log 'OSD module installed'
        Write-Status 'OSD module installed.' -Status 'OK'
    } catch {
        Write-Status "Failed to install OSD module: $_" -Status 'ERROR'
        Write-Log "ERROR installing OSD module: $_"
        exit 1
    }
}

# 9. OSDCloud module
if (-not $osdCloudOk) {
    Write-Status 'Installing OSDCloud module...' -Status 'INFO'
    try {
        Install-Module OSDCloud -Force -Scope AllUsers
        Write-Log 'OSDCloud module installed'
        Write-Status 'OSDCloud module installed.' -Status 'OK'
    } catch {
        Write-Status "Failed to install OSDCloud module: $_" -Status 'ERROR'
        Write-Log "ERROR installing OSDCloud module: $_"
        exit 1
    }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  Installation complete.' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Status "Log saved to: $logFile" -Status 'INFO'
Write-Status 'Run Setup\Verify-Environment.ps1 to confirm everything is ready.' -Status 'INFO'
Write-Log 'Install-Prerequisites.ps1 completed'
