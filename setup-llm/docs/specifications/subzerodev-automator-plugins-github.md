# SubZeroDev.Automator.Plugins.GitHub Project Specification

| Field                   | Value                                                                       |
| ----------------------- | --------------------------------------------------------------------------- |
| Version                 | 1.1                                                                         |
| Status                  | Phase One — implementation started                                          |
| Language                | TypeScript                                                                  |
| Runtime                 | Node.js 24+                                                                 |
| GitHub library          | Octokit                                                                     |
| Hosting decision        | [ADR-0001](../decisions/0001-subzerodev-automator-github-plugin-hosting.md) |
| Boundary decisions      | [ADR-0002](../decisions/0002-github-plugin-phase-one-boundaries.md)         |
| Implementation sequence | `plugins/SubZeroDev.Automator.Plugins.GitHub/IMPLEMENTATION_PLAN.md`        |

This document defines _what_ Phase One is. The implementation plan defines the
order it is built in, and the ADRs record _why_ each boundary was drawn where it
was. Where this document and an ADR disagree, the ADR is correct and this
document has drifted.

## Vision

SubZeroDev.Automator.Plugins.GitHub is a standalone GitHub integration plugin that provides a
normalized representation of GitHub repositories, projects, and development
activity.

Its primary responsibility is to gather repository metadata and statistics and
expose them through a simple object model for downstream consumers.

The plugin must execute independently from any automation runtime. It may later
become a plugin for SubZeroDev.Automator, but no automation framework may be
required.

## Phase One Hosting Decision

SubZeroDev.Automator.Plugins.GitHub is implemented as an in-repository plugin at
`plugins/SubZeroDev.Automator.Plugins.GitHub`. Its first runner is a standalone CLI. Automator
integration is explicitly deferred and must later consume the same public
plugin contracts rather than becoming a dependency of the plugin.

## Primary Goal

Create a local representation of every repository belonging to, or contributed
to by, the authenticated GitHub user.

The plugin should become the single source of truth for portfolio data. Future
systems should consume the normalized project model produced by this plugin
rather than querying GitHub directly.

**Phase One delivers only the first half of that goal: repositories owned by the
authenticated user.** Contributed repositories, organization repositories, and
forks-of-others are the eventual target but are out of scope until the owned path
is stable, because they need a different discovery strategy and a much larger API
budget. The goal above describes the destination; the Repository Discovery section
below is binding for what gets built now.

## Philosophy and Design Principles

GitHub is an external provider. Everything returned by GitHub must be
transformed into internal models, and the GitHub API must not leak outside the
provider implementation. Future providers such as GitLab, Azure DevOps, and
Bitbucket should be capable of producing the same models.

The design principles are:

- API first
- Provider independent
- Cache first
- Incremental synchronization
- Strongly typed
- Deterministic
- Portable
- Self-hosted

## Technology

- Node.js 24+
- TypeScript
- Octokit
- Zod
- Pino
- YAML and JSON
- Vitest
- Docker

## Proposed Project Structure

```text
src/
├── providers/
│   └── github/
├── contracts/
├── commands/
├── models/
├── services/
├── cache/
├── serialization/
├── configuration/
├── logging/
└── output/
tests/
```

`contracts/` holds the cache, clock, logger, and serializer interfaces that
services depend on. `logging/` holds the Pino adapter and its redaction rules.
Both exist so that no service imports a concrete filesystem or GitHub type.

## Phase One Commands

| Command           | Purpose                                                |
| ----------------- | ------------------------------------------------------ |
| `github sync`     | Download and incrementally update repository metadata. |
| `github list`     | Display repositories.                                  |
| `github stats`    | Display aggregate statistics.                          |
| `github export`   | Export normalized data.                                |
| `github validate` | Validate configuration and cached data.                |

## Authentication

Phase One reads a GitHub personal access token from an environment variable,
`GITHUB_TOKEN` by default. The configuration file may name a different variable
to read from; it may never carry the token value itself.

The configuration schema must be incapable of representing a raw token, so that
committing a config file cannot leak a credential. This is stricter than "do not
log tokens": a token that the schema cannot hold is one that cannot reach the
cache, the exported documents, an error message, or a crash dump.

Resolution order for every setting except the token is: command-line option,
environment override, configuration file, then default. The token has no such
chain — it comes from the environment only.

GitHub App and OAuth authentication are future options.

## Synchronization

- Initial synchronization downloads all data in scope.
- Subsequent synchronizations should be incremental.
- Avoid unnecessary API calls.
- Respect rate limits, including the separate bucket used by the Search API.
- Track timestamps and ETags.
- Handle partial synchronization without corrupting the last valid cache.
- A GraphQL transport is a future capability. Phase One uses REST throughout.

Two synchronizations of unchanged data must produce identical canonical output.
"Avoid unnecessary API calls" is measured rather than asserted: the request count
is observable, and an unchanged resync is expected to fall to near-zero primary
quota consumption through conditional requests.

## Repository Discovery

Phase One discovers repositories owned by the authenticated user.

Supported repository classes:

- Public
- Private
- Templates
- Forks, configurable
- Archived repositories, configurable

Repositories contributed to and organization repositories are future scope.

Phase One defaults:

- Forks are excluded unless enabled in configuration.
- Archived repositories are included and clearly flagged.
- Disabled and template repositories are included and clearly flagged.
- Organization and contributed repositories are deferred.

### Repository identity

A repository is identified by GitHub's immutable numeric ID, namespaced by
provider. `owner/name` is mutable metadata and is never used as a key.

This is load-bearing rather than a detail. Keyed on `owner/name`, a rename or a
transfer is indistinguishable from a deletion followed by an addition, so the
cache would discard history and re-fetch the whole repository every time one is
renamed. Every future provider must supply an equivalently stable identifier.

## Repository Metadata

Collect:

- Repository ID and node ID
- Name, owner, and description
- Visibility
- Topics
- Homepage
- License
- Primary language and language breakdown
- Default branch
- Created, updated, and pushed dates
- Size
- Stars, forks, and watchers
- Open issue count, excluding pull requests
- Archived, disabled, and template flags
- Wiki, discussions, projects, issues, and pages capability flags
- Clone, SSH, and HTML URLs

Capability flags are mapped only where GitHub exposes them directly on the
repository object: `has_issues`, `has_projects`, `has_wiki`, `has_pages`,
`has_downloads`, and `has_discussions`. There is no `has_releases` and no
`has_packages`, so neither is collected and neither may be synthesized by probing
an endpoint and inferring a flag from the response.

## Repository Statistics

Collect:

- Commit count
- Release count
- Tag count
- Branch count
- Contributors
- Open and closed pull requests
- Open and closed issues
- Latest release
- Latest tag

### Counting semantics

Several of these are easy to collect incorrectly, in ways that produce a
plausible wrong number rather than an error. Phase One binds them:

- **Commit count** comes from requesting a single-item commit page and reading
  the last page number from the `Link` header, at one request per repository. It
  is null when the header is absent, which is the case for an empty repository.
- **Issue counts exclude pull requests.** GitHub's `open_issues_count` on the
  repository object counts both, so it is not the open-issue count and must not
  be used as one.
- **Closed issue and pull-request counts** require the Search API, which uses a
  rate-limit bucket separate from the primary one and is eventually consistent.
  It can return different totals for two syncs of unchanged data, so a
  disagreement between consecutive syncs is expected and must not be treated as a
  change.
- **Contributor lists are truncated by GitHub** and exclude anonymous
  contributors by default. Contributor data therefore carries a truncation flag,
  so a partial list is never presented as a complete one.
- **Any statistic that cannot be collected is null with a diagnostic**, never a
  zero. A zero commit count and an uncollectable commit count are different
  facts.

Future statistics include traffic, clones, views, and downloads.

## Language Statistics

For each language, collect its name and byte count. Calculate deterministic,
normalized percentages.

Byte counts are the source of truth; percentages are derived. The rounding rule
must be documented and applied identically on every run, and the rounded
percentages must total 100 within the chosen precision — a remainder distributed
by an undefined rule is a source of output churn between otherwise identical
syncs. Languages are ordered deterministically rather than by GitHub's response
order.

## Release Information

Collect:

- Version
- Published date
- Draft and prerelease flags
- Assets
- Release notes URL

## Branch Information

Collect:

- Branch name
- Protected flag
- Default flag
- Last commit

The protected flag is nullable. Branch protection is not readable for every
repository under every token scope and plan, and an unreadable flag is not the
same as an unprotected branch.

Ahead/behind information is future scope.

## Contributor Information

Collect:

- User
- Contribution count
- Profile URL
- Account type
- Truncation flag for the containing list

## Normalized Project Model

The plugin must transform GitHub repositories into a stable internal model:

```text
Project
├── identity        provider-namespaced immutable ID
├── custom          optional, provider-independent portfolio metadata
└── Repository
    ├── Languages
    ├── Releases
    ├── Branches
    ├── Contributors
    ├── Statistics
    └── Metadata
```

GitHub-specific response types must remain inside `providers/github`. Future
providers must populate the same normalized `Project` model.

`custom` carries portfolio data that does not exist in GitHub — display order,
featured and hidden flags, status, stack overrides, demo and blog URLs, priority,
and tags. It is a distinct object rather than fields mixed into the repository
model, so that provider data and hand-authored data never become
indistinguishable, and so a resync cannot overwrite hand-authored values.

### Schema versioning

Every serialized document carries an explicit schema version. All top-level
documents share one version.

A reader accepts a document with the same major version and rejects anything else
with an actionable error. Phase One ships no migration mechanism: below `1.0.0`,
an incompatible document is regenerated by re-running `export`, not upgraded.
Documentation must state this plainly rather than implying an upgrade path
exists.

## Output

Phase One supports JSON and YAML. Markdown and SQLite are future formats.

JSON output:

- `projects.json`
- `projects.schema.json`
- `statistics.json`
- `summary.json`

YAML output:

- `projects.yaml`

Output is consolidated: one canonical document per concern, covering every
project. Per-repository output files are future scope.

The summary should include:

- Total, public, private, and archived project counts
- Languages
- Stars, forks, and releases
- Largest repository
- Most active repository
- Newest repository
- Oldest repository

### Summary determinism

"Largest" and "most active" are opinions until they are defined, and an
undefined selection produces a summary that changes between runs over unchanged
data. Phase One binds each one, and every selection breaks ties by ascending
repository identity so the result is reproducible:

| Selection   | Definition                        |
| ----------- | --------------------------------- |
| Largest     | Greatest repository size on disk. |
| Most active | Latest `pushedAt`.                |
| Newest      | Latest `createdAt`.               |
| Oldest      | Earliest `createdAt`.             |

An empty project set yields null for each selection rather than an omitted key.

### Serialization rules

- UTF-8, LF line endings, one trailing newline.
- Stable property and collection ordering, so identical input produces
  byte-identical output.
- Absent values are serialized as `null` rather than omitted. A present `null` is
  deterministic and keeps a consumer from having to distinguish "missing" from
  "unknown".
- JSON and YAML represent the same normalized data.
- Each document is replaced by a single atomic rename onto its live path.

## Local Cache

The cache must support incremental updates, timestamp tracking, and ETags.
Phase One atomically replaces the current cache while retaining the last valid
state during failures. Historical snapshots are future scope.

Cache entries are keyed on repository identity, so a rename or transfer updates
an entry rather than orphaning it and creating a second one.

Replacement is performed by writing to a staging location and then renaming each
file onto its live path. Directory replacement is not used: it is not atomic on
Windows and fails outright when the destination directory already exists, and
Windows is a supported platform.

A conditional request answered with `304 Not Modified` does not consume primary
rate-limit quota. That is what makes the cache worth its complexity, and it is
why an unchanged resync should approach zero quota consumption rather than merely
fewer requests.

## Logging

Use structured logging. The specification's levels map onto Pino as follows:

| Specification | Pino    |
| ------------- | ------- |
| Information   | `info`  |
| Warning       | `warn`  |
| Error         | `error` |
| Debug         | `debug` |
| Verbose       | `trace` |

Redaction applies to authorization headers, known token fields, request errors,
and nested error causes. No log record at any level may contain a token.

## Configuration

The default configuration file is `github.config.json`. It carries its own
version and must cover:

- Authentication — the name of the environment variable to read the token from,
  never a token value
- Cache
- Output
- Repositories — the fork, archived, disabled, private, and template filters
- Rate limits — concurrency and request budget
- Export formats

Relative paths resolve against the configuration file's own location, not the
current working directory, so a config file behaves the same whichever directory
the CLI is invoked from.

Organization settings are deferred along with organization discovery. They are
not present in the Phase One schema, because a setting that is read but not
honored is worse than a missing one.

## Validation

`github validate` checks:

- Configuration — schema, versions, and resolved paths
- Authentication — that the named environment variable is present
- GitHub connectivity — only when explicitly requested, so validation stays
  usable offline
- Output paths — existence and writability
- Cache integrity — manifest version, structure, and identity consistency

Validation reports every problem it finds rather than stopping at the first, so a
misconfigured setup takes one run to diagnose instead of several.

## Error Handling

Handle:

- Authentication failures
- Rate limiting
- Network failures
- GitHub API changes
- Partial synchronization

Failures are distinguishable by exit code, so a caller can react without parsing
output:

| Code | Meaning                               |
| ---- | ------------------------------------- |
| `0`  | Success                               |
| `2`  | Usage or validation error             |
| `3`  | Operational failure                   |
| `4`  | Partial synchronization               |
| `5`  | Authentication or authorization error |
| `6`  | Rate-limited before completion        |

`1` is deliberately unused. Node.js returns it for an uncaught exception, so
leaving it unassigned keeps a crash distinguishable from a handled failure.

A partial synchronization is a distinct outcome rather than a failure: it exits
`4`, retains the last valid cached data for whatever failed, and records
diagnostics naming the affected repositories.

## Docker Support

Provide an official Docker image. Users must be able to mount cache and output
directories and provide the token through an environment variable.

The container runs as a non-root user. Token values are passed by environment
variable at run time and must never be baked into an image layer or appear in
build arguments.

## Future Providers

- GitLab
- Azure DevOps
- Bitbucket
- Gitea
- Forgejo

Each provider must emit the same normalized `Project` model.

## Future Commands

- `github analyze`
- `github portfolio`
- `github activity`
- `github releases`
- `github languages`
- `github roadmap`
- `github graph`
- `github export markdown`
- `github export sqlite`

## Consumers

- Portfolio website
- Resume generator
- Documentation
- Statistics dashboard
- Developer dashboard
- AI analysis
- Project search
- Automator plugin
- MCP server
- REST API

## Phase One Deliverables

- Authentication
- Repository discovery
- Metadata collection
- Statistics collection
- Normalized Project model
- JSON export
- YAML export
- CLI
- Docker image
- Tests
- Documentation

Phase One is complete when every deliverable above exists, every non-goal below
remains absent, no Octokit type appears outside `providers/github`, an unchanged
resync is deterministic and near-free, an interrupted sync leaves the last valid
cache intact, and the documentation takes a new user from token setup through a
validated export.

## Non-Goals

Phase One does not include:

- Web UI
- Database
- Scheduling
- Background services
- Automation runtime
- Workflow engine
- MCP
- REST API

These belong to future projects or phases.

## Resolved Questions

These were open in version 1.0 and are now closed. They are recorded here so the
reasoning is not lost, and in full in ADR-0002.

| Question                                      | Resolution                                                                                                            |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Is commit count worth the extra API calls?    | Yes. The `Link` `rel="last"` technique costs one request per repository, so the original objection no longer applies. |
| Consolidated, per-repository, or both output? | Consolidated only. Per-repository output is future scope.                                                             |
| Should projects support portfolio metadata?   | Yes, as an optional `custom` object kept separate from provider data.                                                 |
| Where does the token live?                    | Environment only. The configuration schema cannot represent one.                                                      |
| How is a repository identified?               | GitHub's immutable numeric ID, namespaced by provider.                                                                |
| Are packages and releases capability flags?   | No. Neither is a repository property, and neither is synthesized.                                                     |

## Open Questions

### Statistics

- Should commit activity be grouped by week, month, or year? Phase One collects
  no activity series, so this stays open until one is needed.

### AI and Assets

- Should future AI-generated summaries be stored with each project or generated
  dynamically?
- Should screenshots, logos, and badges be managed by this plugin or remain
  external?

Both are future-phase questions. Neither blocks Phase One, because `custom` gives
either answer somewhere to live without a schema change.
