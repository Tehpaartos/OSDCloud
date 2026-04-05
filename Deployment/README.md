# Deployment

Scripts that run **inside WinRE at boot time**. These are fetched live from GitHub - editing and pushing to `main` immediately changes all future deployments.

> **Warning:** `main` is live. Test changes on a branch before merging.

## Scripts

| Script | Raw URL (baked into USB) |
|--------|--------------------------|
| `Deploy-Windows11.ps1` | `https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1` |
| `Start-OSDCloudGUI.ps1` | `https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Start-OSDCloudGUI.ps1` |

## Switching Modes (No USB Rebuild Required)

The USB is stamped with a single StartURL. To switch between standard, ZTI, and GUI modes without rebuilding the USB, you can modify `Deploy-Windows11.ps1` in place.

To re-stamp the USB with a different URL (e.g. to switch to the GUI variant):

```powershell
Edit-OSDCloudWinPE -StartURL 'https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Start-OSDCloudGUI.ps1' `
                   -WorkspacePath "C:\OSDCloud\WinRE-WiFi"
```

Then regenerate the ISO and USB.

## ZTI (Zero Touch) Mode

Pass `-ZTI` to `Deploy-Windows11.ps1` to skip the disk-wipe confirmation prompt:

```
Deploy-Windows11.ps1 -ZTI
```

This is useful for fully automated deployments where no operator interaction is expected.

See [docs/url-deployment.md](../docs/url-deployment.md) for architecture details.
