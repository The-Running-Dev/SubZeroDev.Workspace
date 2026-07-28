# Working on the Documentation plugin

Builds and publishes project documentation from a shared Docusaurus base image.

This plugin is **existing practice being aligned to the contract**, not a new design. The image
inheritance pattern already works and is ratified in `adr/ADR-001`. Alignment work should not become
a redesign.

## The base image is the whole design

A project's documentation image derives `FROM` the shared base and adds content, configuration
overrides, and nothing else.

Two constraints keep that safe:

**Pin the base by digest, not by tag.** The contract requires this for non-development Docker
runtimes, and inheritance is where a mutable tag does the most damage — a base rebuild would silently
change every derived project's output, breaking determinism in a way nobody would attribute to the
base.

**Derived images add content, not tooling.** A project needing a build-step change needs it in the
base, where every project gets it. A project-local tooling override is the start of the drift the
shared base exists to prevent, and it re-creates the per-project vendoring this pattern rejects.

If you find yourself adding an escape hatch for one project, that is the signal the base is missing
something.

## Base image releases are an ecosystem event

A base change reaches every project on its next rebuild. That makes the base's release discipline
part of this plugin's specification, not an operational detail: semantic versioning, a changelog, and
digest pinning downstream so an upgrade is an explicit commit rather than an ambient event.

## This specification is thinner than its siblings

`14-documentation-plugin.md` has had lighter editing than the GitHub and Backlog specifications. It is
known, and it is not a licence to fill the gaps by inference — where it is silent on something the
contract covers, the contract answers. Where it is silent on something genuinely specific to this
plugin, that is a question to record rather than a blank to fill.

## Before you finish

- The base image is pinned by digest wherever it is referenced.
- Nothing added lets a derived project override tooling.
- A documentation build produces the same bytes twice from the same inputs.

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
