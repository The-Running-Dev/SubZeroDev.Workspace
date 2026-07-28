# SubZeroDev Backlog Plugin

Turns a backlog document into tracked work items, and keeps the two reconciled.

## Contents

| Path                             | Covers                                                 |
| -------------------------------- | ------------------------------------------------------ |
| `23-backlog-plugin.md`           | The specification                                      |
| `BUILD-PLAN.md`                  | Milestones and sequencing                              |
| `reference/todo-to-github.skill` | The prior art this plugin generalizes — reference only |

## Why it is the second plugin

It was chosen to stress the parts of the plugin contract the GitHub plugin never touches: it is
**Python** rather than Node, it **writes** to an external system rather than only reading, and it
needs a **direct MCP surface**.

A contract validated by one implementation is a contract fitted to that implementation. Where this
plugin finds the contract Node-shaped or read-shaped, the contract gets fixed.

## Writes are gated

Every write goes through the contract's plan-apply pattern. A read-only command computes what would
change and returns an opaque, single-use, TTL-bounded token plus a rendering a human can review; the
apply command accepts that token and nothing else, and refuses it if the target has changed since the
plan was taken.

This matters most under MCP, where the caller is a language model acting on text it did not author.
An instruction injected into the plugin's input cannot fabricate a plan token — which is the whole
reason the gate is structural rather than a documented convention.

## Shared model

The work-item model and reconciliation live in `SubZeroDev.WorkItems`, shared with the Requirements
Compiler so the two cannot disagree about what a work item is. Reconciliation keys on immutable
provider-issued identity, so a retitled item is the same item.

## Status

Specification and build plan written. Two open questions remain — multi-repository targeting, and
whether to share a GitHub provider library with the GitHub plugin — both recorded with
recommendations. Built in Phase 3.
