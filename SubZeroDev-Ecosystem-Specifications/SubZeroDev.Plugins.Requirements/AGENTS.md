# Working on the Requirements Compiler

Turns requirement documents into a structured, reconcilable work hierarchy, with a language model in
the middle.

## The model is in the loop, so the boundary is the specification

Everything about this plugin that is hard is a consequence of one fact: **a language model produces
its output, and that output is a proposal, not a decision.**

`13-requirements-compiler-plugin.md` has a Human decision boundary section, and it is the most
important section in the document. Treat it as normative rather than as guidance. Concretely:

- **Nothing reaches an external tracker without a human approving the specific diff.** Not "the user
  enabled publishing" — the specific diff, through the contract's plan-apply pattern: an opaque
  single-use token from a read-only compile, a rendering a human reads, and an apply that accepts the
  token and nothing else.
- **A re-run must not silently rewrite what a human already edited.** The fingerprint check exists
  for exactly this. Between compile and publish, someone may have edited an item by hand; applying a
  stale diff over their edit is worse than refusing.
- **Model output is validated before it is trusted.** A schema-invalid or self-contradictory
  compilation is an error, not something to publish and fix later.

## Determinism, honestly

The contract requires that two runs against unchanged input produce byte-identical artifacts. A
language model does not satisfy that.

Do not quietly exempt this plugin. State which artifacts are non-reproducible and why, and apply the
determinism requirement to the **reports** — the contract already provides for this, for compiled
binaries and container images, and it is the same mechanism. The reconciliation output _is_ expected
to be deterministic given the same compiled input; that is what makes a re-run reviewable.

Prompt and model version belong in the output as recorded inputs. A compilation that cannot say which
prompt and which model produced it cannot be reproduced or audited.

## Stable IDs are the load-bearing part

`## Stable IDs` and `## Reconciliation` are where this plugin succeeds or fails. An identifier derived
from a title or a position in a document changes when the document is edited, and every reconciliation
after that reports a deletion and an addition. The work hierarchy then loses its history on the first
reword.

Identity comes from the `SubZeroDev.WorkItems` library, shared with the Backlog plugin so the two
cannot disagree about what a work item is. Do not reimplement the model or the reconciliation here.

## The AI provider is behind a boundary

`## AI provider abstraction` exists so a provider swap is a configuration change. Keep provider types
out of the domain model, the same way the GitHub plugin keeps Octokit types out of its own — an
abstraction that leaks the provider's shapes is decorative.

The provider's credential is a secret and follows the contract: environment variable only, absent
from every log, artifact, error, and image layer.

## The open question

**Whether this plugin publishes directly, or always emits a document and composes with the Backlog
plugin.** Both are defensible; composing keeps a single writer to the tracker, publishing directly is
fewer moving parts. It is unresolved and it shapes the whole repository.

It is recorded here and in `SubZeroDev.WorkItems`, because the answer changes what that library must
support. When answered, record it in both **and** reconcile `19-open-questions.md` in the
Architecture repository, in the same commit.

## Before you finish

- No path publishes without a plan token and a fingerprint check.
- Prompt and model version appear in the output.
- Non-reproducible artifacts are named as such, with the determinism requirement applied to reports.
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
