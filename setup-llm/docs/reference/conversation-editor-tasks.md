---
title: Conversation Editor Tasks
sidebar_position: 6
description: Opt-in VS Code tasks for the existing AgentKit conversation and reviewed memory workflows.
---

# Conversation editor tasks

Open this repository folder in VS Code and choose **Terminal → Run Task**.
The six `Conversation:` tasks are thin process adapters to AgentKit #495–#497.
They require Node 22.18 or later and an existing AgentKit installation containing
`conversation.ts`, `conversation-memory.ts` and `conversation-host.ts`. Set
`AGENTKIT_HOME` before starting VS Code when that installation is outside
`~/.agent-kit`. No extension, graph database or new memory service is required.

Each task prompts for an **existing private archive** and an **existing private
request JSON file**, both absolute paths. Prepare these with AgentKit's existing
conversation schema. The archive needs its normal `INDEX.md` with exactly one
`<!-- notes -->` marker. Keep personal requests, source files, archives and derived
material in private Notes. Do not put them in this public Workspace checkout.

| Task | Existing AgentKit entry point | Request action |
| --- | --- | --- |
| Conversation: Fork | `tools/conversation.ts` | `fork` |
| Conversation: Attach | `tools/conversation.ts` | `attach` |
| Conversation: Return | `tools/conversation.ts` | `return` |
| Conversation: Review memory | `tools/conversation-memory.ts` | `propose` |
| Conversation: Store reviewed candidates | `tools/conversation-memory.ts` | `store` |
| Conversation: Host adapter request | `tools/conversation-host.ts` | Existing `prepare`, `dispatch`, `record` or `reconcile` action |

The wrapper passes paths as literal process arguments without a shell. VS Code's
task command echo is disabled. The terminal reports state, revision and a private
`Result` file URI; open that file for the full packet, parent link, review or host
receipt. Full results stay under `<archive>/.workspace-conversation-results/`.
The directory inherits the archive's access controls; Unix result files request
mode `0600`. It is private transport output, not a new source of truth.

Raw child stderr, source bodies, proposal text and packets never print to the task
terminal. A failure returns the AgentKit exit status and a private result when
structured output exists. A process interruption or unreadable output gives a
fixed recovery message: inspect the archive before retrying, because the operation
may already have persisted. Existing operation IDs, revisions and replay rules
remain AgentKit's responsibility. Reusing a request preserves its operation ID.

## Walk through a branch

1. Prepare a `fork` request with a stable branch/operation ID, parent URI, exact
   source coverage, byte references and attributed handoff statements. Run **Fork**
   and open its private result. Use the portable packet in the intended chat.
2. Prepare an `attach` request for the same branch with a new operation ID and the
   returned revision. Select only the later context to attach. Run **Attach**;
   existing sources and attribution remain in the archive.
3. Prepare a `return` request at the current revision with the selected outcome.
   Run **Return** and open its result for the parent link and attributed packet.
4. Prepare a `propose` request with a new review ID and selected statement indices.
   Run **Review memory** and inspect its private review before choosing proposals.
5. Prepare a `store` request naming that review and only the selected proposal IDs.
   Run **Store reviewed candidates**. With memory off it returns `NotConfigured`
   (exit `2`) and preserves the review. No store is created or configured by tasks.
6. With an explicitly configured existing MemoryKit adapter, rerun that store
   request. Items remain unverified candidates. Acceptance is a separate explicit
   action in AgentKit's existing `memorykit.ts` workflow; tasks never accept them.

See the installed AgentKit [portable workflow](https://github.com/The-Running-Dev/SubZeroDev.AgentKit/blob/main/skills/conversation/SKILL.md),
and its tools' schemas/tests for complete request contracts. The local
`conversation-task.test.mjs` contains a synthetic fork/attach/return/review/store
example using no personal content. Use the
[capability report](./conversation-capabilities.md) before selecting optional
adapters and [existing MemoryKit setup](./conversation-tools-verification.md)
when memory is wanted. Graphify projection remains the separate reviewed
[selected-context operation](./conversation-projection.md).

## Native host boundary

An ordinary VS Code task has no native chat-tool transport. **Fork**, **Attach**
and **Return** always provide the portable workflow. They do not create a chat,
clone history, send a message or navigate a host implicitly.

When running in a host that actually exposes native tools, use **Host adapter
request** with #497's existing capability evidence and explicit authorizations.
Its preparation selects the existing native or portable adapter, and its outbox
produces the call and receipt. The host workflow executes the named native tool,
then records/reconciles the receipt through the same task. This task itself never
invokes an invented VS Code command or MCP bridge. Recheck live tools before
dispatch; a registration or manifest declaration is insufficient evidence.

## Verification

Run `node --test setup-llm/scripts/conversation-task.test.mjs` from the repository
root. CI checks literal arguments, private output and failure redaction on Windows,
Linux and macOS. Set `AGENTKIT_TEST_HOME` to the existing AgentKit checkout to
include its real portable entry points. Set `MEMORYKIT_CLI` to its existing built
CLI to include isolated candidate storage. Tests create disposable synthetic data;
they do not read the personal store or register/install any adapter.

Existing provisioning and MCP tasks retain their labels and arguments. Conversation
tasks do not alter provisioning, host registration, extensions or global settings.

### Windows editor smoke — 2026-10-28

VS Code 1.143.1 (x64), Node 26.12.1 and a worktree based on `8ab22f3`
were tested with an isolated VS Code profile, extensions disabled, and explicit
AgentKit/configuration environment variables. All input lived in a disposable
synthetic archive outside this checkout. Using **Terminal → Run Task** and the
actual path prompts produced:

| Step | Observed result |
| --- | --- |
| Fork synthetic exact source | `Forked`, revision 1 |
| Attach a distinct later source | `Attached`, revision 2; both source hashes retained |
| Return selected outcome | `Returned`, revision 2; private packet contains parent URI and source coverage |
| Review selected statement | `Proposed`; review persisted privately |
| Store while configuration absent | `NotConfigured`, exit 2; review retained |
| Rerun with isolated existing MemoryKit adapter | `Stored`; only selected item persisted as `candidate`, `unverified` |

Task terminals displayed state and private result URIs without source bodies.
Private results were inspected to confirm parent navigation data, both archived
sources and candidate status. No native chat API or memory extension was needed.
The unchanged provisioning preview entry point (`setup.ps1 -Client Both -WhatIf`)
also completed with exit 0; all 13 original task definitions remain intact.
The real AgentKit/MemoryKit wrapper test passed 2 tests with 0 skipped.

Desktop MCP discovery is a separate boundary: the desktop restarted, but this
chat still exposed no MemoryKit tools. That unresolved host check is tracked in
[Workspace #64](https://github.com/The-Running-Dev/SubZeroDev.Workspace/issues/64);
the editor result above uses the existing CLI adapter and makes no desktop routing
claim.