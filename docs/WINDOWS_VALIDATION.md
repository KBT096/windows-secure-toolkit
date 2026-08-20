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

| Surface | Local Windows 11 Pro for Workstations build 26200 | GitHub Actions Windows runner | What it proves |
| --- | --- | --- | --- |
| C# build | Verified | Verified | The checked-in source compiles for .NET Framework 4.8 |
| CMD/BAT entry points | Verified | Verified | The real Windows entry point forwards exit codes |
| `self-test`, `version`, `help`, `plan` | Verified | Verified | Core parsing and no-change checks run |
| `doctor` and `doctor --json` | Verified | Verified | Diagnostic output is available without system changes |
| Audit reports | Verified | Verified | Markdown and JSON reports can be generated |
| Apply / Restore | Not run on the maintainer machine | Not run | Static coverage does not replace a deliberate, backed-up system test |

The CI job is a smoke-test gate, not a privileged deployment test. Before reporting a real Apply or Restore result, record the Windows edition/build, elevation state, exact command, backup path, and whether a reboot or policy refresh occurred.
