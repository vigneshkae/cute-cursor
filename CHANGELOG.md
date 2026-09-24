# Changes

## 0.3.0 (5) — Mac collection release

- Bundle 20 maintainer-supplied cursors with clear, consistent names.
- Start every new cursor and default pack role at 40 logical points.
- Adopt matching uploaded originals without duplicates and preserve user edits.
- Keep intentional deletions and renames when reopening the app.
- Add a System Default choice that restores native cursors and clears the custom preview.
- Generate the Dock/Finder icon from the exact flower used in the app header.
- Open the individual cursor collection first.

## 0.2.0 (4) — Mac beta 1

- Distribute universal Developer ID signed Mac downloads with Apple notarization
  and stapled verification tickets for both the app and DMG.
- Preserve release staging files after packaging failures so notarization can
  resume after a network timeout.

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
registry testing so far. The broader visual compatibility matrix remains pending.
Windows is implemented separately on `codex/windows` and
remains an unsigned preview requiring hardware testing.
