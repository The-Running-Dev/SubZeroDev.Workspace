# SubZeroDev Repository Plugin

Creates a GitHub repository from a directory, and holds it to a stated configuration afterwards.

| Field     | Value                                    |
| --------- | ---------------------------------------- |
| Plugin ID | `subzerodev.repository`                  |
| CLI       | `subzerodev-repository`, alias `sz-repo` |
| Status    | Specified, not implemented               |

## Contents

| Document                  | Covers                                                      |
| ------------------------- | ----------------------------------------------------------- |
| `25-repository-plugin.md` | Purpose, commands, inference, settings, and what it governs |

## What it does

Point it at a directory. It works out the repository name from the directory, the description from
the README's first prose line, the topics from the stack it detects, and the required status checks
from the job names in `.github/workflows/`. Anything it cannot infer comes from a `.settings` or
`.settings.json` file beside the directory.

Then it shows you the diff and waits.

```bash
sz-repo plan  --path ./SubZeroDev.MCP     # read-only; prints the diff and a plan token
sz-repo apply --plan-id 7f3c9a12b8e04d65  # takes the token and nothing else
```

Nothing reaches GitHub without a human seeing the specific change first. Creating a repository is
effectively permanent once anyone clones, forks, or links it, and a ruleset that fails to apply fails
silently — so the approval is structural rather than a documented convention.

## Why it is separate from the GitHub plugin

The GitHub plugin reads; this one writes. Keeping them apart is mostly about **least privilege**: the
GitHub plugin needs read scopes and runs continuously, while provisioning needs repository
administration and runs once per repository. Folded together, the plugin that runs every hour would
declare administration capability it never uses — and in a model where the manifest declaration _is_
the grant, that turns the capability system into paperwork.

They do share the GitHub client — Octokit construction, the request wrapper, rate limits, retries,
redaction. Sharing the transport is not the same as sharing the blast radius.

## What it does not do

Not deletion, not archival, not collaborators, teams, secrets, or transfers — each is a separate
access-control surface. Not the local project either: `setup-llm/scripts/setup-project.ps1` already
builds the directory, files, and first commit. This starts at the remote, which is the step the
existing tooling stops short of.

## Status

Specification only. Two open questions, both recorded with recommendations: whether other forges are
in scope, and whether rulesets become a named shared policy rather than being restated per
repository.
