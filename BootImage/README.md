# BootImage

Scripts for building the WinRE boot image, generating the ISO, and creating bootable USB drives.

> Run these scripts on a **Windows 10** build machine. Windows 11 WinRE is not compatible with older hardware.
> If your build machine runs Windows 11, use a Hyper-V VM with Windows 10 22H2.

## Scripts

| Script | Purpose |
|--------|---------|
| `Build-WinREBootImage.ps1` | Builds the WinRE boot image and stamps the deployment URL into Startnet.cmd |
| `Edit-WinREDrivers.ps1` | Injects supplemental drivers into an existing WinRE workspace |
| `Apply-WinOSDrivers.ps1` | Applies OOB drivers to the deployed Windows OS after installation |
| `New-OSDCloudISO.ps1` | Generates a bootable ISO from the active workspace |
| `New-OSDCloudUSB.ps1` | Creates a bootable USB drive (NTFS + FAT32 partitions) |

## Build Order

1. `Setup/Install-Prerequisites.ps1` - once, on a fresh build machine
2. `Build-WinREBootImage.ps1` - builds the workspace and stamps the URL
3. `Edit-WinREDrivers.ps1` - optional, for supplemental driver injection
4. `New-OSDCloudISO.ps1` - generates the ISO for upload to Azure Files
5. `New-OSDCloudUSB.ps1` - optional, creates USB directly instead of ISO

## Key Fact

The USB / ISO only needs to be built **once**. The boot image fetches the deployment script live from GitHub at boot time. To change what gets deployed, edit `Deployment/Deploy-Windows11.ps1` and push - no rebuild needed.

See [docs/url-deployment.md](../docs/url-deployment.md) for how this works.
