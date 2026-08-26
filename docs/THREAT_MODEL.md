# Threat Model

## Purpose

This document describes what Windows Secure Toolkit reads, what it can change, and where it stops.

## Assets

- local Windows security configuration;
- administrator intent and confirmation;
- backup manifests and firewall exports;
- audit reports that may describe system state;
- integrity of the local toolkit files.

## Trust boundaries

1. **User to launcher**: command names and paths cross from CMD into a fixed C# command map.
2. **Standard to elevated process**: audit and preview are separated from privileged mutation.
3. **Toolkit to Windows**: changes use local registry APIs, WMI providers, and documented Windows executables.
4. **Local machine to GitHub**: update checks read release metadata only.
5. **Backup to restore**: a manifest and SHA-256 file protect against accidental modification.

## Primary threats and controls

### Command injection

Controls:

- the launcher exposes a fixed command map;
- user paths are quoted before they reach a native process;
- the core does not evaluate source text as code;
- CI rejects old script engines and common remote-execution patterns.

Residual risk:

- a local administrator can replace the toolkit or its dependencies;
- Windows command behavior can vary by version, locale, and policy.

### Unexpected privileged changes

Controls:

- read-only audit is the recommended first action;
- preview mode does not require elevation;
- Apply and Restore require an elevated token and explicit confirmation;
- the baseline does not enable RDP, open inbound ports, create users, or reboot;
- each change is reported as applied, skipped, or failed.

Residual risk:

- a confirmed firewall, SMBv1, UAC, Defender, NLA, or AutoRun change can affect legacy workflows;
- Group Policy or security software can reject or later overwrite a local change.

### Failed or incomplete recovery

Controls:

- original managed values are captured before mutation;
- the manifest is hashed with SHA-256;
- Restore requires the originating computer name and validates fixed firewall, Guest SID, Defender, SMBv1, and registry allowlists;
- Restore reports each subsystem independently;
- backups are retained after Restore.

Residual risk:

- SHA-256 detects accidental or unsophisticated modification; it is not a digital signature;
- hardware failure, operating-system corruption, policy enforcement, or unmanaged manual changes can prevent full recovery;
- this is not a replacement for system images, recovery keys, or disaster-recovery tests.

### Remote supply-chain execution

Controls:

- no remote script is piped into CMD;
- update checks read GitHub Release metadata and display the release URL;
- releases are traceable to Git tags and commits.

Residual risk:

- users still need to verify the repository, account, and downloaded archive;
- release archives are not currently Authenticode-signed; SHA-256 and Git tag traceability do not establish publisher trust.

### Sensitive-data disclosure

Controls:

- audits stay local and are not uploaded;
- reports avoid credential material;
- issue templates and documentation require sanitization.

Residual risk:

- reports can reveal security posture, account names, process names, and system version if shared;
- JSON and Markdown reports should be treated as operationally sensitive data.

## Out of scope

- penetration testing, malware-removal guarantees, incident response, or compliance certification;
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
