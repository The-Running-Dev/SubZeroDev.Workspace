# Working on the Project Setup plugin

Takes a project from nothing to a working repository — local files, instructions, git, remote, rules.
Successor to `setup-llm/scripts/setup-project.ps1`, whose behaviour is the specification for the local
half; do not invent a second one.

**This plugin's name is provisional**, and so are the other plugins'. The ecosystem has no naming
convention and the owner may rename several. Do not build anything that hardcodes the name where a
rename would be expensive.

## Gate the half that cannot be undone, and only that half

Local scaffolding is reversible. Generating a directory, a `.gitignore`, a README, and instruction
files needs no plan token — `scaffold` just does it. Putting an approval ceremony there trains people
to click through, which is how the gate that matters stops being read.

## The remote half is a write nobody can take back

A repository name is effectively permanent once anyone clones, forks, or links it. A ruleset that
does not apply fails **silently** — the branch looks protected and is not, and nobody discovers it
until the day it mattered. Visibility set wrong is a disclosure.

So: **no path reaches GitHub except through an applied plan.** `plan` is read-only and returns the
token; `apply` takes the token and nothing else — no name, no visibility, no ruleset, nothing that
would let it act without a plan a human saw. The fingerprint check is not optional, because
repository settings are exactly the kind of thing people change in the web UI between plan and apply.

If you find yourself adding a convenience flag that skips the plan, that is the signal to stop.

## Least privilege is the reason this plugin exists separately

The GitHub plugin reads and runs continuously. This one needs repository administration and runs once
per repository. Folded together, the continuously-running plugin would declare administration
capability it never uses.

That matters because in this ecosystem **the manifest declaration is the grant**. A plugin declaring
more than it exercises turns the capability model into paperwork, and it does so on the plugin with
the most run-time exposure.

Keep the manifest honest. When you add a command, check whether it widens the declared capability; if
it does, ask whether it belongs in this plugin at all.

## Reuse the client, not the domain

GitHub access — Octokit construction from the environment token, the request wrapper, ETags,
rate-limit capture, retry classification, redaction — comes from the shared client, not from a second
implementation here. Sharing the transport is not sharing the blast radius.

Do not reimplement it, and do not shell out to `gh`. The Backlog plugin's build plan already settled
that with `no gh binary`: it is a runtime dependency that must be separately installed and
authenticated, and it carries whatever scopes the user's session holds, which is usually far more
than the manifest declared.

## Inference has one rule

**Infer aggressively, except where a wrong guess is unsafe.**

Names, descriptions, topics, licences, and default branches are safe to guess — a wrong topic is
noise, and the plan shows it before it lands.

Two are not safe:

- **Visibility.** A wrong guess is a disclosure or an obstruction. Propose a value, state the reason
  in the rendering, mark a proposed public repository unmissably, and let the apply gate be the
  confirmation.
- **Required status checks.** Only ever name a check that a workflow in the directory actually
  produces. A required check nothing produces blocks every pull request permanently and looks like a
  GitHub outage rather than a configuration error.

## Boundaries

Not deletion, not archival, not transfers, not collaborators or teams, not secrets or variables. Each
is a separate access-control surface, and grouping them here would widen the capability grant far past
provisioning.

Not workstation setup. Installing tooling, MCP servers, and OS dependencies stays in `setup-llm` —
that is a machine concern, and it is the half of that toolkit this plugin does not supersede.

Stack detection is not yours either. It is the build plugin's `detect`, per the decision in
`15-pipeline-composition.md`; carry a minimal version until that exists, then consume it.

## Before you finish

- Every write is reachable only through a plan token, and the fingerprint is checked.
- The manifest declares no capability the commands do not exercise.
- No required check is named that no workflow produces.
- A repository already matching its settings plans zero actions.
- No token in output, logs, errors, or the plan file — the plan file especially, since it persists on
  disk between two invocations.

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
