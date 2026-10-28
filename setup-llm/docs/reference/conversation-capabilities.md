---
title: Conversation Capabilities
sidebar_position: 3
description: Read-only evidence for existing conversation, graph and memory adapters.
---

# Conversation capabilities

Run this opt-in report before choosing integrations for the portable conversation
workflow in [AgentKit #495](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/issues/495),
reviewed extraction in [#496](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/issues/496),
and host outbox in [#497](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/issues/497).
It inventories existing capabilities. The opt-in [selected conversation projection](./conversation-projection.md)
implements [Workspace #57](https://github.com/The-Running-Dev/SubZeroDev.Workspace/issues/57)
with the installed Graphify build API. Graphify is the selected context-graph tool;
see the [functional verification and local setup](./conversation-tools-verification.md).

## Run the report

PowerShell 7.4 or later is required for this optional report. From the repository root:

```powershell
./setup-llm/scripts/Report-ConversationCapabilities.ps1 -AsJson
./setup-llm/scripts/doctor-workstation.ps1 -Client Codex -ConversationCapabilities -AsJson
```

The standalone report exits `0` even when optional integrations are absent or unknown;
invocation failure exits `2` with a fixed error code. The doctor still exits `1` for
unhealthy required MCP profiles and `0` otherwise. Without the switch its JSON remains
the existing six-row-per-client array and it runs no new probes. With the switch JSON
is an object containing `profiles` and `conversationCapabilities`.

Additional standalone options are `-GraphifyPackagePath`, `-MemoryConfigPath`,
`-Namespace`, `-ExtensionsPath` and `-EvidencePath`. The doctor accepts
`-GraphifyPackagePath` and `-CapabilityEvidencePath`; use the standalone report to
select other paths/scopes. Reports are printed, never automatically persisted.

| Status | Meaning |
| --- | --- |
| `supported` | The stated probe or declaration succeeded; inspect its evidence and scope. |
| `unavailable` | A command/directory is absent, or an operator verified a host tool is absent. |
| `unconfigured` | A registration, configuration, namespace selection or extension declaration is absent. |
| `unknown` | Failed/unrecognized probe, missing evidence, or runtime access not verified. |

`supported` does not imply a successful graph build, activated extension, or authorized
host action. Each entry includes a fixed evidence code, safe details and a next step.
Only `graphify --version` and `codex mcp list --json` execute, with ten-second timeouts
per probe. Configuration commands, extension code and graph source are never executed.
Raw probe output, configuration values, namespace names, conversations and store contents
are excluded from the report. No setup, downloads, indexing, store opening or settings
changes occur. Review any report before sharing it; tool IDs and versions are operational
metadata. Personal sources and derived personal material remain in private Notes.

## Graphify and the live context graph

Use `uv tool dir` to locate the existing `graphifyy` environment, then identify its
`graphify` Python package (for example `Lib/site-packages/graphify` on Windows).
Pass that directory explicitly as `-GraphifyPackagePath`. The report does not install
Graphify or assume a package path from an installer. It records the CLI version and
SHA-256 hashes of supplied `detect.py` and `validate.py` when they declare:

- `.md` and `.txt` document inputs;
- extraction edges with `source`, `target`, `relation`, `confidence`, `source_file`;
- `extra_excludes` and `.gitignore` discovery mechanisms.

These are source declarations, not an end-to-end conversation adapter test. The caller
must verify that the supplied directory belongs to the CLI on PATH. An unrecognized
source/version remains `unknown`. In Graphify 0.9.91, tracked files bypass gitignore
discovery filtering: `.gitignore` alone is insufficient to protect private material.
Validate explicit exclusions and corpus boundaries before any future indexing operation.

Graphify owns the selected conversation graph through the existing #57 projection and
`graphify path` retrieval. No separate context-graph service is required. Installation
alone is not runtime evidence: default `context-graph.live` is `unknown` in this read-only
inventory. To record the selected owner manually,
add `contextGraph` to an evidence document with `status`, `live: true`, `owner`, and
`contractPath` pointing to the current owner's contract. Supported evidence requires a
readable hashed contract outside a `design/` directory. This is operator evidence; the
script cannot authenticate ownership or test that API. The report retains the hash and
an owner-identified boolean, not the owner/path. For Graphify, use this repository's
`conversation-projection.md` as the adapter contract and run the installed lifecycle
smoke separately. Do not resurrect the retired AgentKit design graph or create a database.

## MemoryKit, memory MCP and VS Code

MemoryKit configuration follows AgentKit's `AGENTKIT_MEMORYKIT_CONFIG` override, otherwise
`HOME` / `USERPROFILE` plus `.agent-kit-state/memorykit.json`. The report checks only the
configured CLI's presence, `memory.db` presence, capture/context flags and whether a
namespace was selected. It never executes that configured CLI. Existing MemoryKit
`status` and `namespace get` open the service, which can initialize history or SQLite
sidecars; they are deliberately excluded from this read-only report. Thus even a selected
namespace and present store remain `unknown` for actual access. Verify access separately
through the existing reviewed AgentKit memory workflow before extraction. No store is
enabled and no candidate is captured automatically.

Codex's memory MCP registration is a separate capability. An enabled server named
`memory` yields `registered-runtime-not-probed`, still `unknown` for functional access.
An empty list is `unconfigured`; CLI absence is `unavailable`; failure or unfamiliar JSON
is `unknown`. Other names are not guessed. Claude Code registrations remain part of the
baseline doctor; this report does not claim a Claude memory runtime probe.

VS Code inspection reads extension manifests in `~/.vscode/extensions` or the supplied
`-ExtensionsPath`. It reports exact publisher/name IDs, versions, hashes and contributed
command IDs whose ID or title mentions memory, plus extensions named for memory. Other
extension behavior may remain undiscoverable. Malformed manifests do not stop remaining
inventory. Manifest declarations stay `unknown` for functional use: they do not prove
activation, the active profile, remote extensions or command execution. For manual
verification, open the intended VS Code profile, inspect installed extensions and each
extension's contributed commands/documentation, then test an actual documented command
within the intended scope. Never invent a command ID based on a feature name.

## Manual host evidence

A shell cannot discover this chat's host tools. Inspect the active session contracts and
provide an operator evidence file instead. It expires after seven days and rejects
duplicate tools, unknown tool names, invalid states and future timestamps beyond five
minutes. Example (replace the date/version with observed values):

```json
{
  "schemaVersion": 1,
  "observedAt": "2026-10-27T14:50:00Z",
  "host": {
    "name": "codex",
    "version": "26.1021.3705.0",
    "tools": [
      { "name": "create_thread", "status": "supported", "verification": "contract" },
      { "name": "fork_thread", "status": "supported", "verification": "smoke" },
      { "name": "navigate_to_codex_page", "status": "supported", "verification": "smoke" },
      { "name": "read_thread", "status": "supported", "verification": "contract" }
    ]
  }
}
```

Allowed tool states are `supported`, `unavailable`, `unknown`; verification is `contract`
or `smoke`. Omitted tools remain `unknown`. `contract` records exposure only; `smoke`
records an authorized test. Evidence does not authorize creating or forking a chat.
Missing access remains unknown rather than an assumed implementation.

The `agentKitHost` field projects supported tool names into #497's existing
`{host, tools, evidence}` contract, with exact `mcp__codex_app__` names. Recheck active
session exposure before using it. It creates no host operation, memory write or graph.

## Adapter selection

| Operation | Existing adapter and evidence needed |
| --- | --- |
| Fork / attach / return | #495 portable package; available when every optional integration is absent. |
| Selected handoff | #497 `create_thread`, attributed selected prompt, explicit new-chat authorization. |
| Full-history fork | #497 `fork_thread`, explicit consent to the complete inherited history. No selective native clone. |
| Native return | #497 navigation to the saved parent. Portable attach retains the selected outcome; no automatic message or history rewrite. |
| Memory extraction | #496 reviewed selection using existing MemoryKit; verify store and namespace access separately. |
| Graph projection | #57 `Project-ConversationContext.ps1` and existing Graphify build/path tools; reviewed selection only. Verify its lifecycle separately. |

## Workstation verification, 2026-10-27

The [recorded report](https://github.com/The-Running-Dev/SubZeroDev.Workspace/blob/b17dd7bb45b86d8be8e615609a019a4eb282842c/setup-llm/docs/reference/evidence/conversation-capabilities-2026-10-27.json) was produced
by the standalone entry point on Windows with the installed Graphify package directory
and [operator host evidence](https://github.com/The-Running-Dev/SubZeroDev.Workspace/blob/b17dd7bb45b86d8be8e615609a019a4eb282842c/setup-llm/docs/reference/evidence/conversation-host-2026-10-27.json).
The evidence cites [AgentKit's authorized synthetic smoke test](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/blob/5c0dbca50da5d8fac05b1e9d8a957bd63717896a/docs/conversation-host-smoke.md):
create, full-history fork and parent navigation succeeded; test chats were archived.
Current tool contracts were also exposed. `read_thread` records contract exposure only.
Host version comes from installed Codex app metadata, not a tool API version.

Observed: Graphify 0.9.91 with the declarations above; no default MemoryKit configuration,
no Codex memory MCP registration, and no memory-related declaration in the inspected
local VS Code extension directory. No live context-graph owner/API was exposed to this
session. Namespace access and functional editor memory use were not probed. This is a
dated inventory, not a guarantee for another profile or future installation. The
[subsequent verification](./conversation-tools-verification.md) records the resolved
Graphify ownership and configured MemoryKit integration; it does not rewrite this snapshot.

Pester fixtures cover absent tools, failures, partial hosts, supported declarations,
invalid/stale evidence, subprocess failure/timeouts, secret redaction, store immutability
and unchanged doctor exit behavior. CI runs them on Windows, Linux and macOS.
