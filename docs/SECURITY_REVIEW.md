# Security review: legacy script-risk regression gate

Review date: 2026-08-23  
Scope: the default `main` branch and the Windows source/entry-point files.

## Result

The current implementation does not contain the legacy patterns found in the reference project's old VPS entry script:

- no `curl | bash`, `wget`, or other remote script pipe;
- no `eval`, `Invoke-Expression`, or `certutil -decode` execution path;
- no `/etc/ssh/sshd_config` or `ssh_config` editing;
- no firewall rule creation that opens TCP 22, 80, or 443 by default.

The `apply` path enables Windows Firewall profiles and manages the documented local baseline. It does not create inbound rules, enable RDP, or choose public ports. The `update` path reads the fixed GitHub Release API URL and does not download or execute an archive.

## Regression control

`scripts\\Security-Gate.cmd` scans the executable C# source and CMD/BAT entry points for the rejected patterns. `scripts\\Test-Repository.cmd` runs the gate locally and in GitHub Actions, so a future change that reintroduces one of these patterns fails the repository validation job.

The scan intentionally excludes documentation, because this review and the threat model name rejected patterns as explanatory text. A passing static scan is evidence of source shape, not proof that every runtime configuration is safe.

## Remaining limits

- Apply and Restore system-changing paths remain unexecuted on the maintainer workstation;
- Windows Firewall, Group Policy, cloud security groups, and router rules are environment-specific;
- release archives are traceable to tags and SHA-256 digests but are not currently code-signed;
- this gate does not replace code review or an isolated virtual-machine test.
