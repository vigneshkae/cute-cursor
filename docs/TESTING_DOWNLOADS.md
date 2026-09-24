# Mac and Windows test downloads

## Windows 0.3.2 beta

Windows builds are prepared from `codex/windows` and published as GitHub Release
assets. The repository is public. These portable packages are unsigned testing
builds, not signed final installers.

- **Cute-Cursor-Windows-x64.zip**: Intel and AMD Windows PCs.
- **Cute-Cursor-Windows-ARM64.zip**: Windows-on-ARM PCs.

Check Windows Settings → System → About → System type if unsure. Extract the
whole ZIP and open **CuteCursor.exe**. Keep `LICENSE.txt` with it. No separate
.NET installation, administrator access, or installer is required. Windows may
show an unknown-publisher or reputation warning because these EXEs are unsigned.
Initial testing targets Windows 11. Do not disable Windows security globally.

The packaging script validates each executable's actual PE architecture. CI
launches the packaged x64 app, validates all 20 collection images and 11 pack
roles, creates native cursor handles, and checks UI defaults without replacing
live system cursors. ARM64 is cross-published and needs a native ARM64 PC test.
Actual system-wide Apply/Restore behavior still needs interactive Windows testing.

### What to test

1. Cursors opens with 20 options, including **Ancestor** and **No Smoking**.
2. Every new cursor and all 11 Soft Bloom roles start at visual size **40**.
   At 150% display scaling, 40 logical units render as 60 physical pixels.
3. Import a PNG, adjust its click point and size, and try the preview area.
4. Apply a cursor or pack. Check pointer, link, text, resize, crosshair and
   not-allowed roles outside Cute Cursor. Grab/Grabbing are preview-only.
5. Click **System Default** in the library, footer or tray. The configured Windows
   cursor scheme should return and the custom preview should clear.
6. Apply again, close to the tray, reopen, and choose Exit. Previous cursors should
   return. System Default also works after relaunch with no active selection.
7. Rename, favorite or remove a cursor; relaunch and confirm the edit persists.
   Existing libraries should gain the collection once without losing user edits.
8. Export a pack and import it on Mac; compare sizes and click points.

Each ZIP has an adjacent `.sha256` file. Compare its hash with
`Get-FileHash -Algorithm SHA256` in PowerShell. See [Windows details](WINDOWS.md)
for recovery, supported image formats, display scaling and the full test matrix.

## Mac

Use the [notarized Mac 0.3.1 beta](https://github.com/vigneshkae/cute-cursor/releases/tag/v0.3.1-beta.1),
not the older development-preview DMG. It includes Apple Silicon and Intel code;
Intel runtime behavior and older macOS versions still need hands-on checks.
The current Mac app/library can be renamed independently of that published build.
