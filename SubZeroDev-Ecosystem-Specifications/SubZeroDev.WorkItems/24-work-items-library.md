# SubZeroDev.WorkItems — Shared Library

| Field       | Value                                                           |
| ----------- | --------------------------------------------------------------- |
| Status      | Draft                                                           |
| Destination | Its own repository                                              |
| Consumers   | `SubZeroDev.Plugins.Backlog`, `SubZeroDev.Plugins.Requirements` |
| Kind        | Library, not a plugin. It has no manifest and no CLI            |

## Why this exists

Two plugins produce the same thing by different means and publish it to the same place.

|           | Backlog                                 | Requirements Compiler                   |
| --------- | --------------------------------------- | --------------------------------------- |
| Input     | A structured markdown backlog           | Prose requirements                      |
| Method    | Deterministic parse                     | AI-assisted derivation                  |
| Output    | Epic → story → task hierarchy           | Epic → story → task hierarchy           |
| Publishes | Issues, labels, milestones, Projects v2 | Issues, labels, milestones, Projects v2 |
| Needs     | Stable IDs, reconciliation, dry run     | Stable IDs, reconciliation, dry run     |

The front ends genuinely differ — one parses, one reasons. **Everything after the work-item model is
identical**, and it is the harder half: stable identity across regeneration, reconciliation against
what already exists, and a write path that converges rather than duplicating.

Two implementations of that would be two sets of convergence bugs. The Backlog plugin already carries
fixes for four such bugs, three of which were invisible to unit tests.

## What the library owns

**The work-item model.** Epic, story, task, with title, body, acceptance criteria, labels,
assignees, milestone, tracker fields, and parent links.

**Stable identity.** Generated IDs that survive regeneration where source meaning is unchanged. This
is the load-bearing piece: without it, reconciliation cannot tell an edit from a deletion plus an
addition — the same failure the GitHub plugin's repository identity decision addresses, in a
different domain.

**Markers and content hashing.** How a published item is recognized as managed, and how "changed"
is decided. Number-versus-string comparison lives here; it is where one of the four bugs was.

**Reconciliation.** Given a desired set and an observed set, produce the actions to converge —
create, update, no-op, orphan — ordered parents before children.

**Plan rendering.** A human-readable diff, and the structured action list beside it.

**Tracker providers.** A write interface with GitHub first. GitLab, Gitea, and Forgejo are the same
shape and slot in behind it, exactly as the release plugin anticipates for forges.

## What the library does not own

- **Parsing.** The Backlog plugin's markdown parser stays in the Backlog plugin.
- **AI.** Provider abstraction, prompts, and classification stay in the Requirements Compiler.
- **Plugin concerns.** Manifest, envelope, exit codes, CLI, MCP — all contract-level, and a library
  has none of them.
- **Approval.** The plan-apply gate is a contract pattern implemented by each plugin. The library
  supplies the plan; it does not decide who may apply it.

## The constraint this choice carries

**A shared library binds both plugins to one language.** That is the cost of choosing a library over
composing through a document format, and it should be stated rather than discovered.

Consequences:

- The Backlog plugin is Python, so **the Requirements Compiler is Python too.** Its specification does
  not currently name a language; this decides it.
- A future work-item plugin in another language cannot consume this library. It would have to
  reimplement the model or compose through the backlog document format instead.
- The library versions independently and both consumers pin it. A breaking change to the work-item
  model is a coordinated release across two repositories.

The alternative — Requirements Compiler emits a backlog document, the Backlog plugin publishes it —
needs no shared code and no shared language, at the cost of requiring a workflow to get from prose to
issues. That path stays open: the document format is specified regardless, and a plugin can always
compose rather than link.

## Interchange format

Even with the library, **the backlog document format remains a public interchange format**, because
it is the Backlog plugin's input and a human-editable artifact.

The Requirements Compiler should be able to emit it. That keeps the composition path available, gives
its output a reviewable form, and means a user can hand-edit compiled requirements before publishing
— which is the workflow its own specification already describes as compile, approve, publish.

## Versioning

Semantic versioning, published as a language package. Both consumers pin a compatible range.

The work-item model carries a schema version, separate from the library version. A model change that
alters published content is a major bump on both.

## Testing

The library owns the round-trip test, because it owns convergence.

A fake tracker holding state, replaying plan → apply → plan, asserting the second plan is entirely
no-op. **It must reproduce provider quirks, in particular number fields returning as floats** — that
single behaviour is what the original unit tests missed and what broke convergence.

Both consumers inherit that suite by depending on the library, which is the practical argument for
sharing: the expensive test is written once.

## Open questions

1. Does the library expose tracker providers, or only the model and reconciliation, leaving each
   plugin its own write path? Sharing the write path is most of the value; it is also most of the
   coupling.
2. Should the Requirements Compiler publish directly, or always emit a document and compose? Both are
   supported by this design; the question is which is documented as the default.
