# SubZeroDev.Automator.Plugins.GitHub Project Specification

| Field | Value |
| --- | --- |
| Version | 1.0 |
| Status | Phase One — implementation started |
| Language | TypeScript |
| Runtime | Node.js 24+ |
| GitHub library | Octokit |

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
├── commands/
├── models/
├── services/
├── cache/
├── serialization/
├── configuration/
└── output/
tests/
```

## Phase One Commands

| Command | Purpose |
| --- | --- |
| `github sync` | Download and incrementally update repository metadata. |
| `github list` | Display repositories. |
| `github stats` | Display aggregate statistics. |
| `github export` | Export normalized data. |
| `github validate` | Validate configuration and cached data. |

## Authentication

Phase One must support a GitHub personal access token supplied through an
environment variable or configuration file.

GitHub App and OAuth authentication are future options.

## Synchronization

- Initial synchronization downloads all data in scope.
- Subsequent synchronizations should be incremental.
- Avoid unnecessary API calls.
- Respect rate limits.
- Track timestamps and ETags.
- Handle partial synchronization without corrupting the last valid cache.
- GraphQL caching is a future capability.

## Repository Discovery

Phase One discovers repositories owned by the authenticated user.

Supported repository classes:

- Public
- Private
- Templates
- Forks, configurable
- Archived repositories, configurable

Repositories contributed to and organization repositories are future scope,
pending the decisions listed under Open Questions.

Phase One defaults:

- Forks are excluded unless enabled in configuration.
- Archived repositories are included and clearly flagged.
- Organization and contributed repositories are deferred.

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
- Open issues
- Archived, disabled, and template flags
- Wiki, discussions, projects, releases, and packages capability flags
- Clone, SSH, and HTML URLs

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

Future statistics include traffic, clones, views, and downloads.

## Language Statistics

For each language, collect its name and byte count. Calculate deterministic,
normalized percentages.

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

Ahead/behind information is future scope.

## Contributor Information

Collect:

- User
- Contribution count
- Profile URL
- Account type

## Normalized Project Model

The plugin must transform GitHub repositories into a stable internal model:

```text
Project
└── Repository
    ├── Languages
    ├── Releases
    ├── Statistics
    └── Metadata
```

GitHub-specific response types must remain inside `providers/github`. Future
providers must populate the same normalized `Project` model.

Every serialized model must carry an explicit schema version.

## Output

Phase One supports JSON and YAML. Markdown and SQLite are future formats.

JSON output:

- `projects.json`
- `projects.schema.json`
- `statistics.json`
- `summary.json`

YAML output:

- `projects.yaml`

The summary should include:

- Total, public, private, and archived project counts
- Languages
- Stars, forks, and releases
- Largest repository
- Most active repository
- Newest repository
- Oldest repository

## Local Cache

The cache must support incremental updates, timestamp tracking, and ETags.
Phase One atomically replaces the current cache while retaining the last valid
state during failures. Historical snapshots are future scope.

## Logging

Use structured logging with these levels:

- Information
- Warning
- Error
- Debug
- Verbose

## Configuration

The default configuration file is `github.config.json`. It must cover:

- Authentication
- Cache
- Output
- Repositories
- Organizations
- Rate limits
- Export formats

## Validation

Validate:

- Configuration
- Authentication
- GitHub connectivity
- Output paths
- Cache integrity

## Error Handling

Handle:

- Authentication failures
- Rate limiting
- Network failures
- GitHub API changes
- Partial synchronization

## Docker Support

Provide an official Docker image. Users must be able to mount an output
directory and provide the token through an environment variable.

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

## Open Questions

### Statistics

- Is commit count required despite the additional API calls?
- Should commit activity be grouped by week, month, or year?

### Outputs and History

- Should output be consolidated, one file per repository, or both?

### Portfolio Metadata

Should projects support custom metadata not stored in GitHub, including:

- Display order
- Featured and hidden flags
- Status
- Technology-stack overrides
- Demo, documentation, and blog URLs
- Priority
- Tags

### AI and Assets

- Should future AI-generated summaries be stored with each project or generated
  dynamically?
- Should screenshots, logos, and badges be managed by this plugin or remain
  external?
