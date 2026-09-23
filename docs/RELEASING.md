# Releasing Cute Cursor for Mac

## Current release status

0.2.0 is a beta candidate. Development builds are ad-hoc signed. No public release
should be described as notarized until both signing and notarization have passed.
Windows installers are not available. Do not attach a placeholder EXE.

## Before a stable release

- Run `./scripts/test.sh` and the opt-in system pack test described in README.
- Visually verify pointer, link, text, hands, resizes, crosshair, and not-allowed
  states outside the app. Verify Apply, switching to a partial pack, Restore, and Quit.
- Test macOS 14, 15, 26, and 27 where supported, and an Intel Mac. Mark unsupported
  versions clearly; compiling an Intel slice is not a runtime compatibility test.
- Test opening a downloaded pack from Finder, installing from the DMG, upgrading
  with an existing library, and running with no network connection.
- Check the final name, app icon, About/version, license, and screenshots.

## Public build

Enroll in Apple's Developer Program. Install a **Developer ID Application**
certificate with its private key on the signing Mac. An Apple Development
certificate is not a replacement for a distribution certificate.

Store notarization credentials with Apple's `xcrun notarytool store-credentials`.
Keep certificate files, passwords, and tokens out of Git.

```sh
export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'
export NOTARYTOOL_PROFILE='cute-cursor-notary'
./scripts/build-app.sh --release
```

The script builds Apple Silicon and Intel slices, signs with hardened runtime,
notarizes and staples the app, checks Gatekeeper, builds the DMG, notarizes and
staples it, and writes:

- `dist/Cute-Cursor-macOS.dmg`
- `dist/Cute-Cursor-macOS.zip`
- `dist/Cute-Cursor-macOS-SHA256SUMS.txt`

If signing or notarization fails, do not substitute development files in the
release. Update versions in `Resources/Info.plist` before building a new release.

## GitHub

Publish only the contents of the Cute Cursor project directory, with LICENSE.
The repository can be public even when the app's final signed release is pending.
Upload installers as **Release assets**, never as source files committed to Git.
Create a draft release, attach the signed files, review notes and checksums, then
publish the release. For beta testing, mark it as a prerelease.

The CI workflow tests and builds a development artifact for contributors. It does
not publish releases, use signing credentials, or claim notarization.

Once a stable release exists, these patterns provide download buttons without
hosting a website (replace OWNER and REPO with the published repository):

```text
https://github.com/OWNER/REPO/releases/latest
https://github.com/OWNER/REPO/releases/latest/download/Cute-Cursor-macOS.dmg
```

`latest` selects a stable release, not a prerelease. For a beta, link to its explicit
tag instead, using `/releases/download/TAG/Cute-Cursor-macOS.dmg`.
The repository's automatic “Source code.zip” is not an app installer.
