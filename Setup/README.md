# Setup

Scripts for the **repo owner** to prepare the build machine before creating the WinRE boot image.

> These scripts are not used by community users. Community users only need the README at the repo root.

## Scripts

| Script | Purpose |
|--------|---------|
| `Install-Prerequisites.ps1` | Installs all required tools and modules (Windows ADK, PowerShell 7, OSD, OSDCloud) |
| `Verify-Environment.ps1` | Post-install health check - run after Install-Prerequisites or at any time |

## Usage

Run on a **Windows 10 22H2** build machine as Administrator in PowerShell 7:

```powershell
# Step 1 - Install everything needed
.\Setup\Install-Prerequisites.ps1

# Step 2 - Verify the environment is ready
.\Setup\Verify-Environment.ps1
```

See [docs/prerequisites.md](../docs/prerequisites.md) for the full list of requirements.

> **Build machine must run Windows 10 22H2.** Windows 11 WinRE is not compatible with older hardware.
> If your build machine runs Windows 11, use a Hyper-V VM with Windows 10 22H2 for the build step.
