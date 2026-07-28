# Working on the Release plugin

Generates notes, tags a version, creates a release in a forge, attaches artifacts, and publishes
release metadata.

**Status: sketch.** Phase 5 or later.

## The riskiest plugin in the tooling set

Every command here is **externally visible and hard to undo.** A published release is seen by users,
mirrored by tooling, and consumed by package managers within seconds. A deleted release leaves
dangling references. A moved tag breaks everyone who already fetched it.

There is no equivalent of a local rollback. The blast radius is other people's clones.

That is why the plan-apply gate is not a nicety here: the plan states the tag, the target commit, the
notes, and the artifact digests, and the apply takes a token and nothing else. **The fingerprint
check is the point** — between plan and apply someone may have pushed to the branch, and tagging a
commit the reviewer never saw is exactly the failure this prevents.

## Tags are immutable

Never move a tag. If the wrong commit was tagged, the answer is a new version — the same answer the
Package plugin gives, for the same reason. A moved tag is worse than a wrong one, because the wrong
one is at least consistent for everyone who fetched it.

## Notes are generated, so they are proposed

Release notes assembled from commits or work items are a **proposal a human approves**, not output to
publish. They are read by users, they are the most-read artifact this ecosystem produces, and a
generated summary that misdescribes a breaking change is worse than no notes.

The rendering in the plan is what the human reviews. Make it the actual notes, not a summary of them.

## Ordering

Tag, then release, then attach, then publish metadata — and a failure partway through must leave a
state someone can reason about. A partial release is the normal failure mode here, so `4` and the
envelope's `errors[]` carry real weight: say which steps completed and which did not, by name.

Do not retry automatically. These commands are non-idempotent by nature, and the contract already
says a non-idempotent command is never retried automatically unless explicitly configured.

## Before this can be implemented

1. Change the status from `Sketch`.
2. Specify the plan's contents: tag, target commit, notes, and artifact digests.
3. Specify the partial-failure states by name, since partial is the expected failure rather than an
   edge case.

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
