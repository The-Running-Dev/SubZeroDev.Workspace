# SubZeroDev Project Setup Plugin

Takes a project from nothing to a working repository: the directory and its files, the agent and
contributor instructions, the git history, the remote, and the rules protecting it.

Successor to `setup-llm/scripts/setup-project.ps1`, which does the local half and stops short of the
remote.

| Field     | Value                                        |
| --------- | -------------------------------------------- |
| Plugin ID | `subzerodev.project-setup`                   |
| CLI       | `subzerodev-project-setup`, alias `sz-setup` |
| Status    | Specified, not implemented                   |

## Contents

| Document                     | Covers                                                      |
| ---------------------------- | ----------------------------------------------------------- |
| `25-project-setup-plugin.md` | Purpose, commands, inference, settings, and what it governs |

## What it does

Point it at a directory. It works out the repository name from the directory, the description from
the README's first prose line, the topics from the stack it detects, and the required status checks
from the job names in `.github/workflows/`. Anything it cannot infer comes from a `.settings` or
`.settings.json` file beside the directory.

Then it shows you the diff and waits.

```bash
sz-setup plan  --path ./SubZeroDev.MCP     # read-only; prints the diff and a plan token
sz-setup apply --plan-id 7f3c9a12b8e04d65  # takes the token and nothing else
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

## Two halves, one gate

Local scaffolding is reversible — a directory you did not want is a directory you delete — so
`scaffold` needs no approval. The remote is not: a name is permanent once anyone links it, and a
ruleset that fails to apply fails silently. So `plan` and `apply` gate that half and only that half.
Putting a ceremony around the reversible part is how the gate that matters stops being read.

## What it does not do

Not deletion, not archival, not collaborators, teams, secrets, or transfers — each is a separate
access-control surface. Not workstation setup either: installing tooling, MCP servers, and OS
dependencies stays in `setup-llm`, which is a machine concern rather than a project one.

## Status

Specification only. Four open questions, each recorded with a recommendation: when the PowerShell
script is retired, whether other forges are in scope, whether rulesets become a named shared policy,
and how the generated instruction files are produced.

**The name is provisional.** The ecosystem has no plugin naming convention — some plugins are named
for a provider, some for a domain object, some for an activity — and settling that is free only until
the first package publishes. Question 0 in the register.
