# WiFi Support in WinRE

---

## Why WinRE and Not Standard WinPE?

Standard Windows PE (WinPE) does not include the wireless networking stack. It has no built-in support for WiFi - only wired Ethernet.

**Windows Recovery Environment (WinRE)** is the recovery partition environment that ships with every Windows installation. It does include the wireless networking stack, making WiFi connectivity possible in the boot environment.

This is why `Build-WinREBootImage.ps1` uses `-WinRE` when creating the template:

```powershell
New-OSDCloudTemplate -WinRE -Name "WinRE-WiFi"
```

Without `-WinRE`, the boot image would support Ethernet only - no WiFi, no deployment on machines without a wired connection.

---

## Build Machine OS Requirement

The WinRE source files come from the **build machine's own Windows Recovery Environment**. This means:

- A **Windows 10** build machine produces a **Windows 10 WinRE** boot image
- A **Windows 11** build machine produces a **Windows 11 WinRE** boot image

Windows 11 WinRE requires a CPU with TPM 2.0 and Secure Boot support. Older hardware that can run Windows 10 may not be able to boot a Windows 11 WinRE.

**Always build on Windows 10** to ensure the boot image is compatible with the widest range of hardware.

---

## Intel WiFi Driver Injection

Even with WinRE's wireless stack, the boot image needs WiFi adapter drivers to connect to a network. Most modern Intel WiFi adapters are not included by default.

The `-CloudDriver WiFi` parameter in `Edit-OSDCloudWinPE` injects the Intel WiFi driver pack directly into the WinRE image:

```powershell
Edit-OSDCloudWinPE -WorkspacePath $WorkspacePath `
                   -StartURL $DeployURL `
                   -CloudDriver WiFi
```

This covers the vast majority of Intel WiFi adapters found in modern laptops and desktops.

For hardware using non-Intel WiFi adapters (e.g. some Realtek, MediaTek), use `BootImage/Edit-WinREDrivers.ps1` to inject additional drivers.

---

## How the OSDCloud Module Gets Into WinRE

When WinRE boots and runs `Startnet.cmd`, the OSDCloud module is not pre-installed in the boot image. Instead, OSDCloud bootstraps itself:

1. WinRE boots
2. Operator connects to WiFi (prompted by `Start-WinREWiFi`)
3. `Startnet.cmd` runs `Initialize-OSDCloudStartnet`, which downloads the OSDCloud module from PowerShell Gallery over the internet
4. The deployment script (`Deploy-Windows11.ps1`) is fetched from GitHub and executed

**WiFi must be connected before the deployment script runs.** If the module download fails (no connectivity), the deployment will not start. This is expected - the deployment is entirely cloud-based and requires internet access throughout.

---

## Troubleshooting WiFi Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| WiFi prompt does not appear | Module not loaded - usually means no internet | Check driver injection during build |
| Can connect to network but can't download | DNS or proxy issue in WinRE | Try a different network |
| Module download fails | PSGallery unreachable | Check connectivity from WinRE shell |
| Known adapter not detected | Driver not in CloudDriver set | Use `Edit-WinREDrivers.ps1` with `-DriverPath` |

See also: [troubleshooting.md](troubleshooting.md)
