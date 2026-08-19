# Changelog

All notable changes are documented here. Versions follow Semantic Versioning.

## [Unreleased]

No unreleased changes.

## [1.2.1] - 2026-08-20

### Fixed

- Restore manifest validation now rejects duplicate registry targets and requires the complete allowlist.

### Added

- Self-test coverage for the restore registry allowlist and duplicate-target tamper path.

## [1.2.0] - 2026-08-19

### Changed

- Replaced the script engine with a C# .NET Framework 4.8 executable.
- Kept the CMD/BAT entry points and the existing exit-code contract.
- Reworked the README into a shorter maintainer-style guide.
- Replaced the repository gate with a CMD smoke-test script.

### Added

- Native local process, registry, WMI, Defender, DISM, SFC, and firewall integration.
- C# self-test, JSON round-trip check, SHA-256 check, and allowlisted restore validation.
- A source build path through `build.cmd` and the .NET 6 SDK or newer.

### Verification note

Build, launch, version, self-test, audit, plan, report generation, listener listing, and release checks were run on Windows 11 Pro for Workstations build 26200. System-changing Apply/Restore remains explicitly unverified on the maintainer machine.

## [0.1.0] - 2026-08-18

The first public Windows toolkit layout and safety documentation.

[Unreleased]: https://github.com/KBT096/windows-secure-toolkit/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v1.2.1
[1.2.0]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v1.2.0
[0.1.0]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v0.1.0
