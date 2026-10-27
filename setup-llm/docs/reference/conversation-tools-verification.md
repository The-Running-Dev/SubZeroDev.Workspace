---
title: Conversation Tools Verification
sidebar_position: 5
description: Functional evidence and local setup for existing Graphify and MemoryKit tools.
---

# Conversation tools verification

Graphify is the selected context-graph tool. The owner confirmed this choice on
2026-10-27. The merged #57 adapter uses its existing build/export APIs and `graphify path`;
there is no separate graph service to provision. Memory extraction uses AgentKit
#496 and the existing MemoryKit CLI/MCP implementation. #495 and #497 retain the
portable archive and host outbox as their authority.

## Verified on 2026-10-27

| Boundary | Functional result | Scope |
| --- | --- | --- |
| Context graph | Graphify 0.9.91 build, directed parent/source queries, replay, correction, exclusion, removal and stale replay rejection passed. | Disposable synthetic selection; no Notes discovery or model calls. |
| Reviewed extraction and memory | AgentKit main `20822b5` with MemoryKit `5834c49`: 50 tests passed, two intentionally skipped large-volume real-CLI cases. Real candidate/accept/correction/extraction entry points ran. | Isolated synthetic stores and branch archives; test fixtures include project scope and untrusted text checks. |
| Memory MCP | Built MemoryKit 0.1.0, protocol 2026-07-28: discovery, create, operation replay, namespace filtering, read, correction and tombstone passed. | Existing SDK client connected to the existing stdio server; disposable synthetic store removed after close. Namespace filtering is not an authorization test. |
| Local memory configuration | CLI built; private local store initialized under private Notes; AgentKit recall succeeded with an empty project scope. Codex server named `memory` registered. | `capture: false`, `context: false`; no automatic hooks installed. Store excluded locally from Notes Git. |

These are separate from the read-only capability inventory, which deliberately never
opens a store or executes configured code. A configured store/registered server remains
`unknown` there for runtime access. A successful temporary smoke proves the tested
implementation, not every future host session, namespace, extension or configuration.

## Repeat the functional checks

Use trusted existing checkouts and their installed runtimes. Do not download a new
graph backend or install another SDK for these checks. From the Workspace root:

```text
<graphify-python> -I setup-llm/ai-cluster/tests/smoke_conversation_projection_graphify.py
node setup-llm/ai-cluster/tests/smoke_conversation_memorykit.mjs <memorykit-checkout>
```

The MemoryKit smoke requires its existing dependencies and built `dist/cli/main.js`.
It loads the client SDK from that checkout, runs only a fresh temporary synthetic store,
closes the server and removes the temporary directory. It never reads AgentKit config,
the registered host server or the personal store. Failure reports a fixed stage code;
stdout contains no memory content, paths or raw server errors.

For the reviewed extraction boundary, run from the existing AgentKit checkout with
`MEMORYKIT_CLI` set to the built MemoryKit CLI path:

```text
node --test tools/memorykit.test.ts tools/conversation-memory.test.ts
```

This runs the real CLI cases as well as stand-ins; without that environment variable
the real cases skip. Test hook behavior is confined to synthetic configuration and
does not install machine hooks.

## Local setup and private storage

Use the current AgentKit checkout containing #495–#497; an older installed kit may
not contain `tools/conversation-memory.ts` or `tools/memorykit.ts`. Updating the checkout
does not update native skill registrations. Direct tools from that checkout are usable
without changing unrelated machine-wide skills.

AgentKit reads `AGENTKIT_MEMORYKIT_CONFIG` or its default
`~/.agent-kit-state/memorykit.json`. Choose a private store inside the private Notes
checkout and exclude its entire directory using that checkout's local `.git/info/exclude`
**before** initializing it. Verify `git check-ignore` and keep Notes working status clean.
MemoryKit history is part of that excluded directory. Local exclusion does not provide
an off-device backup; protect that store using private storage/backup policy. Notes
Markdown archives remain canonical, versioned and private.

```json
{
  "cli": "<absolute-existing-memorykit-checkout>/dist/cli/main.js",
  "store": "<absolute-private-notes>/.memorykit",
  "capture": false,
  "context": false,
  "contextBytes": 8192
}
```

Initialize the chosen store explicitly with `node <cli> init <store> --json`. Use
`node <agentkit>/tools/memorykit.ts --action recall --project <project>` to verify access.
Project scope derives from the repository remote. Keep personal extraction under Notes;
do not feed personal transcripts into public project namespaces or select personal
summaries for a public graph. Proposed memories remain candidates until explicitly accepted.
Graph summaries and opaque memory references never trigger memory creation or acceptance.

Register the same local server using the host's existing MCP mechanism. For Codex:

```text
codex mcp add memory -- <node> <cli> mcp --store <private-store>
```

This exposes MemoryKit's ordinary local tools to that user's host, including writes;
it is not a namespace authorization boundary. Do not reuse the registration in a shared
host or publish local config/store paths. Registration is reversible with
`codex mcp remove memory`; removing registration does not delete the store or AgentKit config.

## Remaining host limits

The current chat's active tool inventory contains no memory MCP tools. Start a new host
session or reload its MCP configuration, inspect actual tools, and perform an authorized
synthetic test before claiming host activation. The standalone SDK smoke does not prove
Codex's own protocol negotiation or tool routing. The direct AgentKit CLI works now.

No memory extension or memory command declaration was found in the inspected local
VS Code extension directory. Use the existing CLI/MCP workflow; no invented VS Code
command ID, extension installation or editor activation is claimed. Other profiles and
remote extension hosts require their own inventory.

Keep selections, projections and any personal derived material private. No personal
source text, Notes paths or store contents belong in public issues, PRs or this report.
