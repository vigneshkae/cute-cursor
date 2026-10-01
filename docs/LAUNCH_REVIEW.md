# GitHub launch review — October 1, 2026

**Decision: the current downloads are suitable for beta testing. Do not present
these builds as a fully validated stable launch.** No release tag or binary was
replaced or promoted during this review.

## What was checked

- The repository is public, the default branch is `main`, and no open issues or
  pull requests were listed at review time. Mac source is on main; Windows source
  remains on `codex/windows` as intended.
- The latest main and Windows branch checks passed. Both published release tags
  have successful build checks. All five published releases are marked prerelease.
- Downloaded all seven current release assets anonymously from GitHub: Mac DMG,
  ZIP and checksums, plus both Windows ZIPs and their checksum files. Each size and
  SHA-256 matches GitHub's asset digest; all published file checksums match.
- The downloaded Mac 0.3.1 (6) app passes strict signature verification and
  Gatekeeper assessment as Notarized Developer ID. Both the app and DMG have
  valid stapled tickets. DMG integrity passes; its app matches the ZIP app exactly.
  The DMG includes an Applications shortcut and the license is included.
- The Mac executable contains both arm64 and x86_64 slices. Its metadata targets
  macOS 14 or newer. This is packaging evidence, not an Intel/older-OS runtime test.
- Both Windows ZIPs have valid archive integrity and contain CuteCursor.exe,
  LICENSE.txt, and READ-ME.txt. Their PE headers match x64 and ARM64 respectively.
  Both executables have no Authenticode certificate table and remain unsigned.
- Re-ran all 25 Swift tests and the simulated C transaction/recovery tests: passed.
  Re-ran all 34 Windows portable tests: passed. The Windows cross-build passed with
  zero warnings and errors. No live system cursors were changed during this review.
- The published Windows source previously passed native image/UI checks, 124 cursor
  variants across four scale factors, and execution of the actual packaged x64 app
  on the Windows runner. Those checks intentionally do not apply live cursors.
- MIT licensing, artwork provenance, and installer exclusions from Git are present.
  A limited history scan of 170 text versions found no recognizable private-key,
  GitHub-token, or AWS-key patterns. No signing credential files or installer
  executables were found by the tracked-history filename check. This is not a
  comprehensive security audit or a guarantee that no secret exists.

## Corrections made during the review

- Added direct Mac, Windows x64, and Windows ARM64 download links and installation
  steps to the main README, with explicit beta/signing labels.
- Corrected stale documentation that described Windows as unimplemented or missing
  the latest collection changes, and clarified automated versus hands-on checks.
- Made the two pending Mac name changes visible beside the download instructions.
- Updated the repository description and release navigation to identify current
  beta downloads rather than the earlier source preview/development builds.

## Work still needed before the intended final launch

| Item | Current evidence | Next action |
| --- | --- | --- |
| Mac approved cursor names | Published 0.3.1 contains Little Swimmer and Cigarette; source contains Ancestor and No Smoking | Package a new Mac version, sign/notarize it, and recheck the actual downloads |
| Mac compatibility | Local Apple Silicon testing and universal packaging; broader matrix remains pending | Test on supported older macOS versions and Intel hardware, or narrow the advertised tested range |
| Windows system-wide behavior | Fake-backend transactions and native creation checks pass | On a real PC test Apply, System Default, pack switching, close-to-tray, Exit, and relaunch |
| Windows ARM64 | Correctly packaged ARM64 executable | Run it on a Windows ARM device |
| Windows distribution polish | Unsigned portable ZIPs | Complete publisher signing and the planned installer; packaging as setup.exe alone does not sign the app |
| Install/upgrade experience | Archives and metadata verified | Test clean installation, upgrade with an existing library, and pack opening from the OS |

A simple download website and automatic updates are useful follow-up improvements;
they are not prerequisites for sharing the clearly labelled beta links. Use
explicit beta tags, not `/releases/latest/download`, until a stable release exists.
The old memory-profiling workflow targets the earlier development preview; it was
not treated as memory or runtime evidence for the current Windows beta.

## Evidence and downloads

- [Mac 0.3.1 beta](https://github.com/vigneshkae/cute-cursor/releases/tag/v0.3.1-beta.1)
- [Windows 0.3.2 beta](https://github.com/vigneshkae/cute-cursor/releases/tag/windows-v0.3.2-beta.1)
- [Mac main build](https://github.com/vigneshkae/cute-cursor/actions/runs/35992275610)
- [Windows published-tag build](https://github.com/vigneshkae/cute-cursor/actions/runs/35992239707)
- [Windows branch build](https://github.com/vigneshkae/cute-cursor/actions/runs/35992264933)
- [Mac validation details](VALIDATION.md)
- [Windows validation details](https://github.com/vigneshkae/cute-cursor/blob/codex/windows/docs/WINDOWS_VALIDATION.md)
