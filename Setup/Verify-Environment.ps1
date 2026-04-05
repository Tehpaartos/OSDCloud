#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies that all prerequisites for building the OSDCloud WinRE boot image are installed and configured correctly.

.DESCRIPTION
    Runs a pass/fail check for every required component. Safe to run at any time - makes no changes.
    Use this after running Install-Prerequisites.ps1 or before starting any build.

.EXAMPLE
    .\Setup\Verify-Environment.ps1

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
#>

[CmdletBinding()]
param ()

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('PASS','FAIL','WARN','INFO')]
        [string]$Status = 'INFO'
    )
    $color = switch ($Status) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'WARN' { 'Yellow' }
        'INFO' { 'Cyan' }
        default { 'White' }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OSDCloud Environment Verification' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

$results = @()
$anyFail = $false

# Helper
function Add-Result {
    param([string]$Check, [bool]$Pass, [string]$Detail)
    $script:results += [PSCustomObject]@{
        Check  = $Check
        Result = if ($Pass) { 'PASS' } else { 'FAIL' }
        Detail = $Detail
    }
    if (-not $Pass) { $script:anyFail = $true }
}

# 1. Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Add-Result 'Running as Administrator' $isAdmin (if ($isAdmin) { 'Yes' } else { 'Re-run as Administrator' })

# 2. PowerShell version
$psVersion = $PSVersionTable.PSVersion
$ps5ok = $psVersion.Major -ge 5
Add-Result 'PowerShell 5.1+' $ps5ok $psVersion.ToString()

# 3. PowerShell 7 in PATH
$ps7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
Add-Result 'PowerShell 7 (pwsh.exe)' ($null -ne $ps7) (if ($ps7) { $ps7.Source } else { 'Not found in PATH' })

# 4. TLS 1.2
$tlsOk = ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) -ne 0
Add-Result 'TLS 1.2 Available' $tlsOk (if ($tlsOk) { 'Enabled' } else { 'Not available' })

# 5. NuGet provider
$nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
Add-Result 'NuGet Package Provider' ($null -ne $nuget) (if ($nuget) { $nuget.Version.ToString() } else { 'Not installed' })

# 6. PSGallery trusted
$gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
$galleryTrusted = $gallery -and $gallery.InstallationPolicy -eq 'Trusted'
Add-Result 'PSGallery Trusted' $galleryTrusted (if ($galleryTrusted) { 'Trusted' } else { 'Not trusted' })

# 7. Windows ADK
$adkPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
$adkOk = Test-Path $adkPath
if ($adkOk) {
    $adkRoot = (Get-ItemProperty $adkPath -ErrorAction SilentlyContinue).KitsRoot10
    $adkOk = $null -ne $adkRoot -and (Test-Path $adkRoot)
    $adkDetail = if ($adkOk) { $adkRoot } else { 'Installed but root path missing' }
} else {
    $adkDetail = 'Not installed - see docs/prerequisites.md'
}
Add-Result 'Windows ADK' $adkOk $adkDetail

# 8. Windows PE Add-on (optional but recommended)
$wpeAddon = Test-Path 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment'
Add-Result 'Windows PE Add-on' $wpeAddon (if ($wpeAddon) { 'Found' } else { 'Not found (optional for WinRE builds)' })

# 9. OSD module
$osd = Get-Module -ListAvailable OSD -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
Add-Result 'OSD Module' ($null -ne $osd) (if ($osd) { "v$($osd.Version)" } else { 'Not installed - run Install-Prerequisites.ps1' })

# 10. OSDCloud module
$osdCloud = Get-Module -ListAvailable OSDCloud -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
Add-Result 'OSDCloud Module' ($null -ne $osdCloud) (if ($osdCloud) { "v$($osdCloud.Version)" } else { 'Not installed - run Install-Prerequisites.ps1' })

# 11. Internet connectivity
Write-Verbose 'Testing internet connectivity...'
try {
    $netTest = Test-NetConnection -ComputerName 'www.microsoft.com' -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Add-Result 'Internet Connectivity' $netTest (if ($netTest) { 'Connected to microsoft.com' } else { 'No connection - required for module downloads' })
} catch {
    Add-Result 'Internet Connectivity' $false "Error: $_"
}

# 12. VERSION file
$versionFile = Join-Path $PSScriptRoot '..\VERSION'
$versionOk = Test-Path $versionFile
$versionContent = if ($versionOk) { (Get-Content $versionFile -Raw).Trim() } else { 'File not found' }
Add-Result 'VERSION File' $versionOk $versionContent

# ---------------------------------------------------------------------------
# Print results
# ---------------------------------------------------------------------------
Write-Host ''
$results | Format-Table -Property Check, Result, Detail -AutoSize

if ($anyFail) {
    Write-Status 'One or more checks failed. Run Setup\Install-Prerequisites.ps1 to resolve.' -Status 'WARN'
    exit 1
} else {
    Write-Status 'All checks passed. Environment is ready.' -Status 'PASS'
    exit 0
}
