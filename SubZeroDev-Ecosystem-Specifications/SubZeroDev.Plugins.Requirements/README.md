# SubZeroDev Requirements Compiler

Compiles requirement documents into a structured, reconcilable work hierarchy — epics, features,
stories, tasks — with a language model doing the interpretation and a human approving the result.

## Contents

| Document                             | Covers                                                           |
| ------------------------------------ | ---------------------------------------------------------------- |
| `13-requirements-compiler-plugin.md` | Purpose, model, CLI, the human decision boundary, reconciliation |

## The shape of it

A requirements document goes in. A validated work hierarchy comes out, with stable identifiers, so
that recompiling an edited document produces a **diff** rather than a fresh set of items.

The language model proposes. A human disposes. Nothing reaches an external tracker without someone
approving the specific diff, through the plugin contract's plan-apply pattern: a read-only compile
returns an opaque single-use token plus a rendering, and the publish command accepts that token and
nothing else — refusing it if the target changed in the meantime.

## Stable identity

Recompiling must not turn a reworded story into a deleted story and a new one. Identifiers are stable
across edits, and reconciliation keys on them. The model and the reconciliation come from
`SubZeroDev.WorkItems`, shared with the Backlog plugin so the two cannot disagree about what a work
item is.

## Determinism

A language model does not produce byte-identical output across runs, so the contract's determinism
requirement applies to this plugin's **reports** rather than to the compilation itself — the same
provision the contract makes for compiled binaries and container images. Prompt and model version are
recorded in the output, so a compilation can say what produced it.

## Status

Specification only, and one significant question is open: whether this plugin publishes to a tracker
directly or always emits a document and composes with the Backlog plugin. It shapes the repository
and is unresolved.
