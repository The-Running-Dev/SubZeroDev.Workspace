# SubZeroDev GitHub Plugin

Collects and normalizes GitHub repository metadata into versioned, deterministic documents.

This is the **first** plugin under the SubZeroDev plugin contract, and the reference implementation
the others are scaffolded from.

## Contents

| Path                                    | Covers                                                      |
| --------------------------------------- | ----------------------------------------------------------- |
| `12-github-plugin.md`                   | The specification: scope, model, commands, GitHub's hazards |
| `BUILD-PLAN.md`                         | Milestones 0–8 and the pull-request sequence                |
| `adr/ADR-001-hosting-and-versioning.md` | CLI-first hosting; the rename away from the Automator name  |
| `adr/ADR-002-phase-one-boundaries.md`   | What Phase One includes, and what it deliberately excludes  |
| `reference/`                            | The review that produced the current plan                   |

## What it does

`sync` discovers owned repositories and collects metadata into a local cache; `list`, `stats`, and
`export` read it; `validate` checks configuration and connectivity; `manifest` prints the plugin
manifest.

Output is deterministic: given the same configuration and unchanged upstream data, two runs produce
byte-identical artifacts. That is what lets a consumer detect real change by comparing hashes rather
than re-reading content.

## Run it yourself

The plugin runs standalone. No orchestrator, no host, no service — a token in the environment, a
configuration file, and a terminal:

```bash
export GITHUB_TOKEN=…          # secrets arrive by environment variable, never on the command line
subzerodev-github validate
subzerodev-github sync
subzerodev-github list
```

The Automator can run it later on a schedule, with history and approvals around it. That is an
integration layer, not a prerequisite.

## Identity

A repository's identity is GitHub's **immutable numeric ID**. `owner/name` is mutable metadata. A
rename or a transfer therefore resolves to the same repository rather than to a deletion and a new
arrival.

## Status

Milestone 0 is complete: the package builds, the CLI carries the Phase One command names, and the
full check suite is green on Windows and Linux. The commands intentionally return "not implemented" —
no GitHub API, cache, or export behaviour exists yet.

`BUILD-PLAN.md` says what comes next and in what order.
