# Working on the Build plugin

Runs restore, build, and test for a project and reports the results in a normalized shape.

**Status: sketch, with an unresolved scope question.** Do not implement against this specification
until that question is answered — see below. Phase 5 or later.

## The scope trap, which is this repository's entire risk

The original note said "avoid making this a universal language-specific build system". That is the
right instinct and it is the easiest one in the ecosystem to lose, because **every build system began
as a thin wrapper.**

The pressure is always the same and always reasonable: one project needs a flag, so the plugin learns
a flag. Another needs a pre-step. A third needs a different test reporter. Each addition is small and
justified by a real user, and the sum is a build system nobody chose to write and everybody now
depends on.

The defence is to decide what this plugin _is_ before it acquires users, not after. Until the scope
question is answered, treat additions as evidence that it has not been answered.

**The test to apply to any proposed capability:** does it normalize output that already exists, or
does it decide how the build happens? The first is this plugin. The second is the project's build
system, and belongs to the project.

## What it does own

The **normalized report**. Restore, build, and test produce wildly different output across
ecosystems, and something has to turn that into one shape a workflow can branch on and a human can
read. That shape is the deliverable, and it is the part that would otherwise be re-invented per
project.

Test results, timings, warnings, and failures normalize. Build _configuration_ does not.

## Packaging is not here

It is the Package plugin's. That boundary is easy to blur because building and packaging are one
command in several toolchains, and blurring it means the plugin that produces bytes also publishes
them — with no seam for approval between.

## Before this can be implemented

1. Answer the scope question in `15-build-plugin.md` and change the status from `Sketch`.
2. State the normalized report's schema. It is the deliverable, so it is the thing that needs a
   schema first.
3. Confirm the boundary with the Package plugin holds for a toolchain where build and pack are one
   command.

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
