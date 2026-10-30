# AI settings S1 operator guide

S1 implements the [accepted contract](../../design/ai-settings-s1.md) using
**synthetic temporary profiles only**. It does not yet back up a real machine.
Requires PowerShell 7 and Node.js 22.18 or later. The TypeScript engine runs
directly in Node, with no build step. Install its locked dependencies once from
the repository root (also repeat after a lockfile change):

```powershell
npm ci --prefix setup-llm --ignore-scripts
```

The runtime dependencies are `@ltd/j-toml` (full TOML 1.0 validation) and
`lossless-json` (duplicate detection and preservation of unowned number precision).
The Windows-only permission adapter uses the entry point's PowerShell host to
apply .NET access rules before staging file contents.

From the repository root, create a new sandbox and synthetic data:

```powershell
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-settings-demo-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$fixtureRoot/claude", "$fixtureRoot/codex" | Out-Null
[IO.File]::WriteAllText("$fixtureRoot/claude/settings.json", '{"model":"opus","spinnerTipsEnabled":false}')
[IO.File]::WriteAllText("$fixtureRoot/codex/config.toml", 'model = "fixture-model"')

./setup-llm/scripts/Manage-AISettings.ps1 capture -SandboxRoot $fixtureRoot -AsJson
./setup-llm/scripts/Manage-AISettings.ps1 status -SandboxRoot $fixtureRoot -AsJson
[IO.File]::WriteAllText("$fixtureRoot/codex/config.toml", 'model = "changed"')
./setup-llm/scripts/Manage-AISettings.ps1 restore -SandboxRoot $fixtureRoot -WhatIf -Force -AsJson
./setup-llm/scripts/Manage-AISettings.ps1 restore -SandboxRoot $fixtureRoot -Force -AsJson
```

The demo uses Force because this repository is often operated from Codex itself;
it bypasses the process observation only for these synthetic profiles. The
command cannot accept a profile outside the explicit sandbox. Do not copy real
settings into a sandbox to bypass the current scope. No changes to live profiles,
chezmoi, schedules, encryption keys or installed skills are part of this slice.

Capture creates `repo/preferences.json` under the sandbox, modeling a future
working-tree destination. Repeating capture or restore with no changes preserves
file bytes and mtimes. `status` is read-only. All commands return success as 0;
`-FailOnAttention` changes successful attention results to 2. Other failures are 1.
`-WhatIf` works for restore only and creates no directories or backups.

Override fixture paths with `-ClaudeHome`, `-CodexHome`, `-DataPath`, `-BackupRoot`.
All remain below SandboxRoot; linked paths and overlaps are rejected. Profiles
must already exist. `-NodePath` selects a compatible Node executable. The bundled
manifest is the default; `-ManifestPath` supports fixture manifests. A changed
manifest requires a fresh complete capture, not editing version numbers by hand.

`items` identifies owned fields, ignored boundaries, drift and per-file write or
rollback outcomes. `attention` reports unknown fields by ordinal within the
target, avoiding publication of potentially secret key names. Inspect the local
synthetic file to investigate. Values and source lines never appear in reports.
`coverage.notInspected` makes later scopes explicit. Attention is not a capture of
those settings. Strings that pass validation can still be private; publication
requires review even after canary tests pass.

Private backups contain the entire original file. They are under a separate,
user-only `private-backups` directory, outside the simulated repo. Five completed
runs are retained; failed/conflicted runs remain until explicit investigation.
A rollback-conflict preserves external bytes. Consult the contract before any
future real use: check/replace and rollback have a documented race window.
Restore and rollback preserve the target's Windows access rules and inheritance
protection, or Unix permission bits. On Windows, replacement content is staged
only after access-rule setup succeeds. Fingerprint reads retry transient access failures up
to three attempts, including checks between target writes.

## Verification

```powershell
npm run typecheck --prefix setup-llm
npm test --prefix setup-llm
Import-Module Pester -RequiredVersion 5.5.0
Invoke-Pester setup-llm/ai-cluster/tests/ai-settings.Tests.ps1 -Output Detailed
Invoke-ScriptAnalyzer setup-llm/scripts/Manage-AISettings.ps1 -Severity Warning,Error
Invoke-ScriptAnalyzer setup-llm/scripts/Set-AISettingsPermissions.ps1 -Severity Warning,Error
```

The TypeScript suite uses `node:test` and generated temporary profiles.
Pester launches the actual PowerShell wrapper in a separate process. No tests
read the live Claude, Codex or chezmoi settings. The no-outside-read test guards
profile reads; hostile app-home environment variables have no effect.
CI uses the existing shared pwsh workflow plus a Windows/Linux/macOS engine
matrix on Node 22.18 and 24. Windows additionally exercises an actual exclusive
file handle, not only injected exceptions.

| Brief criterion | Verification |
| --- | --- |
| S1.1 | First/second capture changed state, exit 0, only data file created |
| S1.2 | Exactly three unclassified leaves, fail-on-attention 2, ignored boundary, token preference exemption |
| S1.3 | WhatIf tree and mtime equality, security flags, no backup directory |
| S1.4 | Case-distinct unowned JSON values, preserved TOML statements and CRLF |
| S1.5 | Fake headers in multiline strings/arrays, quoted and escaped keys, missing insertion, nested model, refused forms |
| S1.6 | Second restore identical full tree and mtimes |
| S1.7 | Three deterministic conflicts, successful rebase, bounded read/stat access retries, explicit demonstration of undetectable rename race |
| S1.8 | Injected failure, real Windows lock, rollback, external-write conflict, rollback I/O failure, retained backups, Windows ACL preservation and empty staging on ACL failure |
| S1.9 | Malformed second target preflight, missing source/destination, invalid owned input and complete snapshot validation |
| S1.10 | Canary values in env/MCP headers/unknown values/uninspected files/invalid owned values; zero runtime output and simulated-repo hits |
| S1.11 | Sandbox enforcement and guarded profile reads; no live settings accessed |
| S1.12 | Capture leaves a fixture Git index and branch refs unchanged |
| S1.13 | Running-Codex stub refusal and Force override; actual live process/profile experiment deferred by user restriction |
| S1.14 | Manifest counts: 24 owned, 18 ignored, two root spaces; twelve invalid-manifest cases |
| S1.15 | Shared pwsh CI plus pinned-Node cross-platform matrix and TypeScript checks |
| S1.16 | Explicit unset round trip, invalid null/absence/missing file/incomplete snapshot distinction |
| S1.17 | Explicit uninspected scope and local-working-tree versus independent recovery documentation |

Encryption and recovery rehearsal, Desktop/ChatGPT, authored text and skills
inventory remain later work. O1–O3 remain open. The repo-local
`skills/ai-settings/SKILL.md` is a thin wrapper; it is not installed into any app.
