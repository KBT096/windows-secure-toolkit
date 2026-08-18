# Contributing

Small, real improvements are welcome: Windows compatibility reports, bug fixes, clearer output, safer backups, and documentation corrections.

## Before opening a change

1. Search existing Issues and pull requests.
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

- dynamic command execution from user-controlled text;
- remote download-and-execute pipelines;
- URL shorteners or mutable third-party script endpoints;
- hidden telemetry or report uploads;
- automatic port opening, RDP enablement, administrator creation, or reboot;
- claims that static checks equal runtime validation on every Windows edition.

## Files and validation

- `.cmd/.bat`: UTF-8 without BOM, CRLF;
- `.cs/.csproj`: UTF-8, LF;
- public commands must continue to work through `cmd.exe /d`;
- keep the .NET Framework 4.8 target unless a deliberate version change is documented.

Run the repository gate before opening a pull request:

```cmd
scripts\Test-Repository.cmd
```

For system-changing code, provide a reversible runtime test on the affected Windows edition or state explicitly why it remains unverified.

## Pull requests

Keep each pull request focused. Complete the safety checklist, update the changelog when behavior changes, and preserve the exit-code contract:

- `0`: success;
- `1`: unexpected top-level failure;
- `2`: invalid launcher use or missing privilege;
- `4`: partial operation failure;
- `5`: user canceled.
