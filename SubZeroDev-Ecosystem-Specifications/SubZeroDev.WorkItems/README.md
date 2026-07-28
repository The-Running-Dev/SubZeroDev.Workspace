# SubZeroDev Work Items

A shared library for the work-item model and reconciliation, consumed by the Backlog plugin and the
Requirements Compiler.

**This is a library, not a plugin.** No manifest, no commands, no result envelope. The plugin
contract does not apply to it.

## Contents

| Document                   | Covers                                             |
| -------------------------- | -------------------------------------------------- |
| `24-work-items-library.md` | The model, reconciliation, and the library's scope |

## Why it exists

Two plugins need the same work-item model and the same reconciliation logic. Written twice they would
diverge, and the divergence would surface as two tools disagreeing about what a work item is while
both claim to be authoritative. Written as a third plugin, every use would be a process-boundary
crossing for what is really a data model and a pure function.

The cost, taken knowingly: it binds both consumers to Python.

## Scope

**In:** the work-item model, immutable provider-issued identity, states, markers and content hashing,
the reconciliation that decides whether two items are the same item and what changed, plan rendering,
and the tracker providers that execute a plan — GitHub first, with GitLab, Gitea, and Forgejo the
same shape behind the same interface.

Providers are in scope because convergence _is_ the write path. Reconciliation that cannot execute
its own actions hands each consumer the half where all four known bugs lived. The coupling is real
and accepted.

**Out:** the approval gate. The library supplies the plan and can execute it; only the calling plugin
issues and checks the token that authorizes execution — which is what keeps a seam for a human. Also
out: parsing, AI, and every plugin-level concern (manifest, envelope, exit codes, CLI, MCP).

## Open questions

One: whether the Requirements Compiler publishes directly or always emits a document and composes
with the Backlog plugin. The tracker-provider scope question is closed.

## Status

Specification only. Built in Phase 3, alongside the Backlog plugin.
