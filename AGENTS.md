# Cute Cursor

Independent native macOS and Windows apps. Do not copy code or artwork from sibling Mousecape
repositories; they are not dependencies and must never be included in this repo.
Code and original bundled artwork are MIT licensed.

- SwiftUI and AppKit, deployment target macOS 14+. No external packages.
- Internal package/executable and legacy library directory remain CursorStudio.
  User-facing name is Cute Cursor. Preserve the user's existing library.
- `./scripts/test.sh` validates images, persistence, pack parsing, and geometry.
- `./scripts/build-app.sh --universal` builds a development DMG/ZIP, ad-hoc signed.
- `--release` requires Developer ID signing and notarization. Never label a dev
  build as a public signed release. Read docs/RELEASING.md.
- Keep private APIs isolated in Sources/CursorSystem. They are experimental and
  unsuitable for the Mac App Store. Report missing roles and failed restores.
- Restore originals when switching to partial packs and on quit. Preserve retry
  state if recovery fails. Keep preview usable when system APIs are unavailable.
- `scripts/test-system-pack.m` changes live cursors, then restores them. Only run
  in an interactive Mac session, not CI. Do not claim visual compatibility merely
  because registry calls succeeded.
- Portable pack schema is documented in docs/PACK_FORMAT.md; validate the entire
  pack before writes. Pack settings must not mutate library items.
- Windows is implemented separately under `Windows/`; read `Windows/AGENTS.md`.
- Mac notarized betas are published on GitHub. Windows remains an unsigned testing
  beta. Never commit installers or describe Windows previews as signed releases.
