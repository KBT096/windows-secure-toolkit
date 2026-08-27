# Windows Secure Toolkit

[![CI](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/KBT096/windows-secure-toolkit?display_name=tag&sort=semver)](https://github.com/KBT096/windows-secure-toolkit/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![C%23](https://img.shields.io/badge/C%23-.NET%20Framework%204.8-512BD4.svg)](https://dotnet.microsoft.com/)

Windows security settings are a bit like the fuse box: nobody wants to stare at it all day, but a small record is useful when something goes wrong.

Current version: `1.3.3`.

This is a small local toolkit with a CMD/BAT entry point and a C# engine. It checks, previews, backs up, and restores a conservative set of settings. It does not promise a magic “secure” button. Sadly, those are still out of stock.

## Core architecture and features

- read-only checks for firewall, Defender, UAC, SMBv1, Guest, RDP/NLA, AutoRun, updates, and pending reboot;
- Markdown and JSON audit reports;
- a preview-first baseline with explicit elevation and confirmation;
- a SHA-256 checked manifest and firewall backup before changes;
- same-machine, allowlisted restore;
- a read-only backup listing with manifest and SHA-256 status;
- Defender quick scan, DISM/SFC verification, and TCP listener listing;
- a read-only compatibility doctor for Windows, .NET Framework, WMI, and native tools, with JSON output;
- GitHub Release metadata checks only. It does not download and run remote code.

## Notes and boundaries

- open inbound ports, enable RDP, or create administrator accounts;
- reboot the computer or automatically repair DISM/SFC findings;
- upload reports, usernames, IP addresses, or other local data;
- bypass organization policy or endpoint management;
- claim that every Windows edition or policy environment has been tested;
- treat the maintainer's Windows 10/11 runtime validation as a guarantee for every managed or customized machine.

The maintainer has completed real, backed-up `Apply` and `Restore` validation on Windows 10 and Windows 11. If behavior differs, please open an [Issue](https://github.com/KBT096/windows-secure-toolkit/issues) with the toolkit version, Windows edition/build, elevation state, exact command, and sanitized output. Do not attach secrets, raw audit reports, or private system identifiers.

## 📖📖 Quick entry: how do I configure and run Windows Secure Toolkit?

The target is Windows 10/11 and Windows Server 2019/2022/2025. A compiled build needs .NET Framework 4.8; building from source needs the .NET 6 SDK or newer.

No SDK? Open the [latest Release](https://github.com/KBT096/windows-secure-toolkit/releases), choose the Windows x64 archive, extract it, and run the entry point.

```cmd
build.cmd
win_secure.cmd self-test
win_secure.cmd audit
win_secure.cmd plan
win_secure.cmd doctor
win_secure.cmd apply
```

Run `apply` from an elevated CMD only after reading the plan. Restore example:

```cmd
win_secure.cmd restore "C:\ProgramData\WindowsSecureToolkit\Backups\20260818-120000"
```

## Commands

| Command | Description |
| --- | --- |
| `win_secure.cmd` | Open the menu |
| `win_secure.cmd audit [path]` | Write Markdown + JSON reports |
| `win_secure.cmd plan` | Preview only |
| `win_secure.cmd apply [--yes]` | Back up and apply the baseline |
| `win_secure.cmd restore <path>` | Validate and restore a backup |
| `win_secure.cmd backups [path] [--json]` | List backups and manifest status without changes |
| `win_secure.cmd scan` | Defender quick scan |
| `win_secure.cmd verify` | DISM/SFC read-only verification |
| `win_secure.cmd ports` | Show TCP listeners |
| `win_secure.cmd doctor [--json]` | Read-only compatibility and dependency checks |
| `win_secure.cmd update` | Check the latest Release |
| `win_secure.cmd version` | Print the version |
| `win_secure.cmd self-test` | Run the no-change self-test |

## Layout

- `src/WinSecure.cs` - core implementation;
- `src/WindowsSecureToolkit.csproj` - .NET Framework 4.8 project;
- `build.cmd` - build entry point;
- `win_secure.cmd` and `win_secure.bat` - user entry points;
- `scripts/Test-Repository.cmd` - build and smoke-test gate;
- `docs/THREAT_MODEL.md` - boundaries and threat model.
- `docs/WINDOWS_VALIDATION.md` - doctor command and Windows validation matrix.

## Copyright and component notice

The code in this repository is released under the [MIT License](LICENSE). The build targets .NET Framework 4.8 and the runtime uses Windows components such as `netsh`, `dism`, `sfc`, `netstat`, WMI, and Microsoft Defender; their licensing and use remain subject to the applicable Microsoft Windows terms. CI uses GitHub Actions with a pinned `actions/checkout` revision for repository validation only. This repository does not bundle YABS, NextTrace, or other VPS probe components.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). Ordinary questions belong in [Issues](https://github.com/KBT096/windows-secure-toolkit/issues).

Maintained by [@KBT096](https://github.com/KBT096). Released under the [MIT License](LICENSE).
