# SubZeroDev.GitHub Plugin

## Purpose

Collect GitHub repository and activity metadata for the authenticated user and transform it into a stable provider-independent project model.

The plugin must run manually before Automator integration.

## Technology

- Node.js
- TypeScript
- Octokit
- Zod or equivalent schema validation
- structured logging
- Vitest
- Docker image
- JSON and YAML outputs

## CLI

```text
subzerodev-github sync
subzerodev-github list
subzerodev-github stats
subzerodev-github export
subzerodev-github validate
subzerodev-github manifest
```

`subzerodev-github` is canonical; `sz-github` is a convenience alias for interactive use. The
introspection command is `manifest`, per the plugin contract — not `describe`.

## Authentication

Phase One reads the token from the `GITHUB_TOKEN` environment variable. The configuration file may
name a _different variable to read from_; it may never carry a token value, and the configuration
schema must be incapable of representing one.

The original wording — "configuration reference" — was ambiguous between naming a variable and
storing a token. It means the former. A schema that cannot hold a token is a stronger guarantee than
a rule against logging one, because it also rules out the token reaching the cache, the exported
documents, an error message, or a crash dump.

GitHub CLI token reuse (`gh auth token`) is **opt-in and recorded in the run report**, never a
silent fallback. It inherits whatever scopes the user's `gh` session holds, which is usually far
broader than the read access this plugin needs, so it widens the plugin's access beyond what the
manifest declared.

Future: GitHub App, OAuth.

The token must never appear in output, logs, artifacts, the cache, or error messages.

## Repository scope

Configurable:

- owned repositories
- organization repositories
- contributed repositories
- public/private
- forks
- archived
- disabled
- templates

Recommended default Phase One:

- repositories owned by authenticated user
- include public and private
- include archived
- exclude forks by default, configurable
- contributed repositories deferred unless reliable ownership/contribution rules are defined

An earlier draft said forks were excluded from the portfolio summary but retained in raw collection.
That is a different and more expensive behavior — collecting a repository costs API budget whether or
not it reaches the summary — and it contradicts ADR-0002. Excluding by default is the decision; a
configuration flag turns collection on for anyone who wants forks in the raw set.

## Collected repository metadata

- provider
- provider repository ID
- node ID
- owner
- name
- full name
- description
- visibility
- private
- fork
- archived
- disabled
- template
- created
- updated
- pushed
- default branch
- homepage
- documentation URL, inferred or custom
- clone URL
- SSH URL
- web URL
- topics
- license
- primary language
- language distribution
- size
- stars
- forks
- watchers
- open issues
- discussions enabled
- wiki enabled
- projects enabled
- pages enabled
- latest release
- tags
- branch count
- contributor summary
- pull-request summary
- issue summary

### Capability flags are only what GitHub exposes

The REST repository object provides `has_issues`, `has_projects`, `has_wiki`, `has_pages`,
`has_downloads`, and `has_discussions`. There is **no `has_packages` and no `has_releases`**, so
neither is collected, and neither may be synthesized by probing an endpoint and inferring a flag
from the response. An earlier draft listed both; they were removed rather than faked.

### Counting semantics

Several statistics are easy to collect incorrectly in ways that yield a plausible wrong number
rather than an error:

- **`open_issues_count` includes pull requests.** It is not the open-issue count.
- **Closed issue and pull-request counts need the Search API**, which uses a rate-limit bucket
  separate from the primary one and is eventually consistent — so two syncs of unchanged data can
  legitimately disagree, and that must not be recorded as a change.
- **Contributor lists are capped by GitHub** and exclude anonymous contributors, so contributor data
  carries a truncation flag.
- **Commit count** comes from requesting a single-item commit page and reading the last page number
  from the `Link` header, at one request per repository. Null when the header is absent, as for an
  empty repository.
- **`/stats/*` answers `202` with no body** while GitHub computes the result, requiring a bounded
  retry and a give-up path to null.
- **An uncollectable statistic is null with a diagnostic, never zero.** A repository with no commits
  and one whose commit count could not be read are different facts.

## Cost controls

Some statistics require expensive API calls.

The plugin should use collection profiles:

### Basic

Repository endpoint data only.

### Standard

Basic plus languages, latest release, branch count, tag count.

### Detailed

Standard plus contributors, PR counts, issue counts, commit/activity statistics.

## Normalized project model

The public output must not mirror Octokit response shapes.

Example:

Identity is the immutable provider repository ID, namespaced by provider. `slug` is mutable display
metadata and is never a key — not for the cache, not for portfolio overrides, not for tie-breaking.
`status` is derived, not collected: `archived` when GitHub reports the repository archived,
otherwise `active`. Any user-facing status override belongs in portfolio overrides.

```json
{
  "schemaVersion": "1.0.0",
  "provider": "github",
  "providerId": "123",
  "slug": "the-running-dev/project",
  "name": "Project",
  "description": "...",
  "visibility": "public",
  "status": "active",
  "source": {
    "url": "...",
    "defaultBranch": "main"
  },
  "timestamps": {
    "createdAt": "...",
    "updatedAt": "...",
    "pushedAt": "..."
  },
  "technology": {
    "primaryLanguage": "TypeScript",
    "languages": []
  },
  "statistics": {},
  "releases": {},
  "portfolio": {}
}
```

## Portfolio overrides

Allow a local overrides file **keyed by the immutable provider repository ID**, not by slug.

`owner/name` is mutable: renaming or transferring a repository would silently detach every
hand-written override from it, which is the same identity failure that makes cache reconciliation
impossible. The file may carry the slug alongside the ID as a human-readable comment, but the ID is
what matches.

Fields:

- featured
- hidden
- display name
- summary
- category
- status
- display order
- custom technologies
- demo URL
- docs URL
- screenshots
- business relevance
- personal contribution
- start/end dates
- notes

GitHub data remains source metadata; portfolio overrides remain user-owned metadata.

## Output

```text
output/
  projects.json
  projects.yaml
  summary.json
  statistics.json
  sync-report.json
  raw/, optional
```

## Caching

- ETag support
- last synchronization timestamp
- per-repository cache
- API version metadata
- retry-after handling
- partial failure tracking

## Determinism

Given identical API data and overrides, output ordering and serialization must be deterministic.

## Partial success

One repository failure should not necessarily invalidate all results.

The final report distinguishes:

- succeeded
- partially succeeded
- failed

## Plugin manifest command mapping

Commands exposed to Automator later:

- sync
- export
- validate
- stats

`list` may remain CLI-only unless useful remotely.

## Phase One acceptance criteria

- authenticates with token
- discovers configured repository scope
- collects Basic and Standard profiles
- normalizes data
- writes JSON and YAML
- supports deterministic output
- handles rate limiting
- runs natively with Node
- runs through Docker
- includes tests and documentation
