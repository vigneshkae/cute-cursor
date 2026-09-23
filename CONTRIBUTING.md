# Contributing to Cute Cursor

Use Xcode and macOS 14 or later. Read AGENTS.md, then run `./scripts/test.sh` before
submitting a change. Keep changes focused. Add meaningful tests for pack parsing,
persistence, image handling, and cursor registration behavior.

Do not copy code or images from cursor projects with incompatible licenses. New
contributions must be compatible with the MIT license. Use original artwork or
include clear attribution and redistribution rights.

Keep private API calls in CursorSystem, preserve usable previews when those APIs
are absent, and verify that every changed cursor can be restored. Do not enable
system-changing integration tests on unattended CI. Include macOS version and
hardware in reports of cursor application problems.

Windows is a planned separate implementation. Keep portable role names and the
pack schema stable; propose a new format version before making incompatible changes.
