# Working on ContainerPSGenerator

Inspects a container CLI or repository, infers its commands, and generates a PowerShell module that
exposes them as native cmdlets with help and documentation.

**Status: existing capability, contract alignment pending.** This is not a new design — the
capability works today and is being brought under the plugin contract.

## It generates the ecosystem's PowerShell surface

`08-clients.md` in `SubZeroDev.Automator` describes generated per-plugin PowerShell wrappers, and
this plugin is what generates them. That makes it infrastructure for the PowerShell story rather than
a standalone convenience, and it raises the bar on its output: a generated cmdlet that misstates a
parameter is a defect in every plugin's PowerShell surface at once.

## Inference is a proposal

The plugin infers commands from a CLI's own help output or from a repository. Inference is a guess —
help text is written for humans, and it is inconsistent, incomplete, and occasionally wrong.

Treat the generated module as **output to review**, not output to publish. Where inference fails,
failing visibly beats emitting a plausible cmdlet that does the wrong thing: a cmdlet with a
misinferred parameter is worse than a missing cmdlet, because someone will use it.

Once plugin manifests exist, prefer the **manifest** over inferred help text as the source. The
manifest is a declaration; help output is prose that happens to be parseable. This is the direction
the plugin should move as the ecosystem's plugins gain manifests.

## Naming

Generated modules follow the ecosystem's naming rules from ADR-002 in the Architecture repository:
module `SubZeroDev.<Product>.PowerShell`, cmdlet noun prefix `Sz`. The `Sz` prefix and the `sz-` CLI
alias are where the terseness the long namespace lacks actually lives, at the two places people type.

## Alignment work, not redesign

What "contract alignment" means concretely: a manifest, the contract's command surface, the result
envelope on stdout, the contract's exit codes, secrets from the environment, and passing conformance.

It does not mean rethinking the generation strategy. If alignment reveals a genuine design problem,
record it as a question rather than fixing it in passing — this plugin has users.

## Before you finish

- Generated output is reviewable, and failed inference is visible rather than plausible.
- Cmdlet naming follows `Sz` and the module naming rule.
- Alignment did not change generation behaviour without saying so.

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
