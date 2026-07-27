# SubZeroDev.Automator.Plugins.GitHub — Next Work

This is the working checklist for implementing
[SubZeroDev.Automator.Plugins.GitHub](setup/docs/specifications/subzerodev-automator-plugins-github.md). Complete it
top to bottom, updating decisions and acceptance criteria as the project
develops.

## Current Step: Resolve Remaining Phase One Boundaries

Before scaffolding, record the decisions that affect the normalized model,
configuration schema, API-call budget, and cache layout.

- [x] Implement it here at `plugins/SubZeroDev.Automator.Plugins.GitHub`.
- [x] Use a standalone CLI as the first runner; defer Automator integration.
- [x] Limit Phase One discovery to repositories owned by the authenticated user.
- [x] Exclude forks by default and include archived repositories.
- [x] Defer organization and contributed repositories.
- [ ] Decide whether commit count is required in Phase One.
- [ ] Choose consolidated output, per-repository output, or both.
- [x] Atomically replace current cache; defer historical snapshots.
- [ ] Decide whether portfolio-specific metadata belongs in the core model.
- [x] Require an explicit schema version in every exported document.

Recommended starting decisions:

| Question | Recommendation |
| --- | --- |
| Repository scope | Owned repositories only in Phase One. |
| Forks | Excluded by default, configurable. |
| Archived repositories | Included by default and clearly flagged. |
| Organizations | Defer until the owned-repository path is stable. |
| Commit count | Defer exact counts; expose a nullable field until an efficient strategy is proven. |
| Output layout | Consolidated canonical files plus optional per-project files. |
| Cache history | Keep current state atomically; snapshots are future work. |
| Portfolio metadata | Support an optional provider-independent `custom` section without mixing it with GitHub data. |
| Schema version | Required from the first export. |

Exit criteria:

- [ ] Decisions are recorded in an ADR.
- [ ] The specification is updated where decisions close open questions.
- [ ] Phase One acceptance criteria contain no unresolved scope ambiguity.

## Milestone 1: Scaffold the CLI-First Plugin

- [x] Create the in-repository Node.js 24+ TypeScript plugin.
- [x] Configure ESM, strict TypeScript, package exports, and a CLI binary.
- [x] Add Vitest, ESLint, Prettier, and type-checking scripts.
- [x] Create the specified source directories.
- [x] Add a minimal Dockerfile and `.dockerignore`.
- [x] Add a PowerShell runner and document local and Docker workflows.
- [x] Add CI for dependency audit, lint, type-check, tests, build, CLI smoke test,
  and Docker build.
- [x] Verify the scaffold can install, build, test, and run
  `subzerodev-github --help`.

Exit criteria:

- [x] `npm run lint`
- [x] `npm run typecheck`
- [x] `npm test`
- [x] `npm run build`
- [x] `subzerodev-github --help`

## Milestone 2: Define Contracts Before GitHub Integration

- [ ] Define versioned `Project`, `Repository`, `LanguageStatistics`,
  `Release`, `Branch`, `Contributor`, `RepositoryStatistics`, and `Summary`
  models.
- [ ] Define provider interfaces that contain no Octokit types.
- [ ] Define configuration, cache, serializer, clock, and logger interfaces.
- [ ] Create Zod schemas and inferred TypeScript types.
- [ ] Generate or publish `projects.schema.json` from the canonical schema.
- [ ] Add fixture-based schema and serialization tests.

Exit criteria:

- [ ] No GitHub/Octokit type appears outside `providers/github`.
- [ ] JSON round trips deterministically.
- [ ] Schema validation rejects incompatible data with useful errors.

## Milestone 3: Configuration and Authentication

- [ ] Define `github.config.json` with safe defaults.
- [ ] Load tokens from the environment without serializing or logging them.
- [ ] Decide and document configuration-file token handling.
- [ ] Validate configuration and output paths with Zod.
- [ ] Implement an authenticated connectivity check.
- [ ] Add redaction tests for errors and logs.

## Milestone 4: GitHub Provider and Repository Discovery

- [ ] Implement an Octokit adapter behind the provider interface.
- [ ] Discover all repositories in the agreed Phase One scope with pagination.
- [ ] Apply fork, archived, private, disabled, and template filters.
- [ ] Map GitHub responses into normalized models.
- [ ] Capture rate-limit information.
- [ ] Add mocked provider tests for pagination, filtering, partial failure, and
  response-shape changes.

## Milestone 5: Metadata and Statistics

- [ ] Collect required repository metadata.
- [ ] Collect language bytes and deterministic percentages.
- [ ] Collect releases, tags, branches, contributors, pull requests, and issues.
- [ ] Implement the agreed commit-count strategy.
- [ ] Define “most active repository” deterministically.
- [ ] Bound concurrency and respect GitHub rate limits.

## Milestone 6: Cache and Incremental Synchronization

- [ ] Define a versioned cache manifest.
- [ ] Track successful synchronization timestamps and ETags.
- [ ] Reuse unchanged cached data.
- [ ] Write updates atomically.
- [ ] Preserve the last valid cache after partial or total failure.
- [ ] Test first sync, no-change sync, changed repository, deletion, corruption,
  interruption, and rate limiting.

## Milestone 7: CLI and Exports

- [ ] Implement `github sync`.
- [ ] Implement `github list`.
- [ ] Implement `github stats`.
- [ ] Implement `github export`.
- [ ] Implement `github validate`.
- [ ] Produce deterministic `projects.json`, `projects.schema.json`,
  `statistics.json`, `summary.json`, and `projects.yaml`.
- [ ] Define stable exit codes and machine-readable error behavior.

## Milestone 8: Docker, Documentation, and Release Readiness

- [x] Run the CLI as a non-root container user.
- [x] Support writable cache/output mounts; add the read-only configuration
  mount when configuration loading is implemented.
- [x] Document token injection without placing secrets in image layers.
- [ ] Add quick-start, configuration, command, schema, cache, and troubleshooting
  documentation.
- [ ] Run an end-to-end test against a controlled GitHub fixture account or
  recorded API fixtures.
- [ ] Version and publish the Phase One package and container.

## Definition of Done

- [ ] Every Phase One deliverable in the specification is implemented.
- [ ] Every non-goal remains outside the package.
- [ ] GitHub API and Octokit types do not leak beyond the provider.
- [ ] Repeated unchanged synchronizations are deterministic and avoid unnecessary
  API calls.
- [ ] Interrupted synchronization cannot destroy the last valid cache.
- [ ] Export schemas are explicitly versioned and validated.
- [ ] Documentation can take a new user from token setup to validated export.
