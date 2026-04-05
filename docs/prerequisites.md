# Prerequisites

Requirements for the **repo owner** to build the WinRE boot image and ISO.

> Community users only need the [README](../README.md) - this document is for the person maintaining the repo.

---

## Build Machine OS

> **This is the most common setup mistake.**

The WinRE boot image **must be built on a Windows 10 22H2 machine**.

Windows 11 WinRE is not compatible with older hardware. If you build the image on Windows 11, it will not boot on machines with older firmware or CPUs.

**If your build machine runs Windows 11:** Use a Hyper-V VM with Windows 10 22H2 for the build step. Run `BootImage/Build-WinREBootImage.ps1` inside the VM, then copy the resulting workspace out to generate the ISO.

---

## Required Tools

### 1. PowerShell 7

- Download: https://github.com/PowerShell/PowerShell/releases/latest
- Look for `PowerShell-7.x.x-win-x64.msi`
- Install, then verify: `pwsh.exe --version`

### 2. Windows ADK for Windows 10, version 2004 - Deployment Tools only

> This is the correct ADK for Windows 10 22H2. Microsoft does not publish a separate ADK for each Windows 10 release after 2004 — the version 2004 ADK supports all Windows 10 versions from 2004 through 22H2.

- Go to the ADK download page and select **Windows 10, version 2004** from the "Other ADK downloads" section:
  `https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install`
- Download both **adksetup.exe** and **adkwinpesetup.exe** from that entry
- Run **adksetup.exe** and select **Deployment Tools** only
- Run **adkwinpesetup.exe** and select **Windows Preinstallation Environment**

### 3. OSD PowerShell Module

```powershell
Install-Module OSD -Force -Scope AllUsers
```

### 4. OSDCloud PowerShell Module

```powershell
Install-Module OSDCloud -Force -Scope AllUsers
```

---

## Automated Install

Run `Setup/Install-Prerequisites.ps1` as Administrator in PowerShell 7 - it will scan for missing components and install them in the correct order.

```powershell
# In PowerShell 7, as Administrator
.\Setup\Install-Prerequisites.ps1
```

After it completes, run the verification check:

```powershell
.\Setup\Verify-Environment.ps1
```

---

## Quick Reference

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| Build machine OS | Windows 10 22H2 | Not Windows 11 - see above |
| PowerShell | 7.4.x or later | Also needs PS 5.1 for some cmdlets |
| Windows ADK | version 2004 (build 19041.x) | Deployment Tools + WinPE add-on. Valid for all Win10 2004–22H2 builds. |
| OSD module | Latest from PSGallery | `Install-Module OSD` |
| OSDCloud module | Latest from PSGallery | `Install-Module OSDCloud` |
