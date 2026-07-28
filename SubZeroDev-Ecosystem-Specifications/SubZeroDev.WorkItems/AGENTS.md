# Working on the Work Items library

This is a **library, not a plugin.** It has no manifest, no commands, and no envelope. Two plugins
consume it: the Backlog plugin and the Requirements Compiler.

Everything in the plugin contract about commands, exit codes, and envelopes is therefore not about
this repository. What does apply, because it applies to any code handling tokens: secrets by
environment variable only, and no secret in any log, error, or serialized output.

## Why a library and not a third plugin

Two plugins need the same work-item model and the same reconciliation logic. Expressed twice they
would diverge, and the divergence would show up as two tools disagreeing about what a work item is
while both claim to be authoritative.

Expressed as a plugin instead, every use would be a process boundary crossing for what is a data
model and a pure function.

**The consequence to accept:** this binds both consumers to Python. That is a real constraint on the
Requirements Compiler and it was taken knowingly rather than discovered.

## What belongs here

The model, and reconciliation. A work item's identity, its states, and the logic that decides whether
two items are the same item and what changed.

**Identity must be immutable and provider-issued**, the same rule the GitHub plugin follows. A title
is not a key; a title changes. Reconciliation keyed on anything mutable turns a rename into a delete
plus an add, which is how a sync destroys history.

## What does not belong here

**Anything that writes.** Publishing, issue creation, API calls. A library that reconciles and also
publishes has no seam a caller can approve at, and both consumers need the plan-apply gate — which
lives in the calling plugin, where the token can be issued and checked.

**Tracker-specific knowledge**, unless the open question below settles the other way.

## The open question that shapes this repository

**Does the library expose tracker providers, or only the model and reconciliation, leaving each
plugin to talk to its own tracker?**

This is the boundary decision for the repository and it is unresolved. Until it is answered, prefer
the narrower reading — model and reconciliation only. A library that starts narrow and grows is
ordinary; one that starts broad and has to be split has already been depended on.

The second open question — whether the Requirements Compiler publishes directly or always emits a
document and composes — is recorded here because it affects what this library must support, but it is
the Requirements Compiler's to answer.

When either is answered, record it here **and** reconcile `19-open-questions.md` in the Architecture
repository in the same commit.

## Before you finish

- Check that nothing you added performs a write.
- Check that no reconciliation path keys on a mutable field.

## Conventions

These hold in every SubZeroDev specification repository. The canonical copy of this block is
`AGENTS.md` in the Architecture repository; it is repeated here because a repository has to stand on
its own.

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
