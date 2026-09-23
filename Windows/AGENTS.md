# Cute Cursor for Windows

- Native WPF, .NET 10, no third-party runtime dependencies. Keep the Mac app independent.
- `CuteCursor.Core` owns portable packs, persistence, and transactional cursor replacement.
- `CuteCursor.Windows` owns WPF image decoding, UI, and isolated Win32 calls.
- `CuteCursor.Tests` is an executable test harness; run with `dotnet run --project Windows/CuteCursor.Tests`.
- The UI, image decoder, and native smoke tests require Windows; core tests run on macOS too.
- Never run SetSystemCursor in CI. Use fake-backend tests for apply/rollback/restore.
- Preserve the original cursor handles until restoration succeeds. Don't write cursor registry settings.
- Grab and grabbing are preview-only Windows roles; never map them to unrelated system slots.
- Default pack data is linked from `Examples/Soft-Bloom.cutecursor`; don't duplicate the Mac PNGs.
- No final release, installer upload, code signing, or main-branch merge without user direction.
