# ISO Hosting - Azure Files + DNS CNAME

---

## Architecture

The ISO is hosted on **Azure Blob Storage**. A DNS CNAME record creates a stable vanity URL that never changes, regardless of where the ISO physically lives.

```
https://download.osdcloud.tehpaartos.com/osdcloud/OSDCloud.iso
         │                               │          │
         │                               │          └── Blob filename (stable)
         │                               └── Container name (stable)
         └── DNS CNAME → youraccount.blob.core.windows.net
```

If you ever move to a different storage provider, update only the DNS CNAME. The README link - and anyone who has bookmarked it - never needs to change.

---

## Initial Setup (one time)

### 1. Create Azure Storage Account

1. In the Azure Portal, create a **Storage Account** (any region, LRS redundancy is fine)
2. Note the storage account name - this becomes part of the blob hostname: `youraccount.blob.core.windows.net`

### 2. Create a Blob Container

1. In the storage account, go to **Containers** → **+ Container**
2. Name: `osdcloud`
3. Public access level: **Blob (anonymous read access for blobs only)**

> This allows unauthenticated download of the ISO without exposing the storage account management.

### 3. Build the ISO

```powershell
.\BootImage\Build-WinREBootImage.ps1
.\BootImage\New-OSDCloudISO.ps1
```

The ISO will be named `OSDCloud-v1.0.0.iso` (using the current VERSION file).

### 4. Upload the ISO

Upload to the `osdcloud` container with blob name `OSDCloud.iso` (no version in the blob name - the stable URL always points to `OSDCloud.iso`):

- Via Azure Portal: Storage account → Containers → osdcloud → Upload
- Via Azure CLI:
  ```bash
  az storage blob upload \
    --account-name youraccount \
    --container-name osdcloud \
    --name OSDCloud.iso \
    --file 'C:\OSDCloud\ISO\OSDCloud-v1.0.0.iso'
  ```

### 5. Configure DNS CNAME

At your DNS registrar, add one record:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| CNAME | `download.osdcloud` | `youraccount.blob.core.windows.net` | Auto / 3600 |

Replace `youraccount` with your actual Azure Storage account name.

### 6. Verify

After DNS propagates (allow up to 24 hours, usually minutes):

```
https://download.osdcloud.tehpaartos.com/osdcloud/OSDCloud.iso
```

Should download the ISO. Test with a browser and verify the file size matches.

---

## Releasing a New ISO Version

1. Build the new ISO: `.\BootImage\New-OSDCloudISO.ps1`
2. Test it on real hardware before publishing
3. Upload to Azure Blob Storage, overwriting the existing `OSDCloud.iso` blob
4. Update `VERSION` file: e.g. `1.1.0`
5. Add entry to `CHANGELOG.md`
6. Commit and push to `main`
7. Verify the download URL still works

---

## Moving to a Different Host

1. Upload the ISO to the new storage provider
2. At your DNS registrar, update the `download.osdcloud` CNAME to point to the new hostname
3. Wait for DNS propagation
4. Verify the download URL works

**Nothing else changes** - not the README, not any scripts, not any community-facing links.

---

## URL Summary

| Purpose | URL |
|---------|-----|
| Community landing page | `https://github.com/Tehpaartos/OSDCloud` |
| ISO download (stable) | `https://download.osdcloud.tehpaartos.com/osdcloud/OSDCloud.iso` |
| ISO actual location | `https://youraccount.blob.core.windows.net/osdcloud/OSDCloud.iso` |
| Live deployment script | `https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1` |
