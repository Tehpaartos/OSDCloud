# Changelog

All notable changes to this project will be documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MINOR** - new Windows release target, driver updates, significant script changes
- **PATCH** - config-only changes, documentation updates, minor fixes

---

## [Unreleased]

---

## [1.0.0] - 2026-04-05

### Added
- Initial repository scaffolding and project structure
- `Deployment/Deploy-Windows11.ps1` - cloud deployment script (Windows 11 24H2, en-AU)
- `Deployment/Start-OSDCloudGUI.ps1` - optional interactive GUI variant
- `Setup/Install-Prerequisites.ps1` - full prereq installer with two-phase scan/install
- `Setup/Verify-Environment.ps1` - post-install health check
- `BootImage/Build-WinREBootImage.ps1` - WinRE boot image builder with WiFi support
- `BootImage/Edit-WinREDrivers.ps1` - supplemental driver injection
- `BootImage/Apply-WinOSDrivers.ps1` - OOB driver application to deployed Windows OS
- `BootImage/New-OSDCloudISO.ps1` - bootable ISO generator
- `BootImage/New-OSDCloudUSB.ps1` - bootable USB creator
- `Config/OSDCloud.json` - GUI deployment defaults
- `Config/Unattend/unattend.xml` - Windows unattended answer file template
- `Config/Autopilot/AutopilotConfig.ps1` - Autopilot profile injection stub
- `Maintenance/Update-OSDModules.ps1` - OSD module updater
- `Maintenance/Refresh-BootImage.ps1` - full boot image rebuild
- `Maintenance/Test-OSDEnvironment.ps1` - environment health check
- Full documentation under `docs/`

---

## ISO Release History

| Version | Date       | Notes                                  |
|---------|------------|----------------------------------------|
| 1.0.0   | 2026-04-05 | Initial release - Windows 11 24H2 Pro en-AU |

---

[Unreleased]: https://github.com/Tehpaartos/OSDCloud/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Tehpaartos/OSDCloud/releases/tag/v1.0.0
