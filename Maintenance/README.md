# Maintenance

Scripts for keeping the build environment and boot image up to date.

## Scripts

| Script | Purpose |
|--------|---------|
| `Update-OSDModules.ps1` | Updates OSD and OSDCloud PowerShell modules to latest versions |
| `Refresh-BootImage.ps1` | Full rebuild of the WinRE boot image after module or ADK updates |
| `Test-OSDEnvironment.ps1` | Comprehensive health check - run at any time to verify the environment |

## When to Run These

**After any module update (OSD, OSDCloud):**
```powershell
.\Maintenance\Update-OSDModules.ps1
.\Maintenance\Refresh-BootImage.ps1
```

**Routine health check:**
```powershell
.\Maintenance\Test-OSDEnvironment.ps1
```

**After Windows ADK update:**
```powershell
.\Maintenance\Refresh-BootImage.ps1
```

## After Rebuilding the Boot Image

1. Run `BootImage/New-OSDCloudISO.ps1` to regenerate the ISO
2. Upload the new ISO to Azure Files
3. Update `VERSION` file with the new version number
4. Add an entry to `CHANGELOG.md`
5. Push to `main`

See [docs/iso-hosting.md](../docs/iso-hosting.md) for upload instructions.
