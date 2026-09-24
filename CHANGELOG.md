# Changes

## Unreleased — decisions logged September 24, 2026

- Approved cursor names: **Ancestor** (previously Little Swimmer) and
  **No Smoking** (previously Cigarette).
- Both names are saved in the maintainer's current library and the bundled
  collection source. The published 0.3.1 download predates these name changes;
  include them in the next packaged release.

### Pending final design change

- Replace the **Cute Cursor header wordmark** font with a cute open-source font
  that suits the yellow-and-sage Soft Bloom theme. Font selection is pending;
  no font change has been applied yet.
- Shortlist: Fredoka Medium (rounded and playful), Fraunces SemiBold (soft,
  vintage character), Quicksand SemiBold (light and friendly), Comfortaa Bold
  (rounded geometric letters), and Baloo 2 SemiBold (bold and bubbly).
- Initial recommendation: Fredoka Medium for a playful logo; Fraunces SemiBold
  for a more botanical, elegant direction. These are design suggestions, not an
  approved selection.
- Each shortlisted family uses SIL OFL 1.1. If bundled, retain its copyright
  notice and OFL license alongside the app's separate MIT license. Sources:
  [Fredoka](https://github.com/google/fonts/blob/main/ofl/fredoka/OFL.txt),
  [Fraunces](https://github.com/google/fonts/blob/main/ofl/fraunces/OFL.txt),
  [Quicksand](https://github.com/google/fonts/blob/main/ofl/quicksand/OFL.txt),
  [Comfortaa](https://github.com/googlefonts/comfortaa),
  [Baloo 2](https://github.com/google/fonts/blob/main/ofl/baloo2/OFL.txt).

## 0.3.1 (6) — Mac icon and reset fix

- Recreate native system cursors even when a previous process left a custom
  cursor behind or the app has no active selection.
- Refresh the cached app icon and explicitly load the matching Soft Bloom icon.
- Publish Developer ID signed and notarized Mac app and DMG updates.

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
