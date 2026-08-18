# Contributing

Focused bug fixes, Windows compatibility evidence, documentation corrections, and reversible security improvements are welcome.

## Before opening a change

1. Search existing issues and pull requests.
2. State the Windows edition, build, privilege level, and management context.
3. Explain the user problem and compatibility impact.
4. Remove secrets, public IP addresses, usernames, organization names, and raw audit reports.

## Change requirements

Any new system mutation must include:

- a read-only way to detect the current state;
- a clear preview and impact description;
- explicit elevation and confirmation boundaries;
- capture of the original value before mutation;
- a tested restore path;
- truthful success, skip, and failure reporting;
- documentation of restart and policy-management behavior.

Do not add:

- `Invoke-Expression` or equivalent dynamic execution;
- remote download-and-execute pipelines;
- URL shorteners or mutable third-party script endpoints;
- hidden telemetry or report uploads;
- automatic port opening, RDP enablement, administrator creation, or reboot;
- claims that static checks equal real Windows runtime validation.

## Encoding and compatibility

- `.cmd/.bat`: UTF-8 without BOM, CRLF.
- `.ps1/.psm1/.psd1`: UTF-8 with BOM, CRLF for Windows PowerShell 5.1.
- Public commands must continue to work through `cmd.exe /d`.
- Avoid PowerShell 7-only syntax unless the minimum version is deliberately changed in a major release.

## Validation

Run:

```powershell
.\scripts\Test-Repository.ps1
```

For system-changing code, also provide a reversible runtime test on the affected Windows edition or state explicitly why it remains unverified.

## Pull requests

Keep each pull request focused. Complete the safety checklist, update the changelog when behavior changes, and preserve the exit-code contract:

- `0`: success;
- `1`: unexpected top-level failure;
- `2`: invalid launcher use;
- `4`: partial operation failure;
- `5`: user canceled.
