# Working on the Docker plugin

Builds, tags, pushes, inspects, and scans container images as a plugin command rather than as
build-agent logic.

**Status: sketch, blocked on a trust question.** Do not implement against this specification until
that question is answered. Phase 5 or later.

## The tension that blocks it

**This plugin needs Docker access, and the security model says Docker access is the thing you least
want to grant.**

That is not a detail to resolve in code. Access to the Docker socket is access to the host: it can
start a privileged container, mount the host filesystem, and read every other container's secrets.
A plugin holding it is not sandboxed by the runtime that sandboxes every other plugin — the
capability model the contract enforces for Docker runtimes has no meaning for the plugin that _is_
Docker.

So the question is not "how do we declare `dockerAccess: true`". The declaration is easy. The
question is what trust level a plugin holding it must have, what an operator is agreeing to when they
grant it, and whether a first-party signature is sufficient grounds.

Until that is answered, `dockerAccess` in the manifest is an honest declaration of an unsolved
problem, not a solution.

## Consequences to hold on to when it is answered

- **Whatever is decided must be visible to the operator**, not implied by the plugin being
  first-party. An operator granting this is granting host access, and the interface should say so in
  those words.
- **Image builds are not reproducible**, so the contract's determinism requirement applies to this
  plugin's **reports** rather than to its images. State which artifacts are exempt and why — the
  contract provides for exactly this.
- **Push is an externally visible write.** A pushed tag is pulled by others within seconds. It needs
  the plan-apply gate, like every other write to a system outside the plugin's own storage.
- **Scan results are findings, not gates**, unless someone decides otherwise deliberately. A scanner
  that fails a build on a transitive advisory with no fix available stops being used.

## Before this can be implemented

1. Answer the trust question in `15-docker-plugin.md` and change the status from `Sketch`.
2. Decide how an operator sees and grants host-level access, in `SubZeroDev.Automator/10-security-model.md`.
3. Name the non-reproducible artifacts and the reports the determinism requirement applies to
   instead.

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
