# Releasing Cute Cursor for Mac

## Current release status

0.3.0 (5), the Mac collection beta, has passed Developer ID signing and Apple notarization.
Both the app and DMG carry validated tickets and pass Gatekeeper assessment.
Development builds remain ad-hoc signed. Each new release build must pass signing
and notarization again before being described as notarized.
Windows preview packages are maintained separately on `codex/windows`.

## Mac 0.3.0 release contents

The maintainer supplied 20 individual cursor options and approved proceeding
with those, replacing the earlier plan to wait for 25. These are bundled in
`Resources/Collection`, with curated names and the supplied click points.
The Mac app now uses the same Soft Bloom image for its icon and header logo.
System Default restores the native cursors and clears the custom preview.

The maintainer confirmed that “40” means the existing visual size: **40 logical
points** on Mac (80 device pixels at 2× Retina scale), not 40 physical pixels.
Fresh bundled cursors, all default pack roles, and new image imports use 40.
Existing user size edits and imported pack settings remain intact.

The Windows branch has not received these changes yet. The new Mac build and DMG have both passed signing, notarization, and ticket
validation. The previous Mac beta remains available as an older release.

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

On the signing Mac, create an app-specific password in your Apple Account, then
run this command in Terminal. Enter your developer Apple Account email and the
app-specific password at the interactive prompts; do not put the password in the
command, repository, or chat.

```sh
xcrun notarytool store-credentials 'cute-cursor-notary' --team-id 'YOUR_TEAM_ID'
xcrun notarytool history --keychain-profile 'cute-cursor-notary'
```

The second command must authenticate successfully before building. A missing
profile means the credentials were not stored under that name in the signing
user's Keychain. Creating a password on Apple's website alone does not store it
locally.

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

If the notarization wait times out, Apple may still be processing the submission.
The script preserves its staging folder when a release command fails. Check the
existing submission with `notarytool info` before submitting again. Once accepted,
staple and validate the retained app or DMG and finish packaging. A timeout is not
a rejection; do not discard the signed files or replace them with a development
build.

## GitHub

Publish only the contents of the Cute Cursor project directory, with LICENSE.
The repository can be public even when the app's final signed release is pending.
Upload installers as **Release assets**, never as source files committed to Git.
Create a draft release, attach the signed files, review notes and checksums, then
publish the release. For beta testing, mark it as a prerelease.

The CI workflow runs tests and verifies development packaging. It does not upload
installers, publish releases, use signing credentials, or claim notarization.

Once a stable release exists, these patterns provide download buttons without
hosting a website (replace OWNER and REPO with the published repository):

```text
https://github.com/OWNER/REPO/releases/latest
https://github.com/OWNER/REPO/releases/latest/download/Cute-Cursor-macOS.dmg
```

`latest` selects a stable release, not a prerelease. For a beta, link to its explicit
tag instead, using `/releases/download/TAG/Cute-Cursor-macOS.dmg`.
The repository's automatic “Source code.zip” is not an app installer.
