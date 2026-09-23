# Mac beta validation — September 23, 2026

Environment: macOS 27, Apple Silicon, Xcode's macOS 27 SDK.

Passed:

- 18 Swift tests covering legacy library preservation, image import, transparency,
  size/click-point geometry, pack round trips, complete validation before writes,
  duplicate roles/unsupported versions, corrupt manifests, independent pack edits,
  shared-image retention, empty slots, removal of missing images, Soft Bloom
  transparency/click points at 40 pt, and migration preserving edits and deletion.
- In-memory C registry tests: missing-role preflight preserves the current pack;
  registration failure rolls back; failed rollback preserves retry snapshots;
  an explicit restore retry recovers. These tests do not alter system cursors.
- Live system pack integration: apply all 11 roles at two sizes, verify the 15
  mapped entries, switch to pointer-only and verify omitted roles, then restore
  and compare the original pixel data, dimensions, and click points for every entry.
- User confirmed the purple link hand and text I-beam work outside Cute Cursor
  throughout the system. Other role appearances need their own visual checks.
- Inspected pack editor in the running app and exported the bundled Lilac pack
  through its native Save dialog; 11 roles and embedded images were verified.
- Universal binary verified for arm64 and x86_64. Both slices target macOS 14.
- Development ZIP extracted and its ad-hoc signature, metadata, architectures,
  and pack file association validated. DMG integrity and SHA-256 checksums passed.
- `./scripts/build-app.sh --release` correctly refused to run without a Developer
  ID Application signing identity (exit 2). Developer ID setup was completed
  afterward; final release signing and notarization have not been performed.

Not yet verified:

- macOS 14/15/26 behavior, Intel hardware, every cursor role visually in other apps.
- Cold-launch Finder pack opening and OS upgrade behavior.
- Developer ID signing, notarization, stapling, and Gatekeeper on a downloaded build.
- Windows: no implementation or executable exists yet.

This is evidence for a Mac beta, not a claim of a fully validated public release.

## Interface and source-preview checks

- Soft Bloom installed from the eleven supplied PNGs; every initial slot is 40 pt.
- Inspected the yellow-and-sage interface, compact menu layout, and unboxed header logo.
- Verified the custom removal sheet and Cancel without deleting user content.
- Universal development app built, installed, and its ad-hoc signature verified.
- Source preview includes screenshots and pack data, with no installer release.

## Optional live system test

This changes session cursors briefly and restores them. Run only in an interactive
Mac session, never on unattended CI:

```sh
clang scripts/test-system-pack.m Sources/CursorSystem/CursorSystem.c \
  -I Sources/CursorSystem/include -framework Cocoa -framework ApplicationServices \
  -o /tmp/cute-cursor-system-pack
/tmp/cute-cursor-system-pack
```
