#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.SYNOPSIS
    Injects an Autopilot configuration profile during or after Windows deployment.

.DESCRIPTION
    Reads AutopilotConfigurationFile.json from the USB drive and copies it to the
    correct location in the Windows installation so it is processed during OOBE.

    AutopilotConfigurationFile.json is NOT committed to this repo (it is in .gitignore).
    Place the file on the USB manually before deployment.

    The JSON file must be obtained from your Microsoft Intune or Autopilot tenant.

.PARAMETER AutopilotJsonPath
    Path to AutopilotConfigurationFile.json. Defaults to searching USB drives automatically.

.PARAMETER WindowsTargetPath
    Path to the root of the target Windows installation. Defaults to C:\ (post-deployment).

.EXAMPLE
    .\Config\Autopilot\AutopilotConfig.ps1

.EXAMPLE
    .\Config\Autopilot\AutopilotConfig.ps1 -AutopilotJsonPath 'D:\AutopilotConfigurationFile.json'

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: AutopilotConfigurationFile.json on USB (not committed to repo)
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [string]$AutopilotJsonPath,

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
$logFile = Join-Path $logDir "AutopilotConfig_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

Write-Log 'AutopilotConfig.ps1 started'

$autopilotDestination = Join-Path $WindowsTargetPath 'Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json'

# --- Locate the Autopilot JSON file ---
if (-not $AutopilotJsonPath) {
    Write-Status 'AutopilotJsonPath not specified - searching removable drives...' -Status 'INFO'
    $removableDrives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=2" -ErrorAction SilentlyContinue |
                       Select-Object -ExpandProperty DeviceID

    foreach ($drive in $removableDrives) {
        $candidate = Join-Path $drive '\AutopilotConfigurationFile.json'
        if (Test-Path $candidate) {
            $AutopilotJsonPath = $candidate
            Write-Status "Found Autopilot JSON on $drive" -Status 'OK'
            Write-Log "Found Autopilot JSON at: $AutopilotJsonPath"
            break
        }
    }
}

if (-not $AutopilotJsonPath -or -not (Test-Path $AutopilotJsonPath)) {
    Write-Status 'AutopilotConfigurationFile.json not found.' -Status 'ERROR'
    Write-Status 'Place the file on the USB drive root or specify -AutopilotJsonPath.' -Status 'ERROR'
    Write-Log 'ERROR: AutopilotConfigurationFile.json not found'
    exit 1
}

# --- Validate JSON ---
try {
    $json = Get-Content $AutopilotJsonPath -Raw | ConvertFrom-Json
    Write-Log "Autopilot JSON loaded. TenantId: $($json.TenantId)"
    Write-Status "Autopilot JSON validated. Tenant: $($json.TenantId)" -Status 'OK'
} catch {
    Write-Status "Invalid JSON at ${AutopilotJsonPath}: $_" -Status 'ERROR'
    Write-Log "ERROR: Invalid JSON: $_"
    exit 1
}

# --- Copy to target ---
try {
    $destDir = Split-Path $autopilotDestination -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Write-Log "Created directory: $destDir"
    }

    if ($PSCmdlet.ShouldProcess($autopilotDestination, 'Copy Autopilot JSON')) {
        Copy-Item -Path $AutopilotJsonPath -Destination $autopilotDestination -Force
        Write-Log "Autopilot JSON copied to: $autopilotDestination"
        Write-Status "Autopilot profile injected to: $autopilotDestination" -Status 'OK'
    }
} catch {
    Write-Status "Failed to copy Autopilot JSON: $_" -Status 'ERROR'
    Write-Log "ERROR copying Autopilot JSON: $_"
    exit 1
}

Write-Status "Log saved to: $logFile" -Status 'INFO'
Write-Log 'AutopilotConfig.ps1 completed'
