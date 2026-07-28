# Working in the Architecture repository

This repository owns what belongs to no single product: the vision, the logical architecture, the
phase vocabulary, the repository layout, the ecosystem testing model, and the open-questions
register.

**It is also where the cross-repository authoring conventions are canonical.** Every other
SubZeroDev specification repository repeats the conventions block below so it can stand alone. If the
block changes here, it changes everywhere in the same commit.

**One line differs on purpose.** This copy says "This is the canonical copy"; the repeats name this
repository instead. Everything from the first bullet onward is byte-identical and is what a
consistency check should compare — comparing the introductions would require the canonical copy to
lie about being canonical. A checker that diffs whole sections will flag this; it is the intended
difference, and X13 should encode it rather than remove it.

## What belongs here

A document belongs in this repository when no single product owns it and every product is affected
by it. The test: if the Automator disappeared, would this document still be needed by Platform and
by the plugins? If yes, it is architecture.

What does **not** belong here, with the reason:

| Not here              | Because                                                               |
| --------------------- | --------------------------------------------------------------------- |
| The plugin contract   | It is depended on by everything and depends on nothing — its own repo |
| Product internals     | Platform and Automator own their own specifications                   |
| Any individual plugin | One repository per plugin                                             |
| Implementation code   | This repository is documents                                          |

## What this repository owns exclusively

**Phase numbers.** `18-roadmap.md` defines the phase vocabulary for the entire ecosystem. No other
document maintains its own phase numbering; where one needs to state scope it references a phase from
here. A build plan that invents "Phase 2" locally is a defect.

**The open-questions register.** `19-open-questions.md` is the consolidated view. A question may also
be recorded in the document that owns it, but the register must agree with the sum of them — it once
claimed one open item while ten had accumulated, because each was closed or opened in its own
document and nobody reconciled.

Resolved questions stay in the register, under Resolved, with their reasoning. Deleting them loses
the argument and invites someone to reopen a settled question in good faith.

**The repository layout.** `16-repository-layout-and-packaging.md` decides which repository each
thing lives in. When a new document or component appears anywhere in the ecosystem, its destination
is recorded there, or it has no home.

## Invariants

- **The dependency direction is one-way: plugins → Automator → Platform.** Each layer depends on the
  one beneath it and never the reverse. Platform never depends on Automator or on a plugin, and a
  document that implies otherwise is wrong, whichever document it is.

  Note the arrow. `01-ecosystem-architecture.md` and the READMEs draw the stack top-down as
  `Platform → Automator → plugins`, which is **layering**, not dependency — the arrow points from the
  thing depended on toward the thing that depends on it. Label whichever one you mean; the two point
  opposite ways and reversing them turns the invariant into an instruction to add the forbidden
  reference.

- **The plugin contract sits outside that stack.** It is depended on by the Automator and by every
  plugin, and depends on nothing.
- **The Platform extraction guard.** A capability becomes a Platform package when a _second_ consumer
  needs it, not when the first one does. The original draft specified twenty-four Platform packages
  before one had a consumer; the guard is what keeps the minimal six from becoming those
  twenty-four by increments.

## Conventions

These hold in every SubZeroDev specification repository. **This is the canonical copy**; the others
repeat it because a repository has to stand on its own.

- **Reference, never restate.** A rule that lives in another document is linked, not copied. Two
  copies of a rule is a promise they will diverge and a guarantee nobody will notice which is stale.
- **The plugin contract outranks plugin specifications.** Where a plugin document and the contract
  disagree, the contract is correct and the plugin document has drifted. See ADR-003 in
  `SubZeroDev.PluginContract`.
- **A decision gets an ADR.** Status is exactly one of `Proposed`, `Accepted`, `Superseded`, or
  `Deprecated`, under a `## Status` heading. An accepted ADR states its context, the decision, the
  consequences _including the costs_, and the alternatives it rejected and why. "Accepted in existing
  practice" is not a status — ratifying current practice is a note in the context.
- **Move, never copy.** A specification has exactly one home. Where another repository needs the
  text, it references a tagged commit rather than duplicating the file.
- **Give reasons.** These documents are read by people deciding what to build. An assertion with no
  reason cannot be evaluated, and cannot be safely revised by someone who was not there when it was
  written.
- **Markdown is Prettier-formatted**, 100 columns, LF endings.

## Reading order

1. `00-vision-and-boundaries.md` — what this is and what it deliberately is not
2. `01-ecosystem-architecture.md` — the logical picture
3. `16-repository-layout-and-packaging.md` — where everything lives
4. `18-roadmap.md` — the phase vocabulary everything else references

## Before you finish

- Prettier-check the Markdown.
- If you changed a phase definition, check every document that references a phase number by name.
- If you opened or closed a question anywhere in the ecosystem, reconcile `19-open-questions.md` in
  the same commit.
