# URL-Based Deployment Architecture

---

## How It Works

The USB / ISO only needs to be built **once**. There is no deployment logic baked into it - only a URL.

When WinRE boots, `Startnet.cmd` runs a single command:

```
PowerShell -NoLogo -ExecutionPolicy Bypass -Command "& { Invoke-Expression (Invoke-RestMethod -Uri '<StartURL>') }"
```

The `StartURL` was stamped into the boot image during the build:

```powershell
Edit-OSDCloudWinPE -StartURL 'https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1'
```

**Every time the machine boots from USB, it fetches the latest version of `Deploy-Windows11.ps1` from GitHub.** Pushing a commit to `main` immediately changes what all future deployments do. The USB never changes.

---

## Why `raw.githubusercontent.com`?

PowerShell's `-StartURL` (and `Invoke-RestMethod`) needs to receive a **plain text PS1 file** - not an HTML page.

- `https://github.com/Tehpaartos/OSDCloud/blob/main/Deployment/Deploy-Windows11.ps1` → returns HTML (the GitHub web UI page)
- `https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1` → returns the raw PS1 file as plain text

Always use `raw.githubusercontent.com` in StartURL, not `github.com`.

The repo **must remain public** for unauthenticated raw URL access to work in WinRE. There is no way to pass credentials from the boot environment.

---

## Deployment Flow

```
USB boots
    │
    ▼
WinRE loads
    │
    ▼
Operator connects to WiFi (Start-WinREWiFi)
    │
    ▼
OSDCloud module downloads from PSGallery
    │
    ▼
Startnet.cmd fetches Deploy-Windows11.ps1 from GitHub raw URL
    │
    ▼
Deploy-Windows11.ps1 runs → Start-OSDCloud
    │
    ▼
Windows 11 downloads from Microsoft Update and installs
    │
    ▼
Machine reboots into Windows
```

---

## Switching Deployment Modes

Three deployment modes are available without rebuilding the USB:

| Mode | What to do |
|------|-----------|
| **Standard** (interactive) | `Deploy-Windows11.ps1` - prompts for disk wipe confirmation |
| **ZTI** (silent) | Call `Deploy-Windows11.ps1` with `-ZTI` in Startnet.cmd - no prompts |
| **GUI** (operator selects OS) | Re-stamp USB with `Start-OSDCloudGUI.ps1` URL (requires one USB rebuild) |

### Enabling ZTI without rebuilding the USB

Edit `Deploy-Windows11.ps1` to default to ZTI behavior, then push to `main`. Or modify `Startnet.cmd` in the workspace and regenerate the ISO.

### Switching to the GUI variant

Re-stamp the workspace and regenerate the ISO:

```powershell
$GUIURL = 'https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Start-OSDCloudGUI.ps1'
Edit-OSDCloudWinPE -StartURL $GUIURL -WorkspacePath 'C:\OSDCloud\WinRE-WiFi'
# Then: .\BootImage\New-OSDCloudISO.ps1
```

---

## Key Warning

> `main` is **live**. Merging a change to `Deploy-Windows11.ps1` immediately affects all future deployments.

Always test changes on a feature branch. Temporarily re-stamp a test USB with your branch's raw URL to validate before merging to `main`.

```
https://raw.githubusercontent.com/Tehpaartos/OSDCloud/<branch>/Deployment/Deploy-Windows11.ps1
```
