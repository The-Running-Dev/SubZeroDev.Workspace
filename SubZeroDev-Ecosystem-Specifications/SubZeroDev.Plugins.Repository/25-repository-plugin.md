# Repository Plugin

| Field       | Value                                     |
| ----------- | ----------------------------------------- |
| Plugin ID   | `subzerodev.repository`                   |
| CLI         | `subzerodev-repository`, alias `sz-repo`  |
| Status      | Specified                                 |
| Destination | Its own repository                        |
| Language    | Node, sharing the GitHub client with `12` |

## Purpose

Create a repository from a directory, and hold it to a stated configuration afterwards: description,
topics, homepage, merge strategies, and the rules protecting its default branch.

It infers what it can from the directory it is pointed at, takes the rest from a settings file, shows
the difference, and applies only what a human has seen.

## Why this is not a command on the GitHub plugin

The obvious home was `12-github-plugin.md` — it already speaks GitHub, already has Octokit, and
already has a request wrapper with retries and redaction. Four things say otherwise, and the third is
decisive.

**Direction.** `12` is a reader. Its stated purpose is to collect and normalize metadata and be "the
single source of truth for portfolio data". Every command it has reads. A command that creates
repositories and rewrites branch rules makes it both, and its Phase One boundaries were drawn around
collection.

**Blast radius.** The worst failure of `12` is a stale cache. The worst failure here is a public
repository that should have been private, or protection silently not applied to a branch everyone
believes is protected. Those are not the same class of thing and should not share an approval model —
one needs plan-apply, the other needs nothing.

**Least privilege, which settles it.** `12` needs read scopes. This needs administration write. Fold
them together and the collection plugin's manifest declares repository-administration capability it
never exercises, on every run, forever. The whole point of declaring capabilities in the manifest is
that the declaration is the grant; a plugin that declares more than it uses turns the capability model
into paperwork. Keeping them separate keeps `12` least-privileged, which matters more because `12` is
the one that runs continuously.

**Lifecycle.** `sync` runs on a schedule. `apply` runs once per repository, ever.

## What it reuses

Everything except the domain. This plugin does not reimplement GitHub access — it consumes the
**shared GitHub client** described in `SubZeroDev.Ecosystem/19-open-questions.md`, which is the same
component `12` and the Release plugin need: Octokit construction from the environment token, the
central request wrapper, ETags, rate-limit capture, retry classification, and redaction.

That component now has four candidate consumers rather than the two that made "leave it unshared" a
defensible answer. See the open-questions register for the revised position and the language boundary
that constrains it.

It also reuses, rather than restates: the plan-apply pattern, the exit-code table, the result
envelope, secret handling, serialization, and the manifest — all from `SubZeroDev.PluginContract`.

## Commands

| Command    | Purpose                                                                |
| ---------- | ---------------------------------------------------------------------- |
| `plan`     | Inspect a directory and the live repository; compute and render a diff |
| `apply`    | Execute a plan. Takes a plan token and nothing else                    |
| `validate` | Check settings, inference, and credentials. Contacts nothing writable  |
| `manifest` | Print the plugin manifest — required by the contract                   |

`plan` is read-only and returns the contract's top-level `plan` block: an opaque single-use token, a
TTL, a fingerprint of the observed state, and the rendering a human reviews.

`apply` accepts **only** the token. No name, no visibility, no ruleset — nothing that would let it act
without a plan. It refuses a token that is unknown, expired, already used, or whose fingerprint no
longer matches.

**The fingerprint check is the one that matters here.** Between plan and apply someone may have
changed the repository in the web UI. Applying a stale plan over their change is worse than refusing,
and repository settings are exactly the kind of thing people change by hand.

## Inference

The plugin's value is in what you do not have to write down. From a directory:

| Inferred               | From                                                                                  |
| ---------------------- | ------------------------------------------------------------------------------------- |
| Repository name        | The directory's leaf name                                                             |
| Description            | The first prose line of `README.md`, truncated to GitHub's 350                        |
| Owner                  | The `origin` remote if the directory is a clone, else the authenticated user          |
| Topics                 | Detected stack — `package.json`, `pyproject.toml`, `*.csproj`, `Dockerfile`, `*.psm1` |
| License                | The SPDX identifier implied by a `LICENSE` file                                       |
| Required status checks | **Job names parsed from `.github/workflows/`**                                        |
| Default branch         | `main`, or the checked-out branch if the directory is a clone                         |

**Required checks are inferred from workflows that exist**, never assumed. A required check whose
name no workflow produces blocks every pull request permanently and presents as a GitHub outage
rather than as a configuration error. Inferring from the workflow files is the only way to get this
right without the operator hand-copying job names.

**Visibility is never inferred silently.** A wrong guess is either a disclosure or an obstruction, and
neither default is safe. The plugin proposes a value from the owner's other repositories, states the
reason in the rendering, and marks a proposed public repository prominently. The apply gate is where
that gets confirmed — which is one of the reasons the gate exists.

## Settings

A settings file supplies what inference cannot and overrides what it gets wrong. Two forms, because
they serve different moments:

- **`.settings`** — `key = value`, `#` comments, comma-separated lists. For correcting one field
  quickly without holding JSON syntax in your head.
- **`.settings.json`** — for anything nested: ruleset shape, per-branch rules, check lists.

Both are optional and may coexist. Resolution follows the contract's configuration precedence — CLI
option, environment variable, settings file, inferred value, built-in default — with JSON taking
precedence over text where both define a key, because JSON is the form that can express the nested
settings and is therefore the more likely to be authoritative.

Paths inside a settings file resolve relative to that file, per the contract.

## What it governs

| Group          | Settings                                                         |
| -------------- | ---------------------------------------------------------------- |
| Identity       | name, description, homepage, topics, visibility                  |
| Features       | issues, wiki, projects, discussions                              |
| Merge strategy | squash, merge commit, rebase, auto-merge, delete branch on merge |
| Protection     | a ruleset on the default branch                                  |
| Seed           | `README.md` and `.gitignore` where the repository is empty       |

The default ruleset requires a pull request, blocks force pushes, and blocks branch deletion. Required
approvals default to **zero** rather than one: a single-maintainer repository with one required
approval cannot merge anything, and a default that deadlocks the common case gets disabled wholesale
rather than tuned.

Rulesets, not classic branch protection. Rulesets are what GitHub reports as `GH013 Repository rule
violations`, they compose, and they are what the platform is moving toward.

## Non-goals

**Deleting or archiving repositories.** Provisioning creates and configures. Destruction has a
different approval shape and does not belong behind the same token.

**Transferring ownership**, **managing collaborators or teams**, and **secrets or variables.** Each is
a separate access-control surface with its own blast radius; grouping them under one plugin's
capability declaration would widen the grant far past what provisioning needs.

**Creating the local project.** `setup-llm/scripts/setup-project.ps1` already builds the directory,
the files, and the first commit. This plugin starts where that stops — at the remote, which is the
step that tooling is missing today.

**Local git operations.** No `git remote add`, no first push. Composition, not absorption.

## Composition

The natural pipeline is local scaffold → remote provision → first push, and each step belongs to a
different tool. Under the Automator that becomes a workflow; from a terminal it is three commands.
Neither requires this plugin to know about the other two.

## The bootstrap order, stated rather than hidden

This plugin provisions repositories, and the fifteen repositories the specifications are destined for
include the one this plugin will live in. It cannot create itself.

The first repositories are therefore created by hand or by an agent with GitHub access, and the plugin
exists for the sixteenth onward and for holding all of them to a stated configuration afterwards.
Reconciling drift is the larger half of its value and is unaffected by the ordering.

## Acceptance

- A directory with a README and workflows plans a complete repository with no settings file present
- The plan renders every action in terms a human can check, and a proposed public repository is
  unmissable in it
- `apply` refuses an unknown, expired, reused, or stale-fingerprint token, with a distinct message
  for each
- A repository that already matches its settings plans zero actions
- A partial application exits `4`, reports which actions succeeded by name, and leaves the plan
  consumed rather than replayable
- No token appears in output, logs, errors, or the plan file
- Required checks are only ever those a workflow in the directory actually produces

## Open questions

1. Does provisioning cover GitLab, Gitea, and Forgejo behind the same provider boundary the Release
   plugin and WorkItems both anticipate, or is it GitHub-only until a second forge is genuinely
   wanted? The narrower reading is recommended: one forge, and a boundary shaped so a second can slot
   in.
2. Should the ruleset be expressible as a named, reusable policy shared across repositories, rather
   than restated in each `.settings.json`? Fifteen repositories sharing one policy is the immediate
   case, and restating it fifteen times is the drift this project keeps fixing.
