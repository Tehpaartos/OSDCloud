# OSDCloud Windows Deployment

A community-maintained Windows 11 deployment toolkit powered by OSDCloud V2.
Plug in a USB, boot the machine, and Windows 11 installs automatically over WiFi.

---

## What You Need

- A USB drive (minimum 8 GB) - contents will be erased
- [Rufus](https://rufus.ie/downloads/) (free, no install needed)
- WiFi credentials for the network at the deployment site

---

## Step 1 - Download Rufus

Download the portable version (no install required) from:
**https://rufus.ie/downloads/**

Look for **rufus-x.xx.exe** (portable) - just double-click to run it.

---

## Step 2 - Download the Boot Image

**[Download OSDCloud.iso](https://download.osdcloud.tehpaartos.com/osdcloud/OSDCloud.iso)**

> File size is approximately 500–700 MB. Allow a few minutes on a standard connection.

---

## Step 3 - Create the Bootable USB with Rufus

1. Open Rufus
2. Under **Device**, select your USB drive
3. Under **Boot selection**, click **SELECT** and choose the downloaded ISO file
4. Leave all other settings as default
5. Click **START**
6. When warned that data will be destroyed, click **OK**
7. Wait for **READY** status - takes 2–5 minutes
8. Close Rufus. The USB is ready.

> If Rufus shows an "ISOHybrid" prompt, select **Write in ISO Image mode** (not DD mode).

---

## Step 4 - Boot the Machine from USB

1. Plug the USB into the target machine
2. Power on and enter BIOS/UEFI (usually **F2**, **F12**, **DEL**, or **ESC** at startup)
3. Set USB as the first boot device, or select it from the one-time boot menu
4. Save and exit - the machine will boot from the USB

> If the machine does not boot from USB, check that **Secure Boot** is disabled in BIOS/UEFI settings.

---

## Step 5 - The Deployment

1. When prompted, enter the **WiFi network name (SSID)** and **password**
2. The deployment will start automatically - do not interrupt it
3. Windows 11 will download and install - this takes **20–45 minutes** depending on connection speed
4. The machine will reboot automatically when complete

---

## Issues or Contributions

Open an issue or pull request on GitHub:
**https://github.com/Tehpaartos/OSDCloud**
