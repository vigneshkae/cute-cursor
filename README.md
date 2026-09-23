# Cute Cursor

A small native Mac app for making your everyday cursors a little more you.
Import your own images, choose the click point, and build a matching cursor pack.

**Status: Mac beta, 0.2.0.** macOS 14+ is the build target. System replacement has
been tested on macOS 27 on Apple Silicon; other macOS versions and Intel Macs
still need hands-on testing. Windows is planned, not available yet.

## Download

Open this repository's **Releases** section for published installers. Public Mac
releases use `Cute-Cursor-macOS.dmg` (or `.zip`). Open the DMG and drag **Cute Cursor**
to Applications. You do not need Git, Xcode, or the source code to install it.

Files ending in `-dev` are local development builds. They are ad-hoc signed and
not notarized; they are not the public release. A stable public release is still
pending Developer ID signing, notarization, and the compatibility checks below.

GitHub hosts release downloads. No website, Railway server, login, or subscription
is needed to use the app. See [release preparation](docs/RELEASING.md).

## Make it yours

- **Single cursor:** drop a PNG or choose Add cursor, adjust its size and click
  point, try the preview, and choose Apply pointer.
- **Full pack:** open Cursor packs, try the original Lilac essentials set, or
  create a pack. Choose an image for each slot or use an image from your library.
- **11 slots:** pointer, link, text, grab, grabbing, horizontal resize, vertical
  resize, both diagonal resizes, crosshair, and not allowed.
- Pack settings are independent of your library. Empty slots use the cursor
  definitions that were active before Cute Cursor first applied a change.
- Export a `.cutecursor` pack to share all its images, sizes, and click points.
  Import it by dragging it into the app, using Import, or double-clicking it. A shareable original pack is included in `Examples/`.
- Restore default returns the original cursors. Quitting also restores them;
  closing the window keeps the app running in the menu bar.

## Images and packs

PNG, JPEG, WebP, HEIC/HEIF, TIFF, BMP, ICO, GIF, and static CUR files that macOS
ImageIO can decode are accepted. Transparent PNGs are recommended. Animated and
multi-image files use **only the first frame**. ANI, SVG, and Mousecape `.cape`
files are not supported. Each image must be under 16 MB, at most 16,384 pixels per
side, and is downsampled to a maximum of 256 pixels. Display size is 16–64 points.

Pack files are portable JSON with embedded PNGs, a maximum of 11 unique slots,
and a 16 MB file limit. See [the format specification](docs/PACK_FORMAT.md).
The Windows version can use these role names and images when implemented.

## Compatibility

System replacement uses optional, undocumented macOS functions, isolated in
`Sources/CursorSystem`. OS updates can change this behavior. Some apps and websites
draw their own cursors, which these replacements do not affect. Changed macOS
Accessibility pointer colors can prevent replacement; reset the pointer colors
and try again. A role missing from the current system is reported before applying.
Diagonal resize slots may be unavailable on older macOS versions.

The editor and local preview remain usable when system replacement is unavailable.
A successful API call is not proof that every app displays the new cursor. This
implementation is intended for direct distribution, not the Mac App Store.

If the app crashes while a custom cursor is active, signing out and back in clears
session cursor changes. Restoring is always attempted on a normal quit.

## Build and test

Install Xcode, select its developer tools, then run:

```sh
./scripts/test.sh
./scripts/build-app.sh --universal --install
open "$HOME/Applications/Cute Cursor.app"
```

The internal Swift package/executable is still named `CursorStudio`; the user-facing
app is **Cute Cursor**. The build script stages signing outside cloud-synced folders
and outputs development DMG/ZIP files and SHA-256 checksums under `dist/`.

Automated tests cover import, transparency, geometry, persistence, corrupt data,
pack validation, round trips, independent edits, and missing files. Deterministic C tests also simulate registration and recovery failures without changing system cursors. For the opt-in
live system test, which briefly changes all supported roles and restores them:

```sh
clang scripts/test-system-pack.m Sources/CursorSystem/CursorSystem.c \
  -I Sources/CursorSystem/include -framework Cocoa -framework ApplicationServices \
  -o /tmp/cute-cursor-system-pack
/tmp/cute-cursor-system-pack
```

Run this only in an interactive Mac session, not CI. It verifies full/partial pack
switching, registered sizes and click points, and restoration of the original
bitmap data. The user also confirmed the link hand and text cursor outside the app on macOS 27. Visual checks for every other role and OS version remain necessary before a stable release.

## Privacy

The app has no accounts, analytics, or network requests. Images stay on your Mac.
The saved library remains at `~/Library/Application Support/CursorStudio/` to
preserve data from the original prototype. Existing library files are not reset
when the app is renamed. Imported originals are never modified. Referenced images
are retained when removing a pack to avoid deleting images used elsewhere.

## Source and license

Code and original bundled artwork are available under the [MIT License](LICENSE).
You may inspect, modify, redistribute, and sell modified versions while preserving
the license notice. Rights to images you import remain with their respective owners.

This project contains no copied code or artwork from Mousecape or Mousecape-swiftUI.
Only this directory belongs in the Cute Cursor repository; sibling projects are
not dependencies and must not be included when publishing.

See [CONTRIBUTING.md](CONTRIBUTING.md) to contribute.
