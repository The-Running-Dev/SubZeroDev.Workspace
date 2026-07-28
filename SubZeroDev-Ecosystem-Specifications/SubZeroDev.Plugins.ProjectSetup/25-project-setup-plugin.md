# Project Setup Plugin

| Field       | Value                                               |
| ----------- | --------------------------------------------------- |
| Plugin ID   | `subzerodev.project-setup`                          |
| CLI         | `subzerodev-project-setup`, alias `sz-setup`        |
| Status      | Specified. **Name provisional** — see naming, below |
| Destination | Its own repository                                  |
| Language    | Node, sharing the GitHub client with `12`           |
| Supersedes  | `setup-llm/scripts/setup-project.ps1`               |

## Purpose

Take a project from nothing to a working repository: the directory and its files, the agent and
contributor instructions, the git history, the remote, and the rules protecting it.

It infers what it can from what is already there, takes the rest from a settings file, and asks for
approval exactly once — before the half that cannot be undone.

## Two halves, and only one needs a gate

This is the decision the rest follows from.

**Local scaffolding is reversible.** A directory you did not want is a directory you delete. Files
you did not want are one `git checkout` away. Generating structure, a `.gitignore`, a README, and
agent instructions needs no approval ceremony, and putting one there trains people to click through
it — which is how the gate that matters stops being read.

**The remote is not reversible.** A repository name is effectively permanent the moment anyone
clones, forks, or links it. Visibility set wrong is a disclosure. A ruleset that fails to apply fails
_silently_: the branch looks protected and is not, and nobody finds out until the day it mattered.

So the gate sits on the boundary between the halves, not around the whole run.

| Command    | Half              | Gated                                                 |
| ---------- | ----------------- | ----------------------------------------------------- |
| `scaffold` | Local             | No — reversible; `--force` is the only guard it needs |
| `plan`     | Remote, read-only | Produces the token                                    |
| `apply`    | Remote            | **Takes a plan token and nothing else**               |
| `validate` | Neither           | Settings, inference, and credentials. Writes nothing  |
| `manifest` | Neither           | Required by the contract                              |

`apply` accepts no name, no visibility, no ruleset — nothing that would let it act without a plan a
human saw. It refuses a token that is unknown, expired, already used, or whose fingerprint no longer
matches the observed repository.

**The fingerprint check matters here specifically**, because repository settings are exactly the kind
of thing someone adjusts in the web UI between plan and apply. Applying a stale plan over their change
is worse than refusing.

## What it sets up

### Local

Taken from what `setup-project.ps1` already does, which is the specification for this half:

| Produces                            | From `Setup.psm1`                                   |
| ----------------------------------- | --------------------------------------------------- |
| Directory structure                 | `New-ProjectStructure`, `New-ProjectFile`           |
| `.gitignore`, `.env.example`        | `New-Gitignore`, `New-EnvExample`                   |
| `README.md`, `ARCHITECTURE.md`      | `New-ReadmeFile`, `New-ArchitectureFile`            |
| **`AGENTS.md` and `CLAUDE.md`**     | `New-AgentsInstructions`, `New-ClaudeInstructions`  |
| Language starter files              | `Invoke-LanguageStarter`                            |
| Git initialization and first commit | `Initialize-ProjectGit`, `New-ProjectInitialCommit` |
| Build and test validation           | `Test-ProjectBuildable`, `Test-ProjectTestable`     |

Added, because the existing script does not produce them and this ecosystem needs them:

- **`.gitattributes`** pinning text to LF. Without it `format:check` disagrees across platforms, which
  cost this project a red Windows build before anyone suspected line endings.
- **The `AGENTS.md` conventions block**, with its canonical copy named. Fifteen repositories carry it
  verbatim today because it was hand-copied.

**The instruction pair is the strongest case for this plugin.** Every repository in this ecosystem
needs a `README.md`, an `AGENTS.md` carrying that repository's invariants, and a `CLAUDE.md` pointing
at it. Fifteen sets were written by hand, one at a time. Nothing generates them, which is why the
shared block inside them has to be verified by hash rather than by construction.

### Remote

| Group          | Settings                                                         |
| -------------- | ---------------------------------------------------------------- |
| Identity       | name, description, homepage, topics, visibility                  |
| Features       | issues, wiki, projects, discussions                              |
| Merge strategy | squash, merge commit, rebase, auto-merge, delete branch on merge |
| Protection     | a ruleset on the default branch                                  |
| Wiring         | `origin` remote, default branch, first push                      |

The default ruleset requires a pull request, blocks force pushes, and blocks branch deletion. Required
approvals default to **zero** rather than one: a single-maintainer repository with one required
approval cannot merge anything, and a default that deadlocks the common case gets disabled wholesale
rather than tuned.

Rulesets, not classic branch protection — they are what GitHub reports as `GH013 Repository rule
violations`, they compose, and they are where the platform is going.

## It supersedes `setup-project.ps1`

That script and its `Setup.psm1` do the local half well. They stop there: there is no remote creation
anywhere in them, so a project set up by that script has a local git repository and nowhere to push
it. That gap is what this plugin was asked for, and closing it by adding a remote step to the script
would leave two tools each claiming to set up a project — the ambiguity this ecosystem keeps having to
fix.

So this is the script's successor, and it takes the script's behaviour as its specification for the
local half rather than inventing a second one.

**The script is not deleted on the plugin's first release.** It works, it is in use, and it runs where
there is no container. It becomes the deprecated path once the plugin covers what it covers, and the
retirement is an open question below rather than an assumption.

A PowerShell surface for the plugin comes from ContainerPSGenerator, which exists to generate exactly
that. The PowerShell instinct was right about the interface and wrong about the implementation.

## Why this is not a command on the GitHub plugin

The obvious home was `12-github-plugin.md` — it already speaks GitHub and has Octokit with retries and
redaction. Four things say otherwise, and the third is decisive.

**Direction.** `12` is a reader; its stated purpose is to collect and normalize metadata and be "the
single source of truth for portfolio data". Every command it has reads.

**Blast radius.** The worst failure of `12` is a stale cache. The worst failure here is a public
repository that should have been private. Those should not share an approval model.

**Least privilege, which settles it.** `12` needs read scopes. This needs administration write. Fold
them together and the collection plugin declares repository-administration capability it never
exercises, on every run, forever. In a model where the manifest declaration _is_ the grant, that turns
the capability system into paperwork — on the plugin with the most run-time exposure.

**Lifecycle.** `sync` runs on a schedule. `apply` runs once per project, ever.

## What it reuses

**The GitHub client**, not a second implementation: Octokit construction from the environment token,
the request wrapper, ETags, rate-limit capture, retry classification, redaction. That component now
has four candidate consumers; see the open-questions register for the revised position.

**Stack detection belongs to the build plugin.** Inferring a language starter or a topic from
`package.json` or `*.csproj` is the same detection the build plugin needs for adapter selection, and
`SubZeroDev.Ecosystem/15-pipeline-composition.md` already decided a second implementation would drift
on what counts as a Node project. This plugin consumes it once the build plugin exists, and carries a
minimal version until then — a known debt, not a rediscovery.

**From the contract**, referenced rather than restated: plan-apply, exit codes, the result envelope,
secret handling, serialization, and the manifest.

## Inference

The value is in what you do not have to write down.

| Inferred               | From                                                                                  |
| ---------------------- | ------------------------------------------------------------------------------------- |
| Repository name        | The directory's leaf name                                                             |
| Description            | The first prose line of `README.md`, truncated to GitHub's 350                        |
| Owner                  | The `origin` remote if the directory is a clone, else the authenticated user          |
| Language and starters  | Detected stack — `package.json`, `pyproject.toml`, `*.csproj`, `Dockerfile`, `*.psm1` |
| Topics                 | The same detection                                                                    |
| License                | The SPDX identifier implied by a `LICENSE` file                                       |
| Required status checks | **Job names parsed from `.github/workflows/`**                                        |
| Default branch         | `main`, or the checked-out branch if the directory is a clone                         |

Two are never inferred silently, because a wrong guess is unsafe rather than merely noisy.

**Visibility.** A wrong guess is a disclosure or an obstruction. The plugin proposes a value from the
owner's other repositories, states the reason in the rendering, marks a proposed public repository
unmissably, and lets the apply gate be the confirmation.

**Required status checks.** Only ever a check that a workflow in the directory actually produces. A
required check nothing produces blocks every pull request permanently and presents as a GitHub outage
rather than a configuration error.

## Settings

Two forms, because they serve different moments:

- **`.settings`** — `key = value`, `#` comments, comma-separated lists. For correcting one field
  without holding JSON syntax in your head.
- **`.settings.json`** — for anything nested: ruleset shape, per-branch rules, check lists, the
  file-generation manifest.

Both optional, and they may coexist. Resolution follows the contract's configuration precedence — CLI
option, environment variable, settings file, inferred value, built-in default — with JSON taking
precedence over text where both define a key, because JSON is the form that can express the nested
settings and is therefore the more likely to be authoritative.

Paths inside a settings file resolve relative to that file, per the contract.

## Naming

**This plugin's name is provisional, and so are the others'.** The ecosystem has no naming convention
for plugins: `GitHub` and `Docker` name a provider, `Backlog` and `Package` and `Release` name a
domain object, `Build` names an activity, and `ProjectSetup` and `ContainerPSGenerator` are compounds.
Each was reasonable on its own and no rule connects them.

That is worth settling **before first publish and not after**. ADR-002 in the Architecture repository
already makes the argument for identifiers generally: a package identifier is effectively permanent
once consumers depend on it, so a rename means deprecating, republishing, and breaking everyone who
did not follow. Nothing has published yet, so the cost of settling this is currently zero.

Tracked as an open question in the register, with the whole set in scope rather than this plugin
alone.

## Non-goals

**Deleting or archiving repositories.** Setup creates and configures. Destruction has a different
approval shape and does not belong behind the same token.

**Transferring ownership, managing collaborators or teams, and secrets or variables.** Each is a
separate access-control surface with its own blast radius; grouping them here would widen the
capability grant far past what setup needs.

**Workstation setup.** Installing tooling, MCP servers, and operating-system dependencies stays in
`setup-llm`. That is a machine concern, not a project one, and it is the half of that toolkit this
plugin does not supersede.

## Acceptance

- A bare directory name produces a complete local project and a complete remote plan, with no
  settings file present
- `scaffold` needs no plan token, and `apply` cannot run without one
- The plan renders every remote action in terms a human can check, and a proposed public repository is
  unmissable in it
- `apply` refuses an unknown, expired, reused, or stale-fingerprint token, with a distinct message for
  each
- A project already matching its settings plans zero actions
- Generated `AGENTS.md` and `CLAUDE.md` match the shape this ecosystem's repositories already carry,
  including the shared conventions block
- A partial application exits `4`, names which actions succeeded, and consumes the plan
- No token appears in output, logs, errors, or the plan file

## Open questions

1. **When is `setup-project.ps1` retired, and does anything migrate?** It works and runs where there
   is no container. Recommended: deprecate on this plugin's first release, delete once the plugin has
   set up one real project end to end.
2. Does the remote half cover GitLab, Gitea, and Forgejo behind the provider boundary the Release
   plugin and WorkItems both anticipate, or is it GitHub-only until a second forge is wanted? The
   narrower reading is recommended.
3. Should a ruleset be a named, reusable policy shared across repositories rather than restated in
   each settings file? Fifteen repositories sharing one policy is the immediate case, and restating it
   fifteen times is the drift this project keeps fixing.
4. Are the generated `AGENTS.md` and `CLAUDE.md` templated per repository kind, or generated from one
   source that would let the shared conventions block be checked rather than hand-copied? The second
   is the more useful answer and the larger piece of work. Related to X13.
