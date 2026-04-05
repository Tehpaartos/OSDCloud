# Contributing to OSDCloud

## Reporting Issues

Use [GitHub Issues](https://github.com/Tehpaartos/OSDCloud/issues) to report bugs, deployment failures, or compatibility problems. Include:

- The error message or symptom
- Hardware model (if relevant)
- Which step in the deployment process failed

## Submitting Changes

1. **Fork** the repository
2. Create a **feature branch** from `main` (e.g. `fix/wifi-driver-injection`)
3. Make and test your changes locally
4. Open a **Pull Request** targeting `main`
5. Describe what changed and why - link to the issue if applicable
6. A maintainer will review and merge

## Branch Protection - Read This Before Merging

`main` is the **live branch**. Changes to `Deployment/Deploy-Windows11.ps1` take effect immediately for all future deployments the moment they are merged - no USB rebuild is required.

**Before merging any change to `Deploy-Windows11.ps1`:**

1. Test the script end-to-end in a WinRE environment (VM or spare hardware)
2. Confirm the raw GitHub URL returns the updated script:
   `https://raw.githubusercontent.com/Tehpaartos/OSDCloud/main/Deployment/Deploy-Windows11.ps1`
3. Verify at least one successful Windows 11 deployment using the updated script

Do not merge untested changes to `main`.

## Building and Testing a New ISO Locally

1. Run `Setup/Install-Prerequisites.ps1` on a **Windows 10 22H2** build machine
2. Edit `Deployment/Deploy-Windows11.ps1` with your changes and push to a test branch
3. Temporarily re-stamp your USB with your branch URL to test before merging to `main`
4. Once tested, merge to `main` and run `BootImage/New-OSDCloudISO.ps1` only if the boot image itself changed

See [docs/deployment-guide.md](docs/deployment-guide.md) for the full end-to-end build process.

## Access and Questions

Open an issue on GitHub. For sensitive matters, contact the repo owner directly via GitHub.
