#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive health check for the OSDCloud build and deployment environment.

.DESCRIPTION
    Tests every component of the OSDCloud environment and outputs a pass/fail table.
    Safe to run at any time - makes no changes to the system.

    Checks:
      - Module versions (OSD, OSDCloud)
      - Windows ADK install path and version
      - PowerShell 7 in PATH
      - OSDCloud workspace paths
      - Internet connectivity to Microsoft Update Catalog
      - Current VERSION file contents
      - Build machine OS (Windows 10 recommended)

.EXAMPLE
    .\Maintenance\Test-OSDEnvironment.ps1

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$WorkspacePath = 'C:\OSDCloud\WinRE-WiFi'
)

function Write-Status {
    param([string]$Message, [string]$Status = 'INFO')
    $color = switch ($Status) {
        'PASS'  { 'Green' }
        'FAIL'  { 'Red' }
        'WARN'  { 'Yellow' }
        'INFO'  { 'Cyan' }
        default { 'White' }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OSDCloud Environment Health Check' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

$results = @()
$failCount = 0
$warnCount = 0

function Add-Check {
    param([string]$Name, [string]$Result, [string]$Detail)
    $script:results += [PSCustomObject]@{ Check = $Name; Result = $Result; Detail = $Detail }
    if ($Result -eq 'FAIL') { $script:failCount++ }
    if ($Result -eq 'WARN') { $script:warnCount++ }
}

# 1. Build machine OS
$osCaption = (Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
$osOk = $osCaption -notmatch 'Windows 11'
Add-Check 'Build Machine OS' (if ($osOk) { 'PASS' } else { 'WARN' }) "$osCaption$(if (-not $osOk) { ' - Windows 10 recommended for WinRE compatibility' })"

# 2. Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Add-Check 'Running as Administrator' (if ($isAdmin) { 'PASS' } else { 'FAIL' }) (if ($isAdmin) { 'Yes' } else { 'Re-run as Administrator' })

# 3. PowerShell version
$psVersion = $PSVersionTable.PSVersion
Add-Check 'PowerShell Version' 'PASS' $psVersion.ToString()

# 4. PowerShell 7 in PATH
$ps7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
Add-Check 'PowerShell 7 (pwsh.exe)' (if ($ps7) { 'PASS' } else { 'WARN' }) (if ($ps7) { $ps7.Source } else { 'Not found - install from https://github.com/PowerShell/PowerShell' })

# 5. Windows ADK
$adkPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
$adkOk = $false
$adkDetail = 'Not installed'
if (Test-Path $adkPath) {
    $adkRoot = (Get-ItemProperty $adkPath -ErrorAction SilentlyContinue).KitsRoot10
    if ($adkRoot -and (Test-Path $adkRoot)) {
        $adkOk = $true
        $adkDetail = $adkRoot
        # Check for Deployment Tools
        $deployTools = Join-Path $adkRoot 'Assessment and Deployment Kit\Deployment Tools'
        if (-not (Test-Path $deployTools)) {
            $adkOk = $false
            $adkDetail = "Root found but Deployment Tools missing: $deployTools"
        }
    }
}
Add-Check 'Windows ADK (Deployment Tools)' (if ($adkOk) { 'PASS' } else { 'FAIL' }) $adkDetail

# 6. OSD module
$osd = Get-Module -ListAvailable OSD -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
Add-Check 'OSD Module' (if ($osd) { 'PASS' } else { 'FAIL' }) (if ($osd) { "v$($osd.Version)" } else { 'Not installed - run Setup\Install-Prerequisites.ps1' })

# 7. OSDCloud module
$osdCloud = Get-Module -ListAvailable OSDCloud -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
Add-Check 'OSDCloud Module' (if ($osdCloud) { 'PASS' } else { 'FAIL' }) (if ($osdCloud) { "v$($osdCloud.Version)" } else { 'Not installed - run Setup\Install-Prerequisites.ps1' })

# 8. OSDCloud workspace
$workspaceOk = Test-Path $WorkspacePath
Add-Check 'WinRE Workspace' (if ($workspaceOk) { 'PASS' } else { 'WARN' }) (if ($workspaceOk) { $WorkspacePath } else { "Not found at $WorkspacePath - run BootImage\Build-WinREBootImage.ps1" })

# 9. Workspace Startnet.cmd (URL check)
$startnet = Join-Path $WorkspacePath 'Media\Boot\x64\Startnet.cmd'
if (Test-Path $startnet) {
    $startnetContent = Get-Content $startnet -Raw -ErrorAction SilentlyContinue
    $expectedUrl = 'https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1'
    $urlOk = $startnetContent -match [regex]::Escape($expectedUrl)
    Add-Check 'Startnet.cmd Deploy URL' (if ($urlOk) { 'PASS' } else { 'WARN' }) (if ($urlOk) { 'URL found in Startnet.cmd' } else { "Expected URL not found - re-run Build-WinREBootImage.ps1" })
} else {
    Add-Check 'Startnet.cmd Deploy URL' 'WARN' 'Startnet.cmd not found - workspace may not be built yet'
}

# 10. Internet - Microsoft Update Catalog
Write-Verbose 'Testing internet connectivity...'
try {
    $msTest = Test-NetConnection -ComputerName 'www.microsoft.com' -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Add-Check 'Internet (microsoft.com)' (if ($msTest) { 'PASS' } else { 'FAIL' }) (if ($msTest) { 'Connected' } else { 'No connection' })
} catch {
    Add-Check 'Internet (microsoft.com)' 'FAIL' "Error: $_"
}

# 11. ISO output directory
$isoDir = 'C:\OSDCloud\ISO'
$isoOk = Test-Path $isoDir
$isoFiles = if ($isoOk) { Get-ChildItem $isoDir -Filter '*.iso' -ErrorAction SilentlyContinue } else { @() }
$isoDetail = if ($isoOk -and $isoFiles.Count -gt 0) {
    "$($isoFiles.Count) ISO(s) found - latest: $($isoFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty Name)"
} elseif ($isoOk) {
    'Directory exists but no ISOs found - run BootImage\New-OSDCloudISO.ps1'
} else {
    'Not found - ISOs will be created here by New-OSDCloudISO.ps1'
}
Add-Check 'ISO Output Directory' (if ($isoOk -and $isoFiles.Count -gt 0) { 'PASS' } else { 'WARN' }) $isoDetail

# 12. VERSION file
$versionFile = Join-Path $PSScriptRoot '..\VERSION'
$versionOk = Test-Path $versionFile
$versionContent = if ($versionOk) { (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim() } else { 'File not found' }
Add-Check 'VERSION File' (if ($versionOk) { 'PASS' } else { 'WARN' }) $versionContent

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
Write-Host ''
$colWidths = @{ Check = 35; Result = 6; Detail = 60 }
$results | Format-Table -Property Check, Result, Detail -AutoSize

Write-Host "  Checks: $($results.Count)   " -NoNewline
Write-Host "PASS: $($results | Where-Object Result -eq 'PASS' | Measure-Object | Select-Object -ExpandProperty Count)   " -ForegroundColor Green -NoNewline
Write-Host "WARN: $warnCount   " -ForegroundColor Yellow -NoNewline
Write-Host "FAIL: $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host ''

if ($failCount -gt 0) {
    Write-Status "Environment has $failCount failing check(s). Review the table above." -Status 'FAIL'
    exit 1
} elseif ($warnCount -gt 0) {
    Write-Status "Environment is functional with $warnCount warning(s). See details above." -Status 'WARN'
    exit 0
} else {
    Write-Status 'All checks passed. Environment is healthy.' -Status 'PASS'
    exit 0
}
