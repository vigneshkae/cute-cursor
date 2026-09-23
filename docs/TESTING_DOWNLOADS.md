# Private Mac and Windows test downloads

[Open the test release](https://github.com/vigneshkae/cute-cursor/releases/tag/private-test-2026-09-23.1)
while signed into a GitHub account with access to this private repository.
A private download link does not grant access by itself; an unauthorized visitor
may see a 404 page.

These are development builds for testing, not a final public release. Mac source
matches the `codex/mac-beta` checkpoint; Windows source is from `codex/windows`.
The tag captures both implementations and the packaging workflow.

## MacBook

Download **Cute-Cursor-macOS-dev.dmg**, open it, and drag **Cute Cursor** to
Applications. Quit the previous copy before replacing it. The build includes
Apple Silicon and Intel code and targets macOS 14 or later. ARM64 has been tested
locally; older macOS versions and Intel runtime behavior still need verification.

A ZIP of the same app is also supplied as **Cute-Cursor-macOS-dev.zip**.
The app is ad-hoc signed and **not notarized**. macOS may block the first launch;
only approve a build downloaded from this repository after checking its source
and checksum. The Developer ID certificate exists, but the expected
`cute-cursor-notary` Keychain credential profile is not configured yet.
Do not disable Gatekeeper globally.

## Windows

Download **CuteCursor-windows-preview-win-x64.zip** for most Intel/AMD Windows PCs.
Use **CuteCursor-windows-preview-win-arm64.zip** for a Windows-on-ARM PC.
Check Settings → System → About → System type if unsure.

Extract the whole ZIP, then open **CuteCursor.exe**. Keep `LICENSE.txt` with it.
The .NET runtime is bundled; no separate SDK or runtime installation is needed.
No administrator access or installer is required. These EXEs are **unsigned**,
so Windows may display a publisher or reputation warning. Do not disable Windows
security globally. Initial testing targets Windows 11.

The x64 packaged EXE passed native image and cursor-creation smoke tests in CI.
ARM64 was cross-published; it still requires testing on actual ARM64 Windows.

## What to test

1. Start with Soft Bloom. All eleven slots should initially show size 40.
2. Import a PNG, adjust its click point and size, and try the preview area.
3. Apply the pack and check the pointer, link, text and resize cursors outside
   Cute Cursor. Windows applies nine roles; grab/grabbing remain preview-only.
4. Switch to a pointer-only selection and verify other roles return to normal.
5. Use Restore, then apply again and choose Exit/Quit. Verify original cursors return.
6. Rename and export a pack, import it on the other OS, and compare its settings.
7. Relaunch and confirm edits remain. Closing the window keeps the app running
   in the Mac menu bar or Windows system tray; Exit/Quit restores the cursors.

Back up any important custom packs with Export before testing. Imported original
image files are never changed. See `docs/WINDOWS.md` for Windows crash recovery
and `docs/VALIDATION.md` for the current compatibility limits.

## Verify the download

Each release includes **SHA256SUMS.txt**. On Mac, run `shasum -a 256` on your
chosen downloaded file; on Windows, run `Get-FileHash -Algorithm SHA256` in
PowerShell. Compare the result with the corresponding line in the checksum file.
