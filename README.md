<p align="center">
  <img src="Sources/CursorStudio/Resources/SoftBloom/soft-bloom-pointer.png" width="80" alt="Soft Bloom flower">
</p>
<h1 align="center">Cute Cursor</h1>
<p align="center">A little flower for your everyday clicks.</p>
<p align="center">Native Mac &amp; Windows apps · Custom cursor packs · MIT licensed</p>

Cute Cursor lets you turn images into cursors and build a matching set for your Mac or Windows PC.
It comes with **Soft Bloom**, a yellow-and-sage flower pack with 11 cursor roles,
each starting at **40 pt**.

**Source preview — not a finished release.** This repository contains the app's
source, artwork, examples, and development tools. **There are no published DMG,
ZIP app downloads, or Windows installers yet.** You can build either app locally; Windows development is on `codex/windows`.
Signing, notarization, and broader compatibility testing remain before a public
installer release.

![Cute Cursor showing the Soft Bloom pack and botanical interface](docs/images/soft-bloom.png)

## What you can do

- **Create your own cursor.** Import an image, adjust its size and click point,
  and try it in the preview area.
- **Build a complete pack.** Set an image for each cursor role, or choose one from
  your library. Rename the pack with the pencil beside its name.
- **Start with Soft Bloom.** Rounded yellow flowers, cream hands, and sage-green
  accents across all 11 slots. Every default slot starts at 40 pt and is editable.
- **Apply across your desktop.** Use Apply cursor or Apply pack. Some apps draw their
  own cursors; see the compatibility notes below.
- **Return to normal.** Restore default stays in the bottom bar and menu bar.
  Quitting also restores the original cursors; closing the window keeps the app running.
- **Share your work.** Export one `.cutecursor` file with its images, sizes, and
  click points. Import through the app or drag and drop.

The interface uses a warm cream background, yellow buttons, sage-green text,
compact menus, and matching confirmation dialogs. The header flower has no tile
behind it. Native file pickers retain their system appearance. The image above shows the Mac
app; see the [Windows implementation and plan](docs/WINDOWS.md) for its features
and platform differences.

## Cursor roles

| Role | Used for |
| --- | --- |
| Pointer | Everyday pointing and clicking |
| Link | Links and other clickable items |
| Text | Text selection and insertion |
| Grab | Items you can drag |
| Grabbing | An active drag |
| Horizontal resize | Left/right resizing |
| Vertical resize | Up/down resizing |
| Diagonal resize ↖↘ | Top-left / bottom-right resizing |
| Diagonal resize ↗↙ | Top-right / bottom-left resizing |
| Crosshair | Precise selection |
| Not allowed | An unavailable action |

Pack settings are independent of the single-cursor library. Empty slots use the
cursor definitions captured before Cute Cursor first applied a change.

Try the shareable [Soft Bloom pack](Examples/Soft-Bloom.cutecursor).
The earlier [Lilac essentials example](Examples/Lilac-essentials.cutecursor) is
also included. These are **pack data files**, not application installers.

## Build on your Mac

Requirements: macOS, Xcode with Swift 5.9 or newer and the macOS 15 SDK or newer,
and Xcode's command-line tools selected. The app's deployment target is macOS 14.
No API keys, environment secrets, or third-party packages are needed.

```sh
git clone https://github.com/vigneshkae/cute-cursor.git
cd cute-cursor
./scripts/test.sh
./scripts/build-app.sh --universal --install
open "$HOME/Applications/Cute Cursor.app"
```

The build script creates a universal Apple Silicon/Intel **development build**,
installs it under `~/Applications`, and writes a local DMG, ZIP, and checksums to
`dist/`. These files are ad-hoc signed and not notarized. They are ignored by Git
and are not published by CI. Omit `--install` to build without installing.

The internal Swift package and executable are named `CursorStudio` for continuity
with the prototype; the app is named **Cute Cursor**.

## Build on Windows

On the `codex/windows` branch, install the .NET 10 SDK and run:

```powershell
dotnet run --project Windows/CuteCursor.Tests
dotnet run --project Windows/CuteCursor.Windows
./scripts/build-windows.ps1 -Runtime win-x64
# Or: ./scripts/build-windows.ps1 -Runtime win-arm64
```

The script creates a self-contained, unsigned development ZIP with `CuteCursor.exe`
and the license. It does not upload anything. See [Windows setup, architecture,
recovery, and testing](docs/WINDOWS.md) before trying system-wide changes.

![Cute Cursor for Windows with the Soft Bloom pack](docs/images/windows-soft-bloom.png)

*Windows interface rendered from the WPF app in CI.*

## Image and pack support (Mac)


- PNG, JPEG, WebP, HEIC/HEIF, TIFF, BMP, ICO, GIF, and static CUR files that macOS
  ImageIO can decode. Transparent PNGs work best.
- Animated and multi-image files use only their **first frame**. ANI, SVG, and
  Mousecape `.cape` files are not supported.
- Images: up to 16 MB and 16,384 pixels per side; imported images are downsampled
  to at most 256 pixels. Cursor display size: 16–64 logical points.
- Packs: portable JSON with embedded PNGs, up to 11 unique roles and a 16 MB limit.
  See the [pack format specification](docs/PACK_FORMAT.md).

## Compatibility and current limits

System-wide replacement uses undocumented macOS functions isolated in
`Sources/CursorSystem`. It is experimental and intended for direct distribution,
not the Mac App Store. macOS updates may change or remove this behavior.

The app has been tested locally on **macOS 27 / Apple Silicon**. macOS 14, 15, 26,
and Intel runtime compatibility still need hands-on verification; compiling an
Intel slice is not a runtime test. Diagonal resize roles may be unavailable on
older macOS versions. Some apps and websites use their own cursor rendering.

If custom pointer colors in macOS Accessibility settings prevent replacement,
reset those colors and try again. If the app crashes with custom cursors active,
signing out and back in clears the session changes. Normal quit attempts to
restore the originals. Editing and local previews work even when system-wide
replacement is unavailable.

**Windows has a native WPF implementation on `codex/windows`.** Nine system roles
are supported; Grab and Grabbing remain editable preview roles. Windows uses
documented Win32 APIs. Hands-on Windows compatibility testing is still pending;
see the [Windows development guide](docs/WINDOWS.md).

## Development and checks

`./scripts/test.sh` runs Swift tests and deterministic C transaction tests without
changing the system cursors. Coverage includes import validation, transparency,
click-point geometry, persistence, portable packs, rollback, and preserving user
edits when installing Soft Bloom.

GitHub Actions runs Mac tests and universal packaging, plus Windows tests, native
cursor creation checks, an isolated WPF UI render, and x64/ARM64 packaging. It has
no release-publishing step and uploads no installers. A temporary Windows UI
review image is retained in Actions.

For the optional live system check, see [validation notes](docs/VALIDATION.md).
That check briefly replaces the session's cursor roles, so run it only in an
interactive Mac session.

| Directory | Contents |
| --- | --- |
| `Sources/CursorStudio` | SwiftUI interface, library, packs, and bundled artwork |
| `Sources/CursorSystem` | Isolated macOS cursor bridge |
| `Tests` | Swift tests |
| `Windows` | WPF app, shared C# core, and Windows tests |
| `Examples` | Shareable cursor packs |
| `scripts` | Build, icon generation, and verification tools |
| `docs` | Screenshots, pack format, validation, and release preparation |

## Privacy

No accounts, analytics, or network requests. Images stay on your device. The library
is saved at `~/Library/Application Support/CursorStudio/` to preserve earlier
versions' data. On Windows, it is `%LOCALAPPDATA%\CuteCursor\library.json`. Imported original files are never modified. Updating the default
pack preserves existing packs, renames, size changes, and intentional deletion.

## Roadmap

- Finish Mac installation, upgrade, and compatibility testing.
- Sign, notarize, and publish the first Mac beta as GitHub Release assets.
- Verify the Windows implementation on real x64 and ARM64 machines, then prepare
  signed distribution.

See [release preparation](docs/RELEASING.md) and the [changelog](CHANGELOG.md).

## License and contributions

Code and included artwork are distributed under the [MIT License](LICENSE).
You can inspect, modify, redistribute, and sell modified versions while preserving
the license notice. Imported third-party images remain subject to their owners'
rights. See [artwork provenance](docs/ARTWORK.md) for the included assets.

This is an independent implementation: no code or artwork was copied from
Mousecape or Mousecape-swiftUI, and neither is a dependency.

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and
[AGENTS.md](AGENTS.md). Please include your OS version and hardware when reporting
cursor behavior problems.
