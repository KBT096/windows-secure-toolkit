# Windows Secure Toolkit

[![CI](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![C%23](https://img.shields.io/badge/C%23-.NET%20Framework%204.8-512BD4.svg)](https://dotnet.microsoft.com/)

Windows security settings are a bit like the fuse box: nobody wants to stare at it all day, but a small record is useful when something goes wrong.

Current version: `1.2.0`.

This is a small local toolkit with a CMD/BAT entry point and a C# engine. It checks, previews, backs up, and restores a conservative set of settings. It does not promise a magic “secure” button. Sadly, those are still out of stock.

## What it does

- read-only checks for firewall, Defender, UAC, SMBv1, Guest, RDP/NLA, AutoRun, updates, and pending reboot;
- Markdown and JSON audit reports;
- a preview-first baseline with explicit elevation and confirmation;
- a SHA-256 checked manifest and firewall backup before changes;
- same-machine, allowlisted restore;
- Defender quick scan, DISM/SFC verification, and TCP listener listing;
- GitHub Release metadata checks only. It does not download and run remote code.

## What it does not do

- open inbound ports, enable RDP, or create administrator accounts;
- reboot the computer or automatically repair DISM/SFC findings;
- upload reports, usernames, IP addresses, or other local data;
- bypass organization policy or endpoint management;
- turn static checks into claims about every Windows edition.

## Quick start

The target is Windows 10/11 and Windows Server 2019/2022/2025. A compiled build needs .NET Framework 4.8; building from source needs the .NET 6 SDK or newer.

No SDK? Grab `windows-secure-toolkit-v1.2.0-win-x64.zip` from the [v1.2.0 Release](https://github.com/KBT096/windows-secure-toolkit/releases/tag/v1.2.0), extract it, and run the entry point.

```cmd
build.cmd
win_secure.cmd self-test
win_secure.cmd audit
win_secure.cmd plan
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
| `win_secure.cmd scan` | Defender quick scan |
| `win_secure.cmd verify` | DISM/SFC read-only verification |
| `win_secure.cmd ports` | Show TCP listeners |
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

## Verification note

Windows 11 Pro for Workstations build 26200 has been used for build, launch, version, self-test, audit, plan, reports, listener listing, and Release checks. Public GitHub Actions also builds and runs the smoke tests on Windows.

System-changing Apply/Restore has not been run on the maintainer machine. The release notes say so plainly. Read the plan, keep the backup, and do not expect Windows to clap when you click the button.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). Ordinary questions belong in [Issues](https://github.com/KBT096/windows-secure-toolkit/issues).

Maintained by [@KBT096](https://github.com/KBT096). Released under the [MIT License](LICENSE).
