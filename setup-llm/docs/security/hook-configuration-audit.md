# Read-only hook configuration audit

This opt-in audit inventories a bounded subset of command-hook registrations in
operator-selected files. It reports identical supported registrations within and
across those files, with source/group/hook coordinates for local review. It never
runs a hook, shell, package manager or network request, installs dependencies,
rewrites configuration, discovers plugins or scans a user profile.

## Run

Use PowerShell 7.4 or newer. Select files for **one host per invocation**; the host
argument describes your intended interpretation, not detected host installation.

```powershell
./setup-llm/scripts/Test-HookConfiguration.ps1 -HostKind Claude -LiteralPath ./settings.json -AsJson
./setup-llm/scripts/Test-HookConfiguration.ps1 -HostKind Codex -LiteralPath ./hooks.json

# In PowerShell, compare explicitly selected sources together:
$sources = @('./settings.json', './settings.local.json')
./setup-llm/scripts/Test-HookConfiguration.ps1 -HostKind Claude -LiteralPath $sources -AsJson
```

Files must be local UTF-8 `.json` or `.jsonc`, optionally with one UTF-8 BOM.
JSONC permits comments and trailing commas; JSON does not. Duplicate JSON keys,
invalid UTF-8 and excessive nesting reject the file. URLs, UNC paths, network
drives on Windows, links/reparse points (including parent directories), directories
and other formats are unsupported. The implementation bounds input to 64 paths,
2 MiB per file, JSON depth 64, 64 event keys, 256 groups per event, 256 handlers
per group and 4096 encountered handlers per invocation. Strings are bounded to
8192 characters; argument vectors to 256 elements. Unsupported shapes do not
establish absence of hooks. Native Codex TOML and managed requirements are outside
this pilot.

## Supported subset

See the [CLI](https://github.com/The-Running-Dev/SubZeroDev.Workspace/blob/main/setup-llm/scripts/Test-HookConfiguration.ps1) and
[classifier](https://github.com/The-Running-Dev/SubZeroDev.Workspace/blob/main/setup-llm/scripts/modules/HookConfigurationAudit.psm1) for the parameter
and report definitions and the exact event allowlists. The subset intentionally
does not claim complete validation of either host's settings schema.

Both inputs require an object containing a `hooks` object mapping known events to
arrays of matcher groups. Each group has a `hooks` array and optional string
`matcher`. Empty containers are supported; absent/null containers are unverified.
Matcher strings are data: no regex compilation, environment expansion or matching.

Supported handlers have `type: "command"`, a nonblank string `command`, optional
nonnegative finite numeric `timeout`, boolean `async` and string `statusMessage`.
Claude additionally accepts string-array `args`. Codex requires integer timeouts
and additionally accepts `commandWindows` and nonnegative integer
`additionalContextLimit`. Optional fields must have the stated type; null is not
an omitted value. The Codex snake-case override alias is outside this subset.
Unknown fields, events and handler types, including HTTP, prompt, agent and MCP
tool handlers, remain unverified. Conditional `if`, `once`, `shell` and
`asyncRewake` fields are outside this pilot, even when supported by a host.

For Claude settings, unrelated root settings are outside scope and ignored;
`disableAllHooks`, if present, must be boolean and is reported as configuration
metadata. For Codex hook files, only `hooks` and optional string `description` are
accepted at the root. The description is never projected. Global host features,
inline TOML, plugin sources, trust approvals, managed policies and override rules
are not resolved. A supported registration can still be disabled, unloaded,
invalid for an event at runtime or unsupported by an installed host version.

## Duplicate meaning and output

The report uses schema version 1 and `execution: "not-evaluated"`. `supported`
means the selected data fits this reader's subset. `unverified` means at least
one input, group, event or handler could not be inspected under that subset.
Supported siblings of unsupported events/groups/handlers are retained, but the
configuration and aggregate remain unverified. Parser/container failures and
registration-limit failures discard that file's registrations and comparisons.
Do not treat a supported subset as a complete host configuration audit.

Equality includes the event, matcher value **and presence**, command, argument
order and all supported handler fields **and their presence**. Object key order
does not matter. String comparison is ordinal and case sensitive; whitespace,
path syntax, shell quoting, environment references and defaults are never
normalized. Different defaults or spellings may therefore hide a runtime
equivalence. Only supported handlers in supported groups/events participate.
Global disabling does not remove registrations from this presence inventory.

`identical-registration-present` means only that the same supported registration
is present at multiple coordinates. It does **not** prove both files are loaded,
that a matcher fires, or that a hook executes twice. Repeated canonical path
spellings are rejected to avoid counting the same selected file twice. Hard links
and file replacement races are not resolved; select distinct stable snapshots.

Output exposes input ordinals, known events, group/hook indices and bounded numeric
or boolean metadata. Commands, arguments, matchers, source paths, status messages,
Windows overrides, descriptions and exception text are never projected. Duplicate
groups receive invocation-local sequential IDs, not hashes of secret-bearing
content. Keep the ordered input list locally to map ordinals back to files.
Output is deterministic for unchanged input bytes, input order and host selection.

Exit codes:

- `0`: all selected content supported, no identical registrations found.
- `1`: at least one unverified input/registration or identical registration group.
- `2`: missing/invalid host, missing paths or more than 64 selected paths.

Exit zero is not a trust, security, execution, latency or permission verdict.
Review original files locally before deciding whether a registration is redundant.
The human and JSON reports carry the same interpretation; JSON includes metadata
and member coordinates for automation.

## Ownership and evidence

Workspace owns this optional static provisioning/configuration check. AgentKit
owns its installer validation and engineering workflow. SkyNetHR owns event
replay, runtime hook observability, auditing and permission policies. This audit
does not assemble context or orchestrate agents and is not wired into setup or
doctor commands automatically.

The subset was checked against the [Claude hook reference](https://code.claude.com/docs/en/hooks)
on 2026-10-28 and the pinned Codex
[handler schema](https://github.com/openai/codex/blob/78a3185ecba7ca3422f14589aeac97059649f60f/codex-rs/protocol/src/hooks.rs)
and [file container](https://github.com/openai/codex/blob/78a3185ecba7ca3422f14589aeac97059649f60f/codex-rs/config/src/hook_config.rs).
Host behavior can change independently of this reader. The mechanism was informed
by ECC's [surface audit](https://github.com/affaan-m/ECC/blob/25278e7d7b6cf6e6a4e7a6c8e10f14ff22f0eb5b/skills/workspace-surface-audit/SKILL.md)
and duplicate-hook concern. This is an original PowerShell implementation with no
ECC code or dependency installed.

Regression tests exercise positive inventory, strict types, unsupported inputs,
duplicate equality, redaction, deterministic ordering, CLI exits, process/network
canaries and unchanged input hashes. CI runs the focused suite on Windows, Ubuntu
and macOS. It does not execute candidate hooks or measure runtime overhead.
