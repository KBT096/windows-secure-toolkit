## Summary

Describe the user-visible change and why it is needed.

## Safety and compatibility

- [ ] Read-only behavior remains the default.
- [ ] Elevated changes are explicit and confirmed.
- [ ] Every changed setting is captured by backup and restore.
- [ ] No remote content is downloaded and executed.
- [ ] The .NET Framework 4.8 target and CMD/BAT entry points remain usable.
- [ ] Chinese `.cmd/.bat` files remain UTF-8 without BOM + CRLF.

## Verification

- [ ] `scripts\Test-Repository.cmd`
- [ ] Tested on the stated Windows edition/build, or documented why runtime testing was not possible.
- [ ] Logs and screenshots contain no secrets or personal data.
