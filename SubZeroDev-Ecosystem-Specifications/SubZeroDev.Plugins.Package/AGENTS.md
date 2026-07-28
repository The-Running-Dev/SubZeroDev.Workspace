# Working on the Package plugin

Produces and publishes distributable packages for NuGet, npm, PowerShell Gallery, and plain archives,
behind one provider boundary.

**Status: sketch.** Phase 5 or later.

## The property that shapes every decision here

**Most package registries treat a published version as permanent.** npm restricts unpublishing, NuGet
delists rather than deletes, PowerShell Gallery is similar.

Publishing the wrong bytes under a version number is effectively unrecoverable. The remedy is always
a new version, never a correction — and every consumer who resolved the bad version in the meantime
has it.

That single fact justifies things that would be over-engineering anywhere else:

- **Plan-apply is mandatory for publish**, not merely recommended. The plan states the exact
  registry, the exact version, and the digest of the exact bytes; the apply accepts a token and
  nothing else, and refuses when the fingerprint no longer matches.
- **Refuse on mismatch rather than overwrite.** If a version already exists remotely, the run fails.
  It does not skip quietly, and it does not force.
- **The dry run is the default posture**, not a flag people remember.

## One provider boundary, not four plugins

Four registries, one abstraction. The commands are the same shape; only the provider differs.

Keep registry-specific types behind the provider boundary. A version string, a package identifier,
and an authentication token look similar enough across NuGet, npm, and PowerShell Gallery that
leaking one registry's shapes into the domain model is easy and only hurts when the second registry
arrives.

Where registries genuinely differ — prerelease semantics, identifier casing rules, scope handling —
that difference is provider knowledge, stated explicitly rather than normalized away.

## Building is not here

The Build plugin produces the bytes; this one publishes them. That boundary exists so the thing which
produces artifacts is not the thing that makes them permanent, and so there is a seam where a human
can approve.

Several toolchains make build and pack one command. That is a reason to be careful about the
boundary, not a reason to merge the plugins.

## Credentials

Registry tokens are secrets under the contract: environment variable only, never `argv` — a publish
command's arguments are exactly what ends up in a CI log — never a configuration file, never an MCP
tool argument.

## Before this can be implemented

1. Change the status from `Sketch`.
2. Specify the plan's contents for a publish: registry, identifier, version, and the digest of the
   bytes.
3. Decide the behaviour when a version exists remotely with different bytes. The answer should be
   "fail", and it should be written down as a decision rather than assumed.

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
