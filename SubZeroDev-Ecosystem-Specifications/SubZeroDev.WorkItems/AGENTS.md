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

**Tracker providers, with GitHub first.** GitLab, Gitea, and Forgejo are the same shape and slot in
behind the same interface.

Providers are in scope because **convergence _is_ the write path.** Reconciliation that cannot
execute its own actions hands each consumer the half where all four known bugs lived. The coupling
that buys is real and accepted: a provider change affects both consumers, and this library's release
cadence becomes a shared constraint.

## What does not belong here

**The approval gate.** The library supplies the plan and can execute it; only the calling plugin
issues and checks the token that authorizes execution. That separation is what keeps a seam for a
human — a library that decided who may apply would remove it.

**Parsing** — the Backlog plugin's markdown parser stays there. **AI** — prompts, provider
abstraction, and classification stay in the Requirements Compiler. **Plugin concerns** — manifest,
envelope, exit codes, CLI, MCP — are contract-level, and a library has none of them.

## The open question that remains

**Whether the Requirements Compiler publishes directly, or always emits a document and composes with
the Backlog plugin.** It is recorded here because it changes what this library must support, but it
is the Requirements Compiler's to answer.

The tracker-provider question is **closed** — see the Open questions section of
`24-work-items-library.md`. It was open in one section of that document while another section
answered it, and three downstream documents had each read a different half.

When the remaining question is answered, record it here **and** reconcile `19-open-questions.md` in
the Architecture repository in the same commit.

## Before you finish

- Check that no reconciliation path keys on a mutable field.
- Check that nothing you added decides **who may apply** a plan. Executing one is this library's job;
  authorizing one is not.

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
