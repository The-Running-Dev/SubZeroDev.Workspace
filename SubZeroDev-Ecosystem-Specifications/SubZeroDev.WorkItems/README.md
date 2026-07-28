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

**In:** the work-item model, immutable provider-issued identity, states, and the reconciliation that
decides whether two items are the same item and what changed.

**Out:** anything that writes. Publishing and issue creation stay in the calling plugin, where the
plan-apply approval gate can issue and check a token. A library that reconciles _and_ publishes
leaves the caller no seam to approve at.

## Open questions

Whether the library exposes tracker providers or only the model and reconciliation is unresolved, and
it is the boundary decision for this repository. Until it is settled, the narrow reading applies.

## Status

Specification only. Built in Phase 3, alongside the Backlog plugin.
