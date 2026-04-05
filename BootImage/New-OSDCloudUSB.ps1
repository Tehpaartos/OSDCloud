#Requires -RunAsAdministrator
#Requires -Version 7.0

<#
.SYNOPSIS
    Creates a bootable OSDCloud USB drive with NTFS and FAT32 partitions.

.DESCRIPTION
    WARNING: This script will erase all data on the selected USB drive.
    A confirmation prompt is shown before any destructive action.

    Creates two partitions:
      - NTFS (large): Stores OSDCloud content
      - FAT32 (2 GB):  Boot partition required for UEFI booting

.PARAMETER WorkspacePath
    Path to the OSDCloud WinRE workspace. Default: C:\OSDCloud\WinRE-WiFi

.EXAMPLE
    .\BootImage\New-OSDCloudUSB.ps1

.NOTES
    Author: OSDCloud Project
    Repo:   https://github.com/Tehpaartos/OSDCloud
    Requires: OSDCloud module, completed WinRE workspace, USB drive (min 8 GB)
    WARNING: Destructive - will erase the selected USB drive
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [string]$WorkspacePath = 'C:\OSDCloud\WinRE-WiFi'
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
$logFile = Join-Path $logDir "New-OSDCloudUSB_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Verbose $entry
}

Write-Log 'New-OSDCloudUSB.ps1 started'

# Validate workspace
if (-not (Test-Path $WorkspacePath)) {
    Write-Status "Workspace not found: $WorkspacePath" -Status 'ERROR'
    Write-Status 'Run BootImage\Build-WinREBootImage.ps1 first.' -Status 'ERROR'
    exit 1
}

# Load module
try {
    Import-Module OSDCloud -Force -ErrorAction Stop
    Write-Status "OSDCloud module loaded: v$((Get-Module OSDCloud).Version)" -Status 'OK'
} catch {
    Write-Status "OSDCloud module not found: $_" -Status 'ERROR'
    exit 1
}

# Enumerate removable drives
$usbDisks = Get-Disk | Where-Object { $_.BusType -eq 'USB' -and $_.Size -ge 8GB }

if (-not $usbDisks) {
    Write-Status 'No USB drives found that are >= 8 GB. Insert a USB drive and try again.' -Status 'ERROR'
    exit 1
}

Write-Host ''
Write-Status 'Available USB drives:' -Status 'INFO'
$usbDisks | Select-Object Number, FriendlyName, Size, @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}} |
    Format-Table Number, FriendlyName, SizeGB -AutoSize

# Prompt for disk selection
$diskNumber = Read-Host 'Enter the disk NUMBER to use for the bootable USB'
if ($diskNumber -notmatch '^\d+$') {
    Write-Status 'Invalid input. Aborting.' -Status 'ERROR'
    exit 1
}

$selectedDisk = $usbDisks | Where-Object { $_.Number -eq [int]$diskNumber }
if (-not $selectedDisk) {
    Write-Status "Disk $diskNumber not found in the USB drive list. Aborting." -Status 'ERROR'
    exit 1
}

$sizeGB = [math]::Round($selectedDisk.Size / 1GB, 1)
Write-Host ''
Write-Status "Selected: Disk $diskNumber - $($selectedDisk.FriendlyName) (${sizeGB} GB)" -Status 'WARN'
Write-Status '!! ALL DATA ON THIS DISK WILL BE ERASED !!' -Status 'WARN'
Write-Host ''
$confirm = Read-Host "Type 'YES' to confirm erasure of Disk $diskNumber"
if ($confirm -ne 'YES') {
    Write-Status 'Confirmation not received. Aborting.' -Status 'WARN'
    exit 0
}

Write-Log "User confirmed erasure of Disk $diskNumber ($($selectedDisk.FriendlyName))"

# Create USB
Write-Status "Creating OSDCloud USB on Disk $diskNumber..." -Status 'INFO'
try {
    if ($PSCmdlet.ShouldProcess("Disk $diskNumber", 'Create OSDCloud USB')) {
        New-OSDCloudUSB -WorkspacePath $WorkspacePath -DiskNumber ([int]$diskNumber) -Verbose
        Write-Status 'OSDCloud USB created successfully.' -Status 'OK'
        Write-Log "OSDCloud USB created on Disk $diskNumber"
    }
} catch {
    Write-Status "Failed to create USB: $_" -Status 'ERROR'
    Write-Log "ERROR creating USB: $_"
    exit 1
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host '  USB Creation Complete' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Status 'The USB is ready. Plug it into the target machine and boot.' -Status 'OK'
Write-Status "Log: $logFile" -Status 'INFO'
Write-Host ''
Write-Status 'REMINDER: The USB is static. Future deployment changes go in' -Status 'WARN'
Write-Status '          Deployment\Deploy-Windows11.ps1 - no USB rebuild needed.' -Status 'WARN'

Write-Log 'New-OSDCloudUSB.ps1 completed'
