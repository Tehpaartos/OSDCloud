# Config

Configuration files used by the OSDCloud deployment environment.

## Files

| File | Purpose |
|------|---------|
| `OSDCloud.json` | GUI default selections for interactive deployments via `Start-OSDCloudGUI.ps1` |
| `Unattend/unattend.xml` | Windows unattended answer file template (regional settings, OOBE suppression) |
| `Autopilot/AutopilotConfig.ps1` | Script to inject an Autopilot profile during deployment |

## Important Notes

### OSDCloud.json vs Deploy-Windows11.ps1

`OSDCloud.json` controls what the **GUI pre-selects** when running `Start-OSDCloudGUI.ps1` interactively. It does **not** affect `Deploy-Windows11.ps1`.

Deployment settings (OS version, edition, language) live directly in `Deploy-Windows11.ps1` as clearly commented variables. That script is the single source of truth for automated deployments.

### Autopilot Config

`AutopilotConfigurationFile.json` is **not committed to this repo** (it is in `.gitignore`). Place the file on the USB manually before deployment if Autopilot enrollment is required.

### Unattend Passwords

Never commit `unattend.xml` files containing plaintext or base64-encoded passwords. The template in this repo uses placeholder comments only.
