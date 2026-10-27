---
title: Selected Conversation Projection
sidebar_position: 4
description: Rebuild approved branch context with the installed Graphify tools.
---

# Selected conversation projection

This opt-in adapter implements [Workspace #57](https://github.com/The-Running-Dev/SubZeroDev.Workspace/issues/57)
on the [capability inventory](./conversation-capabilities.md) and AgentKit's
[portable branches (#495)](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/issues/495),
[reviewed memory extraction (#496)](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/issues/496)
and [host outbox (#497)](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/issues/497).
The private branch archive remains canonical. Graphify receives a separate, reviewed
selection, with no archive discovery, transcript extraction or model call. The graph
is disposable retrieval support under the [memory/RAG contract](../architecture/memory-rag-contract.md).
No new database, background service or memory store is introduced.

## Verified integration and gaps

Verified locally on 2026-10-27 with installed `graphifyy` / `graphify` **0.9.91**:

- `graphify.validate.assert_valid(extraction)` validates nodes and edges.
- `graphify.build.build_from_json(extraction, directed=True, dedup=False)` preserves
  stable identities and relationship direction without prose extraction or an LLM.
- `graphify.export.to_json(graph, {}, output, force=True, built_at_commit=selectionDigest)`
  writes the existing Graphify graph format. Replacement is permitted only in the
  adapter's dedicated disposable directory, including intentional removals.
- `graphify path 'branch:child' 'branch:parent' --graph <graph.json> --directed`
  returned `child --forked_from [EXTRACTED]--> parent` in the synthetic smoke test.

Graphify's document detector accepts Markdown/text and declares `extra_excludes` and
gitignore support. In this version tracked files bypass gitignore filtering. The adapter
therefore uses the build API with selected JSON only; it never runs `extract`, `watch`,
global indexing, or discovery against Notes. It does not rely on exclusions to sanitize
a broad private corpus. The installed package API is version sensitive: incompatible
imports/builds report an optional adapter failure and leave no retrievable old graph.

**Live context-graph owner/API/schema remains unverified.** Every result reports
`contextGraph: unknown-owner`; no live context-graph adapter is claimed. The selected
extraction provides an explicit mapping for an eventual verified owner. Historical
AgentKit design files are not treated as the running context graph.

**Memory remains AgentKit #496's reviewed MemoryKit workflow**, with its configured
namespace and store as authority. Optional summary `memoryRef` values are opaque
references to already reviewed records, not new memory writes or proof of existence.
This adapter never opens a memory store, switches stores, registers MCP tools or
enables infrastructure. This workstation has no verified configured MemoryKit/VS Code
memory tool, as recorded by #56. Their absence does not block portable Notes capture
or this local graph projection. There is no automatic graph-to-memory synchronization.

## Run with existing tools

Use PowerShell 7.4+ and the **existing Graphify environment's Python**, 3.12+ recommended.
No install occurs. Locate that interpreter in your `uv tool dir` environment; Windows
normally uses `graphifyy/Scripts/python.exe`, Unix `graphifyy/bin/python`.
`-I` isolates Python from user-site/PYTHONPATH injection while retaining that environment.

From the repository root, with an operator-selected interpreter:

```powershell
$python = '/absolute/path/to/graphifyy/bin/python'
$state = Join-Path $HOME 'synthetic-conversation-projection'
./setup-llm/scripts/Project-ConversationContext.ps1 -PythonPath $python -StateRoot $state -SelectionPath ./setup-llm/ai-cluster/tests/fixtures/conversation-selection.json
graphify path 'branch:child' 'branch:parent' --graph (Join-Path $state 'graph.json') --directed

# Rebuild the persisted selection, including its exclusion ledger.
./setup-llm/scripts/Project-ConversationContext.ps1 -PythonPath $python -StateRoot $state
```

Use this committed fixture only for synthetic smoke tests. For real material, both
the selection and state directory must stay private, inside private Notes or another
appropriately restricted private location. Never put personal material, private archive
links, selection files or derived graphs in Workspace/public issues or the blog.
Use an ignored state directory (`rag-index` / `rag-cache` where appropriate), outside
versioned source. Unix new state directories/files request owner-only permissions;
Windows inherits the chosen private directory's ACL. Review ACLs when choosing it.

The Python entry point is also callable directly:

```text
<existing-python> -I setup-llm/scripts/conversation_projection.py --state-root <private-dedicated-directory> [--selection <reviewed-selection.json>]
```

Exit `0` means built; `3` means Graphify is absent or failed (retryable); `2` means
invalid input/state/access or another invocation error. Results contain fixed codes
and operational version/status only. Graphify stdout/stderr is suppressed because it
can contain selected text. No source content, input path or traceback is logged.

## Selection format and graph mapping

The [synthetic fixture](https://github.com/The-Running-Dev/SubZeroDev.Workspace/blob/main/setup-llm/ai-cluster/tests/fixtures/conversation-selection.json)
is the complete schema example. The strict allowlist accepts:

| Object | Required fields | Optional fields |
| --- | --- | --- |
| Selection | `schemaVersion: 1`, `corpusId`, positive `revision`, `branches` | `exclude`, `restore` (branch ID arrays) |
| Branch | `branchId`, positive `sourceRevision`, `sources`, `summaries` | `parentBranchId` |
| Source reference | `refId`, lowercase 64-character `sha256` | None |
| Stable summary | `summaryId`, `role`, `kind: summary`, `approved: true`, `text` | `memoryRef` |

IDs are lowercase letters/digits/hyphens, 1–64 characters, beginning with a letter or
digit. Roles are `user`, `assistant`, `unknown`; attribution remains explicit. Only
approved **summaries** belong here: exact user statements, assistant suggestions,
incomplete story candidates and completed stories remain distinct in Notes. Do not
silently turn any of those into a stable fact or approved memory. A source hash is
operator-supplied provenance, not a claim that this adapter read/verified the archive.
Source IDs are opaque handles resolved privately in Notes; no archive URI/path is accepted.

Prepare the selection explicitly from the reviewed branch metadata. For AgentKit,
`branchId` and `revision` from the canonical branch manifest map to `branchId` and
`sourceRevision`; selected source IDs/hashes map to `refId`/`sha256`. Do **not** pass
`branch.json` to this command: it also contains handoff/prompt/receipt material. This
adapter opens only the explicit selection and its own state; it never follows a source
reference. Its reader must be given reviewed metadata, not an archive dump.

Unknown fields (including raw/prompt/path payloads), duplicate JSON keys, duplicate
IDs, cycles, unapproved text and non-summary kinds are rejected before Graphify runs.
External selection input is bounded to 2 MiB, 500 branches, 100 sources/summaries per branch and 2,000
characters per summary. Common secret-shaped summaries are rejected with a fixed
error. Owned state/graph readers allow their expanded representation and accumulating
exclusion ledger to grow beyond the selection input cap, so accepted selections remain
rebuildable/removable. This is a defense in depth check; approval requires a real human/content review,
and cannot automatically identify every secret or private detail concealed in prose.

| Graph entity | Identity / relation | Provenance |
| --- | --- | --- |
| Branch node | `branch:<branchId>` | Source branch revision |
| Source node | `source:<refId>` | Selected source SHA-256 |
| Summary node | `branch:<branchId>:summary:<summaryId>` | Role, kind, source revision, optional opaque memory ref |
| Child → selected parent | `forked_from` | Source branch revision |
| Branch → source | `attached_source` | Source branch revision |
| Branch → summary | `approved_summary` | Source branch revision |

Every node/edge carries corpus ID, selection revision/digest, projection schema version
and `embeddingIdentity: none`; `source_file` is `selected:<corpusId>`. Only selected
ancestors become nodes/edges. Excluding a parent removes the relation rather than
silently restoring the parent. No relationship is inferred from text. Ordering and IDs
are deterministic; unchanged replay and rebuild yield the same relationships.

## Correction, exclusion, rebuild and removal

Selections are complete snapshots. Increase selection `revision` for any change. Increase
the affected `sourceRevision` when changing branch metadata or approved summaries;
equal revisions with different content and lower revisions are rejected. A corpus ID
cannot change in an existing state directory. Replay of an identical revision is safe.

Omitting a previously selected branch, or listing it in `exclude`, records a persistent
tombstone. To restore it intentionally, submit a higher selection revision and name it
in `restore`; the source high-water check still applies. Rebuild without `--selection`
uses the persisted snapshot and ledger. An older selection cannot resurrect exclusions,
even if its file is copied back into the selection directory. Keep `state.json` when
resetting derived files; discarding the ledger also discards this replay protection.

The directory must be dedicated and empty on first use. Thereafter only this adapter's
named files are accepted: `state.json`, `extraction.json`, `graph.json`, `receipt.json`,
their fixed `.tmp` files, the exclusive `lock` and Graphify's verified
`cache/last_query_stamp`. Unknown files, symlinks and junctions
cause a refusal; unrelated files/directories are never recursively deleted. Use
canonical directory paths (for example macOS `/private/var`, rather
than its `/var` system symlink). Concurrent
updates are refused. If a process is killed, remove an orphan `lock` only after verifying
no adapter is still running, then rebuild to reconcile any interrupted publication.

`state.json` retains the selection, source revision high-water hashes and tombstones.
It is committed before the optional Graphify build. Each invocation invalidates the
previous extraction, graph, receipt, temporary derivatives and the verified query stamp,
then rebuilds. Adapter
failure removes all those derivatives while retaining selected state and exclusions.
Source archives are never opened, changed or deleted. Only use a graph from a completed
successful command, with the matching `selectionDigest` in `receipt.json` and the graph
SHA-256 it records. After an interrupted invocation, rebuild before retrieval.

The build creates **no embeddings, query-result caches, snapshots, global index or database**.
The supported `graphify path` retrieval command also creates `cache/last_query_stamp`;
that fixed stamp and its empty cache directory are invalidated along with the three
named derived JSON files on correction/removal/rebuild. Other cache contents are refused
and preserved for explicit operator handling. Do not feed its private output into global
index/watch/cache commands; external copies/caches fall outside this ownership boundary
and must be removed explicitly before retrieval resumes. Ordinary removal does not erase
Git history, backups or the canonical private archive. Never remove `state.json` as a
substitute for exclusion.

Projection schema changes require an explicit migration preserving the selected snapshot,
tombstones and source high-water ledger. Embedding identities other than `none` are not
accepted by this schema. A future embedding integration must use an explicit, documented
fresh-index/migration procedure under the existing memory/RAG contract; no mixed vectors
or implicit migration are supported.

## Verification

Run the service-free synthetic lifecycle suite:

```text
python -I setup-llm/ai-cluster/tests/test_conversation_projection.py

# Separately, with installed Graphify Python and its matching CLI on PATH:
<existing-python> -I setup-llm/ai-cluster/tests/smoke_conversation_projection_graphify.py
```

It checks parent/source relations and attribution, deterministic replay/rebuild, corrections,
source/selection revision conflicts, deletion/exclusion/reindex/explicit restore, excluded
ancestors, adapter failure and retry, private/raw/secret sentinels, unrelated archive/file
preservation, locks and symlink refusal (skipped if the host cannot create symlinks).
CI runs this suite on Windows, Linux and macOS and executes the PowerShell entry point
with an absent optional Graphify installation. The actual installed Graphify smoke above
is separate evidence; a live context-graph smoke remains blocked on identifying its owner.
