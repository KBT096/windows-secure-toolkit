# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
| Earlier or untagged copies | No |

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository:

1. Open the repository's **Security** tab.
2. Select **Advisories**.
3. Choose **Report a vulnerability**.

Do not open a public issue for a vulnerability that could expose a system, bypass a confirmation or backup boundary, execute untrusted content, or reveal local data.

Include:

- affected version or commit;
- Windows edition and build;
- whether the process was elevated;
- the smallest safe reproduction;
- expected and observed behavior;
- impact and any proposed mitigation.

Remove usernames, tokens, public IP addresses, organization names, audit reports, and other identifiers. The maintainer will acknowledge a complete report when it is reviewed, coordinate a fix and disclosure where appropriate, and credit reporters who request attribution.

## Scope priorities

Security-sensitive defects include:

- command or argument injection;
- execution of remote or untrusted content;
- backup or restore integrity bypass;
- unexpected elevation or system mutation;
- secret or local-data disclosure;
- misleading success output after a failed security change.

Hardening preferences and compatibility disagreements without a security impact can be filed as ordinary issues.
