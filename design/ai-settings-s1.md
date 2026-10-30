# AI settings preservation — accepted S1

Ben changes Claude Code and Codex preferences frequently and wants a repeatable
capture/restore command for reinstall recovery. The reviewed source brief is
`D:\Dropbox\Notes\SubZeroDev.Workspace\2026-10-30-ai-settings-review-brief.md`,
revision 3. On 2026-10-30 Ben accepted the proposed S1 defaults and requested
implementation using temporary profiles and fixtures only.

## Scope and execution

PowerShell 7 entry point: `setup-llm/scripts/Manage-AISettings.ps1`.
Python 3.11–3.14 is required; no pip packages. The sidecar also enforces the sandbox.

Commands: `capture`, `status`, `restore [-WhatIf] [-Force]`.
All require `-SandboxRoot`: an existing child directory of the OS temp directory.
Defaults below it are `claude/settings.json`, `codex/config.toml`,
`repo/preferences.json`, and `private-backups/`.
`-ClaudeHome`, `-CodexHome`, `-DataPath`, and `-BackupRoot` override these
locations only within that sandbox. Reparse points, linked paths and overlaps are
refused. Backups must be outside the preferences data directory.
Existing valid profile files are required. There is no HOME, CLAUDE_CONFIG_DIR or
CODEX_HOME fallback, no default chezmoi integration and no installation into apps.

`-AsJson` returns `changed`, `items`, `attention`, `manifestCounts` and
`coverage`. Success exits 0, including a changed result or attention. Failures
exit 1. `-FailOnAttention` exits 2 on an otherwise successful result with attention.
`restore -WhatIf` returns `wouldChange` and writes nothing, including no backups
or directories. `-Force` bypasses only the Codex process check, never the sandbox.
The PowerShell entry point checks process names; direct engine calls take this
observation as an explicit flag. The engine is a library/test adapter, not a live
profile entry point.

## Ownership and recovery promise

Version 1 of `ai-settings.manifest.json` inspects the JSON and TOML root key
spaces. Each owned leaf has a type, limits or accepted values, sensitivity review
and security-relevance flag. The validator rejects bad targets, tables, overlap,
malformed rules and unsupported inspection spaces and returns coverage counts.

Only reviewed owned preferences are captured. Each gets an explicit `set` with
validated value or `unset`; absence is recoverable, null is invalid for S1 types,
and an omitted snapshot entry is an error. Snapshots must match the complete
ordered owned path list and manifest version. Capture fails without replacing
previous data if any selected source is missing, unreadable, malformed or invalid.
Repeated identical capture does not rewrite the data. No timestamps in snapshots.
The command writes only that data file; it never stages, commits, pushes or logs.

Status classifies each owned path, ignored boundary and unknown leaf or empty
container. Ignored descendants are not inspected for classification or copied.
Unknowns get exactly one attention item: suspected-secret (name heuristic) or
unclassified. Reviewed numeric token preferences bypass the heuristic. Unknown
key names can themselves be secrets, so attention identifies them by target and
traversal ordinal, not raw names. Reports never include values, hashes, source
lines, parser diagnostics or arbitrary exception text. A missing snapshot is
attention; unavailable targets are reported individually by safe reason codes.
Status is an inventory of these two files, not proof that effective app settings
or every profile file have been preserved.

Explicitly uninspected: Claude Desktop, ChatGPT, authored text, skills, secrets,
and all other profile files. Encryption, secret bindings/pull, key recovery,
scheduling, live activation, installation and remote backup remain later slices.
Unknown preferences remain visible as attention. MCP configuration belongs to
its installers and is never captured.

Current documentation was checked before admitting candidates:
[Claude settings](https://code.claude.com/docs/en/settings-reference),
[Claude environment variables](https://code.claude.com/docs/en/env-vars),
[Codex config](https://learn.chatgpt.com/docs/config-file/config-reference).
The manifest is the exact owned list. `theme` is in Claude's separate global
configuration and is outside this file's scope. The proposed concurrent-subagent
and spawn-depth environment candidates lack a verified documented contract;
they remain unknown if present. Model effort and tier are bounded identifiers
because client/model support varies. Deprecated approval strings and granular
approval tables are refused; S1 supports the reviewed scalar forms only.
Valid strings can still contain personal text: public publication requires review.

## Restore and concurrency

Validate snapshot and every target, including proposed edits, before writing any
target. JSON preserves all unowned values semantically, including case-distinct
keys; formatting may change. TOML permits only existing single-line top-level
scalar assignments or insertion at the end of the root prelude. The lexical
scanner handles comments, escaped and quoted keys, multiline strings, arrays and
inline tables before the first actual table header. Owned dotted, table, inline,
duplicate and multiline forms are refused. Full TOML 1.0 parsing checks input and
output, and output must equal the entire intended object, preserving unowned
values. Bytes outside edited TOML lines remain unchanged, including CRLF.
UTF-8 without BOM is the supported encoding.

For each changed file, read length/mtime/SHA-256 fingerprint, replan on fresh
bytes, recheck before replacing and retry up to three attempts on a conflict or
sharing violation. Replacement uses a same-directory temporary file and atomic
rename. Re-read after writing; unexpected bytes report overwritten-after-write.
Fingerprints stay private in memory. Capture's per-file consistency is best
effort, not a simultaneous cross-app snapshot.

The final check and rename are **not compare-and-swap**. A competing write in
that gap can be lost without detection; tests demonstrate this limitation.
Close competing apps before later real-profile use. Restore refuses when Codex
is observed running unless forced. This check is tested with a stub; no live
app-closing or real-profile experiment is authorized in S1.

Private backups contain full original files and may contain secrets. Backup
directories grant access only to the current user (Windows ACL; Unix mode 0700).
They live outside the simulated repository. Keep the last five completed runs;
failed/conflicted runs are retained for explicit investigation, never auto-pruned.
On failure, roll back earlier writes only if the current fingerprint is still
the one this run wrote. Otherwise preserve external bytes and report
rollback-conflict; I/O failures report rollback-failed. The rollback check/rename
has the same race limitation. This is best-effort multi-file recovery, not a
transaction. `changed` records whether this invocation replaced any target,
even when it subsequently rolled back.

## Verification and later decisions

Synthetic profiles, deterministic writer/I/O injection, canary scans, parser
fixtures, wrapper Pester tests and CI cover S1.1–S1.17; see
`setup-llm/docs/ai-settings-s1.md` for the acceptance map and exact commands.
No real settings files or default chezmoi state are opened by tests.
Local capture in a working tree is not independent backup: later publication and
fresh-machine/key-recovery rehearsal are required to demonstrate reinstall recovery.

O1 (independent encryption key copy), O2 (public authored text), O3 (secret drift
vs automatic pull) remain undecided. S1 acceptance does not accept later defaults.
