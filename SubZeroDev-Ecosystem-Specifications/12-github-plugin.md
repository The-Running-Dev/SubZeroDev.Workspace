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
sz-github sync
sz-github list
sz-github stats
sz-github export
sz-github validate
sz-github describe
```

## Authentication

Phase One:

- `GITHUB_TOKEN`
- configuration reference
- GitHub CLI token reuse, optional

Future:

- GitHub App
- OAuth

The token must never be written to output or logs.

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
- exclude forks from portfolio summary but retain them in raw collection
- contributed repositories deferred unless reliable ownership/contribution rules are defined

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
- packages indicator
- releases indicator
- latest release
- tags
- branch count
- contributor summary
- pull-request summary
- issue summary

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

```json
{
  "schemaVersion": "1.0",
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

Allow a local overrides file keyed by stable repository slug.

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
