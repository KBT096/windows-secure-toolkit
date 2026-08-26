# Changelog

All notable changes are documented here. Versions follow Semantic Versioning.

## [Unreleased]

### Changed

- Documented maintainer runtime validation of `Apply` and `Restore` on Windows 10 and Windows 11.
- Clarified that GitHub Actions remains a non-privileged smoke-test gate while real system-changing validation is recorded separately.

## [1.3.2] - 2026-08-26

### Changed

- Synchronized the toolkit version metadata for the maintenance release.
- Kept quick-start downloads on the general Releases page so patch releases do not require a README filename edit.
- Kept the README focused on setup and issue reporting for this maintenance release.

## [1.3.1] - 2026-08-23

### Added

- Added a read-only `backups` command that lists local backup directories and manifest/SHA-256 status.

### Changed

- Added a latest Release badge to the Chinese and English README entry points.
- Added the repository-specific `windows-security-toolkit` GitHub topic without changing the implementation-language labels.
- Reworked the Chinese README quick entry into numbered preparation, preview, apply, and restore steps.
- Rephrased the Chinese notes as direct, neutral statements.
- Added the backup listing command to the smoke-test path.

## [1.3.0] - 2026-08-20

### Added

- A read-only `doctor` command for platform, .NET Framework, WMI, native-tool, and Defender capability checks.
- `doctor --json` output with a versioned document schema for automation and issue reports.
- A Windows validation matrix documenting what CI and local smoke tests do and do not prove.

### Compatibility

- Restore accepts v1.2.0 and v1.2.1 backup manifests when their machine, hash, schema, and allowlist checks pass.

### Verification

- Windows build, CMD smoke tests, `doctor`, `doctor --json`, and self-test passed locally and in GitHub Actions.

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

Build, launch, version, self-test, audit, plan, report generation, listener listing, and release checks were run on Windows 11 Pro for Workstations build 26200. At the time of v1.2.0, system-changing Apply/Restore was explicitly unverified on the maintainer machine; current Windows 10/11 runtime validation is documented in `docs/WINDOWS_VALIDATION.md`.

## [0.1.0] - 2026-08-18

The first public Windows toolkit layout and safety documentation.

[Unreleased]: https://github.com/KBT096/windows-secure-toolkit/compare/v1.3.2...HEAD
[1.3.2]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v1.3.2
[1.3.1]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v1.3.1
[1.3.0]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v1.3.0
[1.2.1]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v1.2.1
[1.2.0]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v1.2.0
[0.1.0]: https://github.com/KBT096/windows-secure-toolkit/releases/tag/v0.1.0
