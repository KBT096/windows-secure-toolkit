# Threat Model

## Purpose

This document defines what Windows Security & Management Toolkit protects, what it changes, and what remains outside its scope.

## Assets

- Local Windows security configuration;
- administrator intent and confirmation;
- backup manifests and firewall exports;
- audit reports that may describe system state;
- integrity of the local toolkit files.

## Trust boundaries

1. **User to launcher**: command names and paths cross from CMD into PowerShell.
2. **Standard to elevated process**: audit and preview are separated from privileged mutation.
3. **Toolkit to Windows subsystems**: changes pass through documented local commands and registry providers.
4. **Local machine to GitHub**: update checks read release metadata only.
5. **Backup to restore**: a manifest and SHA-256 file protect against accidental modification.

## Primary threats and controls

### Command injection

Control:

- The CMD launcher exposes a fixed command map.
- Restore paths are passed as PowerShell file arguments.
- The core does not use dynamic expression evaluation.
- CI rejects common dynamic and remote pipeline execution patterns.

Residual risk:

- A local administrator can replace the toolkit or its dependencies.
- Operating-system command behavior can vary by Windows version and policy.

### Unexpected privileged changes

Control:

- Read-only audit is the recommended first action.
- Preview mode does not require elevation.
- Apply and restore require an elevated token and explicit confirmation.
- The baseline does not enable RDP, open inbound ports, create users, or reboot.
- The launcher changes execution policy only for its child process; it does not persist a policy and cannot override Group Policy MachinePolicy/UserPolicy.

Residual risk:

- A confirmed firewall, SMBv1, UAC, Defender, NLA, or AutoRun change can affect legacy workflows.
- Group Policy or security software can reject or later overwrite a local change.

### Failed or incomplete recovery

Control:

- Original managed values are captured before mutation.
- The manifest is hashed with SHA-256.
- Restore requires the originating computer name and validates fixed firewall, Guest SID, Defender, SMBv1, and registry allowlists.
- Restore reports each subsystem independently.
- Backups are retained after restore.

Residual risk:

- SHA-256 detects accidental or unsophisticated modification; it is not a digital signature.
- Hardware failure, operating-system corruption, policy enforcement, or manual changes outside the managed set can prevent full recovery.
- The tool is not a replacement for system images, BitLocker recovery keys, or tested disaster recovery.

### Remote supply-chain execution

Control:

- No remote script is piped to CMD or PowerShell.
- Update checks read GitHub Release metadata and display the release URL.
- Releases are traceable to Git tags and commits.

Residual risk:

- Users still need to verify the repository, GitHub account, and downloaded archive.
- The project does not currently publish signed release artifacts.

### Sensitive-data disclosure

Control:

- Audits are local and are not uploaded.
- Reports avoid collecting API keys or credential material.
- Issue templates and documentation require sanitization.

Residual risk:

- Reports can reveal security posture, account names, process names, and system version if users share them.
- JSON and Markdown reports should be treated as sensitive operational data.

## Out of scope

- Penetration testing, malware removal guarantees, incident response, or compliance certification;
- bypassing authorization, endpoint controls, Group Policy, or tamper protection;
- scanning third-party systems or repositories;
- domain-wide or cloud policy management;
- firmware configuration and physical security;
- universal hardening for every application and organization.

## Security invariants

Changes must preserve all of the following:

1. Audit and preview do not modify managed security settings.
2. Privileged changes require elevation and confirmation.
3. Every newly managed setting has backup and restore coverage.
4. Remote content is not executed.
5. Failures are reported as failures.
6. No automatic reboot occurs.
