# Working on the Backlog plugin

The second plugin, and chosen as the second deliberately: it is Python rather than Node, it **writes
to an external system** rather than only reading, and it needs a direct MCP surface. Each of those
exercises a part of the contract the GitHub plugin never touches.

That is the job of this repository. Where the contract turns out to be Node-shaped, read-shaped, or
CLI-shaped, the defect is in the contract and it gets fixed there — not worked around here. A
contract validated by one implementation is a contract fitted to that implementation.

## This plugin writes, which changes everything

**Every write goes through plan-apply.** A read-only command computes what would change and returns
an opaque, single-use, TTL-bounded `planId` plus a rendering a human can review. The apply command
takes **only** the token — no target, no content, nothing that would let it act without a plan.

The fingerprint check is the one most often skipped and the one that matters: between plan and apply,
someone may have edited the target by hand. Applying a stale diff over their change is worse than
refusing.

**This is not optional under MCP.** The caller there is a model acting on text it did not author. A
prose instruction to stop and wait for approval is not a control — another client's model never reads
it. The gate must be structural, and an instruction injected into the plugin's input cannot fabricate
a token.

`--dry-run` is still required for side-effecting commands. Plan-apply is the stronger form, for
writes where seeing the diff first is not merely polite.

## Identity and reconciliation

The work-item model and reconciliation come from the `SubZeroDev.WorkItems` library. Do not
reimplement them here — that library exists precisely because this plugin and the Requirements
Compiler would otherwise express the same model twice and disagree.

Reconciliation keys on **immutable provider-issued identity**. A title is not a key. Keyed on
anything mutable, a rename becomes a delete plus an add and the sync destroys history.

## Two open questions, both recorded with recommendations

**Multi-repo targeting** — one file per repository as today, or per-epic repository targeting.

**Whether this plugin shares a GitHub provider library with the GitHub plugin.** Note the shape of
this one: a shared provider is attractive and would be the second consumer that justifies extraction
under the Platform guard, but it also couples two plugins' release cadences. It is a real decision,
not a refactor.

When either is answered, record it in `23-backlog-plugin.md` **and** reconcile `19-open-questions.md`
in the Architecture repository in the same commit.

## The reference skill

`reference/todo-to-github.skill` is the prior art this plugin generalizes. It is reference material,
not a specification — where it and `23-backlog-plugin.md` disagree, the specification wins.

## Before you finish

- Every write path is reachable only through a plan token.
- The plan carries a fingerprint, and apply refuses when the target has changed.
- No secret is reachable from an MCP tool argument.
- Nothing reimplements what `SubZeroDev.WorkItems` owns.

## What the plugin contract already decides

This repository is a plugin. `SubZeroDev.PluginContract` outranks it: where this specification and
the contract disagree, the contract is correct and this document has drifted.

**Do not restate any of these here.** Reference them.

| Decided in the contract                                                               |
| ------------------------------------------------------------------------------------- |
| The exit-code table, and that `1` is reserved for uncaught exceptions                 |
| Secrets from the environment only — never `argv`, never config, never a tool argument |
| stdout is machine-only; logs go to stderr at every level                              |
| The result envelope, and its schema                                                   |
| Serialization: UTF-8, LF, stable ordering, `null` over omission                       |
| Atomic replacement by per-file rename, never a directory swap                         |
| Schema-version compatibility: accept the same major, refuse a higher one              |
| Configuration precedence, and config-relative path resolution                         |
| Logging levels                                                                        |
| Determinism as a testable requirement                                                 |
| The plan-apply pattern for writes to external systems                                 |
| Manifest shape, capabilities, and the trust levels                                    |

A rule copied here to make this document "self-contained" is the second copy that drifts. It cost
this project a pair of exit-code tables that disagreed about whether `5` meant authentication failure
or partial success.

**The test for a new decision:** would a second plugin face this same question? If yes it belongs in
the contract, even while only one plugin exercises it. If genuinely unclear, the contract is the
safer home.

## The plugin runs standalone

Whatever the Automator can invoke, a person can invoke from a terminal, with the same commands and
the same envelope. If a change makes a command meaningless without the Automator, the change is
wrong.

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
