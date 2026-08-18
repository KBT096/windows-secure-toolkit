# Windows Security & Management Toolkit

[![CI](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/KBT096/windows-secure-toolkit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Windows PowerShell 5.1](https://img.shields.io/badge/Windows%20PowerShell-5.1%2B-5391FE.svg)](https://learn.microsoft.com/powershell/)

Windows Security & Management Toolkit provides local security auditing, conservative hardening, configuration backup, and restoration for Windows 10/11 and Windows Server. `win_secure.cmd` and `win_secure.bat` are the user-facing entry points; no third-party runtime is required.

Read-only checks are the default. Elevated changes show their scope, ask for confirmation, and create a verifiable backup first. The toolkit does not download and immediately execute remote code, and it never restarts the computer automatically.

## Main capabilities

### Read-only security audit

- Reviews Windows Firewall, Microsoft Defender, UAC, SMBv1, Guest, RDP/NLA, BitLocker, Secure Boot, and Windows Update.
- Summarizes local administrators, common pending-reboot markers, and TCP listeners.
- Produces both Markdown and JSON for human review and follow-up automation.
- Does not present a local snapshot as a penetration test, compliance certificate, or universal security score.

### Reversible baseline

- Enables all Windows Firewall profiles.
- Enables Defender real-time and potentially unwanted application protection.
- Places Defender Network Protection in audit mode on Windows clients; Windows Server is left unchanged for role-specific review.
- Enables UAC with secure-desktop prompts.
- Disables SMBv1, Guest, and AutoRun.
- Requires Network Level Authentication only when RDP is already enabled.
- Saves a JSON manifest, SHA-256 checksum, and complete firewall policy export before changes.

### Maintenance diagnostics

- Starts a Microsoft Defender quick scan.
- Runs read-only `DISM /ScanHealth` and `SFC /verifyonly` checks.
- Lists listening TCP addresses, ports, process IDs, and process names.
- Checks GitHub Release metadata without replacing the local script.

## Safety boundaries

The toolkit does not:

- bypass Group Policy, MDM, tamper protection, or endpoint management;
- open inbound ports, enable RDP, or create administrator accounts;
- automatically repair findings from DISM or SFC;
- upload audit results or local identifiers;
- execute content obtained from dynamic script URLs or URL shorteners;
- claim that one baseline is appropriate for every environment.

The CMD launcher sets `ExecutionPolicy Bypass` only for its child PowerShell process. It does not write CurrentUser or LocalMachine policy, and MachinePolicy/UserPolicy set through Group Policy retain higher precedence.

See the [threat model](docs/THREAT_MODEL.md) for the full scope.

## Requirements

- Windows 10/11 or Windows Server 2019/2022/2025;
- Windows PowerShell 5.1 or later;
- standard privileges for most audits;
- administrator privileges for hardening, restoration, Defender scans, and system verification.

Managed devices should be reviewed with the responsible administrator before any local policy change.

Initial verification scope:

| Environment | Verified | Not verified |
| --- | --- | --- |
| Windows 11 Pro for Workstations build 26200 with Windows PowerShell 5.1 | CMD/BAT launch, parsing, self-test, audit reports, listeners, and baseline preview | Applying and restoring the baseline |
| GitHub Actions `windows-latest` | Public CI after the first push | Elevated configuration changes |
| Windows 10 and Windows Server 2019/2022/2025 | Target compatibility environments | No first-release mutation evidence yet |

Unverified behavior is not described as runtime-tested in release notes.

## Quick start

Download a versioned archive from [Releases](https://github.com/KBT096/windows-secure-toolkit/releases), or clone the repository:

```powershell
git clone https://github.com/KBT096/windows-secure-toolkit.git
cd windows-secure-toolkit
```

Start with a read-only audit:

```cmd
win_secure.cmd audit
```

Preview the baseline:

```cmd
win_secure.cmd plan
```

After compatibility review, open an elevated CMD or PowerShell window:

```cmd
win_secure.cmd apply
```

Backups are stored under `%ProgramData%\WindowsSecureToolkit\Backups`. Restore accepts only a same-computer manifest with a matching SHA-256 checksum and allowlisted fields. Reports are stored under `%LOCALAPPDATA%\WindowsSecureToolkit\Reports`.

## Commands

| Command | Privilege | Behavior |
| --- | --- | --- |
| `win_secure.cmd` | Standard | Opens the interactive menu |
| `win_secure.cmd audit [path]` | Standard | Writes Markdown and JSON reports |
| `win_secure.cmd plan` | Standard | Previews the baseline without changes |
| `win_secure.cmd apply` | Administrator | Backs up and applies the baseline |
| `win_secure.cmd restore "path"` | Administrator | Verifies and restores managed settings |
| `win_secure.cmd scan` | Administrator | Runs a Defender quick scan |
| `win_secure.cmd verify` | Administrator | Runs read-only DISM and SFC checks |
| `win_secure.cmd ports` | Standard | Lists TCP listeners |
| `win_secure.cmd update` | Standard | Reads the latest GitHub Release metadata |
| `win_secure.cmd self-test` | Standard | Runs non-mutating self-tests |

## Validation

Run the same repository checks used by CI:

```powershell
.\scripts\Test-Repository.ps1
```

The suite covers PowerShell parsing, Windows PowerShell 5.1 execution, the CMD launcher, batch encoding and line endings, audit report generation, required files, and remote-execution anti-patterns. Static validation is not a substitute for runtime testing on each supported Windows edition.

## Contributing and security

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes.
- Use [GitHub Issues](https://github.com/KBT096/windows-secure-toolkit/issues) for ordinary defects and requests.
- Follow [SECURITY.md](SECURITY.md) for private vulnerability reports.
- Maintained by [@KBT096](https://github.com/KBT096).

## License

Released under the [MIT License](LICENSE). Windows, Microsoft Defender, and PowerShell are product or trademark names of their respective owners. This project is not affiliated with or endorsed by Microsoft.
