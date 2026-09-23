# Changes

## 0.2.0 — Mac beta candidate

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
