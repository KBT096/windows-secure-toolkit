# Windows validation notes

This document describes the small, repeatable validation surface behind the `doctor` command. It is deliberately narrower than a claim that every Windows edition has been tested.

## Read-only doctor

```cmd
win_secure.cmd doctor
win_secure.cmd doctor --json
```

The command reads platform information, the .NET Framework 4.x `Release` registry value, WMI operating-system metadata, the native tools used by this repository, and the optional Defender command-line tool. It does not change registry values, firewall policy, services, accounts, or files. `Unavailable` means that the capability could not be confirmed in the current environment; it is not an instruction to install or enable anything.

The JSON form has `SchemaVersion`, `ToolkitVersion`, `GeneratedUtc`, `ComputerName`, and a `Checks` array. Each check has an identifier, status, human-readable summary, detail, and a `Required` hint. Consumers should treat unknown statuses or fields as review items so the schema can grow without breaking older collectors.

## Current matrix

| Surface | Windows 10 maintainer test | Windows 11 Pro for Workstations build 26200 maintainer test | GitHub Actions Windows runner | What it proves |
| --- | --- | --- | --- | --- |
| C# build | Not recorded in this matrix | Verified | Verified | The checked-in source compiles for .NET Framework 4.8 |
| CMD/BAT entry points | Not recorded in this matrix | Verified | Verified | The real Windows entry point forwards exit codes |
| `self-test`, `version`, `help`, `plan` | Not recorded in this matrix | Verified | Verified | Core parsing and no-change checks run |
| `doctor` and `doctor --json` | Not recorded in this matrix | Verified | Verified | Diagnostic output is available without system changes |
| Audit reports and `audit --json` | Not recorded in this matrix | Verified | Verified | Markdown, file JSON, and standard-output JSON can be generated |
| Secure Boot audit | Not recorded in this matrix | Verified | Smoke-tested | The registry-backed state is reported without changing firmware settings |
| BitLocker audit | Not recorded in this matrix | `Unavailable` without elevation | Smoke-tested | The command handles inaccessible or absent providers without treating them as an unencrypted result |
| Apply / Restore | Verified by the maintainer | Verified by the maintainer | Not run | The real privileged paths were exercised locally on both versions; CI intentionally does not perform system-changing operations |

The maintainer has completed backed-up `Apply` and `Restore` validation on Windows 10 and Windows 11 through the normal elevated and confirmation flow. This is version-level evidence from the maintainer's test machines; it is not a claim that every Windows edition, policy combination, or managed environment behaves identically. A `Not recorded in this matrix` entry means that a separate result for that surface was not retained here; it does not mean the command is unsupported. For BitLocker, `Unavailable` means the current token or WMI provider did not expose the state; it is not a negative encryption finding.

The CI job remains a smoke-test gate, not a privileged deployment test. If behavior differs on Windows 10 or Windows 11, open an [Issue](https://github.com/KBT096/windows-secure-toolkit/issues) with the toolkit version, Windows edition/build, elevation state, exact command, sanitized output, and whether the backup was retained. Do not attach secrets, raw audit reports, or private system identifiers.
