# Troubleshooting

Common issues and fixes for the OSDCloud deployment environment.

---

## Boot Issues

### USB does not boot

**Symptom:** Machine powers on but ignores the USB or shows an error.

**Fixes:**
- Disable **Secure Boot** in BIOS/UEFI settings
- Check that USB is set as first boot device or use the one-time boot menu (F12, F11, etc.)
- If Rufus warned about ISOHybrid during creation, ensure you selected **Write in ISO Image mode** (not DD mode)
- Try a different USB port (USB 3.0 ports occasionally have compatibility issues in WinPE - try a USB 2.0 port)

---

### WinRE won't boot on older hardware

**Symptom:** USB boots but shows a compatibility error, hangs on logo, or immediately reboots.

**Cause:** Boot image was built on a Windows 11 machine. Windows 11 WinRE requires TPM 2.0 and Secure Boot, which older hardware may not support.

**Fix:** Rebuild the image on a **Windows 10** build machine (physical or Hyper-V VM with Windows 10 22H2).

See [prerequisites.md](prerequisites.md) and [wifi-setup.md](wifi-setup.md).

---

## WiFi Issues

### WiFi prompt does not appear / machine has no network

**Cause:** Intel WiFi driver was not injected during the build.

**Fix:** Verify `Build-WinREBootImage.ps1` used `-CloudDriver WiFi`. If not, rebuild.

For non-Intel adapters: use `BootImage/Edit-WinREDrivers.ps1` with `-DriverPath` pointing to your adapter's driver folder.

---

### WiFi connects but OSDCloud module fails to download

**Symptom:** Network connects but the deployment stalls with a module error.

**Causes and fixes:**
- PSGallery is temporarily unavailable - wait and retry
- Network has a web proxy or firewall blocking PowerShell Gallery (`powershellgallery.com`, `oneget.org`)
- DNS not resolving - check with `nslookup powershellgallery.com` in the WinRE shell

---

## Script Execution Issues

### `-StartURL` script is not executing

**Symptom:** WinRE boots but nothing happens after WiFi connects, or you see a download error.

**Cause:** The StartURL was set using `github.com` instead of `raw.githubusercontent.com`.

**Fix:** The StartURL must point to the raw file:
```
https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1
```
Not:
```
https://github.com/Tehpaartos/OSDCloud/blob/main/Deployment/Deploy-Windows11.ps1
```

Rebuild the boot image with the correct URL.

---

### `#Requires -RunAsAdministrator` error in WinRE

**Symptom:** Deploy-Windows11.ps1 throws an error about administrator privileges.

**Cause:** `Deploy-Windows11.ps1` should not have `#Requires -RunAsAdministrator` - WinRE runs as SYSTEM, and this directive causes errors.

**Fix:** Remove the `#Requires` line from `Deploy-Windows11.ps1`. See the note in the script header.

---

## ISO Download Issues

### `download.osdcloud.tehpaartos.com` does not resolve

**Symptom:** Browser or download tool cannot reach the ISO URL.

**Fix:**
1. Check DNS propagation: `nslookup download.osdcloud.tehpaartos.com`
2. If not resolved, the CNAME record may not have propagated yet - wait up to 24 hours
3. Verify the CNAME record at your registrar points to the correct Azure Blob hostname

---

### Azure blob returns 404 or authentication error

**Symptoms:** URL resolves but returns a 404 or access denied error.

**Fixes:**
- Verify the blob container access is set to **Blob (anonymous read)** - not private
- Verify the blob path: `https://youraccount.blob.core.windows.net/osdcloud/OSDCloud.iso`
  - Container name must be `osdcloud`
  - Blob name must be `OSDCloud.iso` (case-sensitive)
- Confirm the ISO was uploaded successfully in the Azure Portal

---

## Deployment Issues

### Windows 11 fails to download

**Symptom:** OSDCloud starts but fails downloading the OS image from Microsoft.

**Fixes:**
- Check internet speed and stability - a dropped connection mid-download causes failure
- Resync time: `w32tm /resync /force` (WinRE clock drift can cause TLS errors)
- Retry - Microsoft Update servers occasionally throttle requests

---

### Driver issues after Windows installs

**Symptom:** Windows installs successfully but has missing drivers (WiFi, display, etc.).

**Fix:** Run `BootImage/Apply-WinOSDrivers.ps1` post-deployment to apply OOB drivers, or check that the correct driver pack is being pulled during deployment.

---

## ADK Issues

### ADK version mismatch

**Symptom:** `New-OSDCloudTemplate` errors with a WinRE version mismatch.

**Fix:** Ensure the ADK version matches the Windows 10 source WinRE. Supported versions:
- ADK 10.1.26100.2454
- ADK 10.1.28000.1

Run `Setup/Verify-Environment.ps1` to check the installed ADK version.
