# Start-OSDCloudGUI.ps1
# Optional interactive variant - lets the operator choose OS version and edition at boot time.
#
# Fetched from: https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Start-OSDCloudGUI.ps1
#
# To re-stamp the USB with this URL (requires re-running Edit-OSDCloudWinPE):
#
#   $GUIURL = "https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Start-OSDCloudGUI.ps1"
#   Edit-OSDCloudWinPE -StartURL $GUIURL -WorkspacePath "C:\OSDCloud\WinRE-WiFi"
#
# NOTE: No #Requires directives - this script runs in WinRE under PowerShell 5.1 as SYSTEM.

Write-Host '[OSDCloud GUI] Loading OSDCloud module...' -ForegroundColor Cyan
try {
    Import-Module OSDCloud -Force -ErrorAction Stop
} catch {
    Write-Host '[OSDCloud GUI] ERROR: Could not load OSDCloud module. Ensure WiFi is connected.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host '[OSDCloud GUI] Starting interactive GUI...' -ForegroundColor Green
Start-OSDCloudGUI
