# Working on the GitHub plugin

This is the **first** plugin and the template for the rest. Two things follow from that.

**A shortcut taken here gets copied.** The next plugin author will read this repository before
reading the contract. Where the contract says one thing and convenience suggests another, the cost of
the shortcut is multiplied by every plugin that follows.

**Generic decisions do not belong here.** This plugin was specified before the contract existed, so
it accumulated an exit-code table, secret-handling rules, serialization rules, configuration
precedence, and logging levels — every one of which a second plugin faces identically. They were
promoted to the contract by ADR-003, and `adr/ADR-002` here is marked rather than rewritten so the
reasoning survives. Do not push them back down.

## What is GitHub-specific and stays here

Repository scope and filters; identity on GitHub's immutable numeric ID; capability-flag mapping to
GitHub's `has_*` fields; commit count via the `Link` header's `rel="last"` page number; the Search
API's separate rate-limit bucket; collection profiles and their request budgets; summary selection
rules; portfolio overrides.

## Invariants

**Identity is GitHub's immutable numeric ID.** `owner/name` is mutable metadata and never a key. A
cache keyed on the name turns a rename or a transfer into a delete plus an add, which destroys
history and re-fetches everything. Numeric identifiers serialize as **strings** — a 64-bit provider
ID does not survive a round trip through a JSON number in every language.

**No Octokit type escapes `providers/github`.** The domain models are provider-neutral, and the
moment a provider type appears in one, the abstraction is decorative.

**Pino writes to stderr.** It defaults to stdout, which corrupts the envelope and breaks every
adapter at once. This is the single most likely defect in a Node plugin, and it is why the
conformance suite forces `trace` before checking stdout.

**An interrupted write cannot damage the last valid cache.** Stage, then rename per file. Never swap
a directory — it is not atomic on Windows and fails when the destination exists. Verify this on
Windows, not only on Linux.

## GitHub's hazards, which are the real work

These are documented in `12-github-plugin.md` and are the reason the metadata milestone is larger
than it looks:

- The statistics endpoints return `202` while GitHub computes them. A `202` must never reach a caller
  as data.
- The contributor list is capped, so a truncation flag is part of the model rather than an
  afterthought.
- `open_issues_count` includes pull requests. Reporting it as an issue count is wrong and looks
  right.
- The Search API has its own rate-limit bucket, so a budget that counts only core requests is
  incorrect for any command that searches.

## Sequencing

`BUILD-PLAN.md` holds the milestones. **Milestone 3.5 is the de-risking step** and is deliberately
out of dependency order: run `validate → sync → list` against one real account _before_ the expensive
statistics and cache work, so everything after is built against real payloads rather than mocks that
encode the same assumptions as the code.

When reality disagrees with the request budget, correct the budget. Fold every mapping correction
back into the Milestone 1 fixtures.

## Naming

The plugin was originally `SubZeroDev.Automator.Plugins.GitHub`, packaged as
`@subzerodev/automator-plugin-github`. That name asserted the plugin is a component of the Automator,
which the architecture rejects. It is now `SubZeroDev.Plugins.GitHub` and `@subzerodev/plugin-github`
— see the amendment in `adr/ADR-001`. Do not reintroduce the old form.

## Before you finish

- `npm ci && npm run check` green on **both** Windows and Linux. The line-ending policy exists
  because `format:check` disagreed across platforms.
- Secret canary present in no output, log, artifact, cache, error, or image layer.
- An unchanged resync is byte-identical and measurably cheaper, shown by a request count rather than
  by assertion.

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
