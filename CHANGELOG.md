# Changes

## Windows 0.3.2 beta — collection and system-default parity

- Bundle the same 20 cursor choices as Mac, with approved Ancestor and No Smoking names.
- Seed the collection once, preserving existing edits, favorites and deletions.
- Keep the current app font; handwritten alternatives were not selected.
- Match the Soft Bloom app icon and unboxed header logo.
- Open Cursors first and expose System Default in the library, footer and tray.
- Reload the configured Windows cursor scheme rather than replaying stale originals.
- Start new cursors and all default pack roles at visual size 40, respecting display scaling.
- Verify actual x64/ARM64 executable headers when packaging self-contained test ZIPs.


## Unreleased — Windows source preview (`codex/windows`)

- Add a native .NET 10 / WPF Windows app with the Soft Bloom theme and all 11
  shared pack slots at an initial size of 40.
- Add image import, library search/favorites, pack editing/renaming, click-point
  preview, shared pack import/export, and themed editor menus and confirmations.
- Support nine Win32 system cursor roles with preflight, rollback, original
  restoration, tray lifecycle and recovery after an interrupted session.
- Preserve Grab/Grabbing for preview and cross-platform sharing.
- Add portable transaction/persistence tests, native Windows creation checks,
  isolated UI review, and unsigned self-contained x64/ARM64 development packaging.
- Do not publish installers. Hands-on Windows validation and signing are pending.

## 0.2.0 — Mac beta candidate

- Add Soft Bloom as the default pack, with 11 botanical cursors at 40 pt.
- Use a yellow and sage theme with custom menu popovers and a visible pack rename action.
- Preserve existing packs and user edits when installing the new default.

- Simplify the window to one library column with Cursors/Packs tabs and a favorites filter.
- Keep Apply and Restore together in a fixed action bar; show dismissible messages separately.
- Show every pack role in a wrapping grid and keep import, export, and help easy to reach.

- Rename the product to Cute Cursor and preserve existing saved libraries.
- Create and edit matching packs with 11 slots covering ten common cursor roles.
- Include the original Lilac essentials pack.
- Share `.cutecursor` files containing images, sizes, and click points.
- Keep pack settings independent of the single-cursor library.
- Apply packs, restore omitted roles when switching, and restore originals on quit.
- Correct restore ordering for numeric macOS cursor registrations.
- Validate complete pack imports before writing images or library data.
- Add universal Mac DMG/ZIP packaging, checksums, and optional Developer ID
  signing and notarization; development files are clearly labelled.
- Release code and original bundled artwork under MIT.

Known limits: static images only; private system APIs; macOS 27 / Apple Silicon
registry testing so far. Public notarization and the broader visual compatibility
matrix are pending. Windows is not yet implemented.
