#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Installs all prerequisites required to build the OSDCloud WinRE boot image.

.DESCRIPTION
    Two-phase approach:
      Phase 1 - Scans the system and reports what is installed vs missing.
      Phase 2 - Installs any missing components in the correct order.

    Run on a Windows 10 22H2 build machine. Windows 11 WinRE is not compatible with older hardware.
    If your build machine runs Windows 11, use a Hyper-V VM running Windows 10 22H2.

.EXAMPLE
    .\Setup\Install-Prerequisites.ps1

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: Windows 10 22H2 build machine, internet access
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

function Get-ADKRoot {
    $regPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    if (Test-Path $regPath) {
        $root = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).KitsRoot10
        if ($root) { return $root.TrimEnd('\') }
    }
    # Fallback to known default locations
    $defaults = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10",
        "$env:ProgramFiles\Windows Kits\10"
    )
    return $defaults | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Test-ADKInstalled {
    return $null -ne (Get-ADKRoot)
}

function Get-ADKVersion {
    return Get-ADKRoot
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

# TLS 1.2 - check registry so result is consistent across sessions
$tlsReg64 = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name SchUseStrongCrypto -ErrorAction SilentlyContinue).SchUseStrongCrypto -eq 1
$tlsReg32 = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Name SchUseStrongCrypto -ErrorAction SilentlyContinue).SchUseStrongCrypto -eq 1
$tlsOk = $tlsReg64 -and $tlsReg32
$scan += [PSCustomObject]@{ Component = 'TLS 1.2'; Status = if ($tlsOk) { 'OK' } else { 'MISSING' }; Detail = if ($tlsOk) { 'Registry persisted' } else { 'Not persisted in registry' } }

# NuGet provider (minimum 2.8.5.201 required by PowerShellGet)
$nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
$nugetOk = $null -ne $nuget -and $nuget.Version -ge [Version]'2.8.5.201'
$scan += [PSCustomObject]@{ Component = 'NuGet Provider'; Status = if ($nugetOk) { 'OK' } else { 'MISSING' }; Detail = if ($nugetOk) { $nuget.Version.ToString() } elseif ($nuget) { "v$($nuget.Version) - too old" } else { 'Not installed' } }

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

# Windows PE Add-on
$winPEOk = $false
if ($adkOk) {
    $adkRoot = Get-ADKVersion
    $winPERoot = Join-Path $adkRoot 'Assessment and Deployment Kit\Windows Preinstallation Environment'
    $winPEOk = Test-Path $winPERoot
}
$scan += [PSCustomObject]@{ Component = 'Windows PE Add-on'; Status = if ($winPEOk) { 'OK' } else { 'MISSING' }; Detail = if ($winPEOk) { 'Installed' } else { 'Not installed - required for OSDCloud template build' } }

# ADK version match - read from ADK binary, registry has no version property
$adkVersionMatch = $false
$adkVersionDetail = 'Could not check'
if ($adkOk) {
    $adkRoot = Get-ADKVersion
    $osVersion = (Get-CimInstance Win32_OperatingSystem).Version
    $osBuild = ($osVersion -split '\.')[2]
    $adkBinary = @(
        (Join-Path $adkRoot 'Assessment and Deployment Kit\Deployment Tools\amd64\Dism\dism.exe'),
        (Join-Path $adkRoot 'Assessment and Deployment Kit\Deployment Tools\x86\Dism\dism.exe')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($adkBinary) {
        $adkFileVersion = (Get-Item $adkBinary).VersionInfo.FileVersion
        $adkBuild = ($adkFileVersion -split '[\.\,]')[2]
        # The Windows 10 ADK (build 19041) is the only ADK for all Win10 versions 2004-22H2.
        $win10AdkBuilds = @('19041', '19042', '19043', '19044', '19045')
        $adkVersionMatch = ($osBuild -eq $adkBuild) -or ($adkBuild -eq '19041' -and $osBuild -in $win10AdkBuilds)
        $adkVersionDetail = if ($adkVersionMatch) { "ADK build $adkBuild is valid for OS build $osBuild (Win10 22H2)" } else { "OS build $osBuild vs ADK build $adkBuild - MISMATCH" }
    } else {
        $adkVersionDetail = "ADK dism.exe not found under $adkRoot - Deployment Tools may not be installed"
    }
}
$scan += [PSCustomObject]@{ Component = 'ADK Version Match'; Status = if ($adkVersionMatch) { 'OK' } else { 'MISSING' }; Detail = $adkVersionDetail }

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
    Write-Status 'Persisting TLS 1.2 to registry...' -Status 'INFO'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # Create registry keys if they don't exist, then set SchUseStrongCrypto
    $tlsRegPath = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
    if (-not (Test-Path $tlsRegPath)) { New-Item -Path $tlsRegPath -Force | Out-Null }
    Set-ItemProperty -Path $tlsRegPath -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -Force
    $tlsRegPath32 = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'
    if (-not (Test-Path $tlsRegPath32)) { New-Item -Path $tlsRegPath32 -Force | Out-Null }
    Set-ItemProperty -Path $tlsRegPath32 -Name 'SchUseStrongCrypto' -Value 1 -Type DWord -Force
    Write-Log 'TLS 1.2 persisted to registry'
    Write-Status 'TLS 1.2 persisted to registry.' -Status 'OK'
} else {
    Write-Status 'TLS 1.2 already persisted.' -Status 'OK'
}

# 4. NuGet provider
if (-not $nugetOk) {
    Write-Status 'Installing NuGet package provider...' -Status 'INFO'
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers -ForceBootstrap | Out-Null
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

# 7. Windows ADK + WinPE Add-on
# Always show both download links together - they are always needed as a pair.
if (-not $adkOk -or -not $winPEOk) {
    Write-Host ''
    Write-Host '  -------------------------------------------------------' -ForegroundColor Yellow
    Write-Host '  Windows ADK and/or Windows PE Add-on requires attention' -ForegroundColor Yellow
    Write-Host '  -------------------------------------------------------' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Required version: Windows ADK for Windows 10, version 2004 (build 19041)' -ForegroundColor White
    Write-Host '  This is the correct ADK for Windows 10 22H2 - there is no separate 22H2 ADK.' -ForegroundColor White
    Write-Host ''
    if (-not $adkOk) {
        Write-Status 'Windows ADK is not installed.' -Status 'WARN'
    }
    if (-not $winPEOk) {
        Write-Status 'Windows PE Add-on is not installed.' -Status 'WARN'
    }
    Write-Host ''
    Write-Host '  Download page (select "Windows 10, version 2004" from the Other ADK downloads section):' -ForegroundColor White
    Write-Host '  https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Step 1 - Run adksetup.exe, select Deployment Tools only' -ForegroundColor White
    Write-Host '  CLI: adksetup.exe /features OptionId.DeploymentTools /passive /norestart' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  Step 2 - Run adkwinpesetup.exe, select Windows Preinstallation Environment' -ForegroundColor White
    Write-Host '  CLI: adkwinpesetup.exe /features OptionId.WindowsPreinstallationEnvironment /passive /norestart' -ForegroundColor Gray
    Write-Host ''
    Write-Status 'Re-run this script after installing both.' -Status 'WARN'
    Write-Log "ADK installed=$adkOk WinPE installed=$winPEOk - prompted user"
}

# 7a. ADK version mismatch
if ($adkOk -and -not $adkVersionMatch) {
    Write-Status 'ADK version does not match the required version.' -Status 'WARN'
    Write-Host ''
    Write-Host '  This causes 0x800f081e errors when building the WinPE template.' -ForegroundColor Yellow
    Write-Host '  Required version: Windows ADK for Windows 10, version 2004 (build 19041)' -ForegroundColor White
    Write-Host ''
    Write-Host '  1. Uninstall the current ADK and WinPE Add-on from Apps & Features' -ForegroundColor White
    Write-Host '  2. Go to the ADK download page and select "Windows 10, version 2004":' -ForegroundColor White
    Write-Host '     https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install' -ForegroundColor Cyan
    Write-Host '     ADK CLI:   adksetup.exe /features OptionId.DeploymentTools /passive /norestart' -ForegroundColor Gray
    Write-Host '     WinPE CLI: adkwinpesetup.exe /features OptionId.WindowsPreinstallationEnvironment /passive /norestart' -ForegroundColor Gray
    Write-Host '  4. Re-run this script after reinstalling both.' -ForegroundColor White
    Write-Host ''
    Write-Log 'ADK version mismatch detected - prompted user'
}


# 8. OSD module
if (-not $osdOk) {
    Write-Status 'Installing OSD module...' -Status 'INFO'
    try {
        # Install to the shared Windows PowerShell path so both PS5.1 and PS7 can find it
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
        # Install to the shared Windows PowerShell path so both PS5.1 and PS7 can find it
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
