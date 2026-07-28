# SubZeroDev GitHub Plugin Implementation Plan

This plan turns the Phase One specification into an implementation sequence for
`@subzerodev/automator-plugin-github`. It is intentionally ordered by dependency:
contracts first, provider access second, persistence third, and user-facing
commands last.

## Current Baseline

The repository already provides:

- A Node.js 24+, strict TypeScript, ESM package scaffold.
- A provider-independent `ProjectProvider` boundary.
- A minimal versioned `Project` Zod schema.
- A CLI entry point with the Phase One command names.
- Vitest, ESLint, Prettier, build, Docker, PowerShell runner, and GitHub Actions
  scaffolding.
- ADR-0001 for package location, CLI-first hosting, and semantic versioning.

The commands intentionally return “not implemented.” No GitHub API,
configuration, synchronization, cache, export, or statistics behavior exists
yet.

## Review Findings to Resolve First

1. **Repository scope conflicts in the specification.** The primary goal says
   owned and contributed repositories, while the Phase One discovery section
   limits work to repositories owned by the authenticated user.
2. **Authentication policy is incomplete.** The specification permits a token
   in a configuration file, but storage, redaction, precedence, and safe example
   files are not defined.
3. **The API-call budget is undefined.** Exact commit, issue, pull-request,
   contributor, tag, branch, and release counts can require many paginated
   requests per repository.
4. **Output shape remains open.** Consolidated versus per-project output affects
   schemas, serializers, cache keys, and atomic writes.
5. **Portfolio metadata remains open.** Adding it after publishing the first
   schema would create avoidable schema churn.
6. **Summary semantics are incomplete.** “Most active repository” needs an
   exact formula and deterministic tie-breaker.
7. **GitHub capability mapping needs validation.** GitHub exposes some
   capabilities directly, but a packages capability is not a normal repository
   property and must not be invented.
8. **Cross-platform validation is not clean.** Prettier reports line-ending
   changes on the current Windows checkout, and the symlink entry-point test
   requires Windows Developer Mode or elevated symlink permission.

## Phase One Decisions

Record these decisions in ADR-0002 and update the specification before
implementing contracts:

| Topic                              | Phase One decision                                                                                        |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Repository scope                   | Repositories owned by the authenticated user only.                                                        |
| Forks                              | Excluded by default; configurable.                                                                        |
| Archived repositories              | Included by default; configurable and flagged.                                                            |
| Disabled and template repositories | Included by default; configurable and flagged.                                                            |
| Token source                       | `GITHUB_TOKEN` or a configurable environment-variable name. Do not accept or persist a raw token in JSON. |
| Output layout                      | Canonical consolidated documents only. Per-project documents are future scope.                            |
| Commit count                       | Nullable in Phase One. Collect only when an exact, bounded strategy is enabled.                           |
| Portfolio metadata                 | Optional provider-independent `custom` JSON object on `Project`.                                          |
| Most active                        | Latest repository `pushedAt`; tie-break by normalized repository ID.                                      |
| Cache history                      | Atomically replace current state; no historical snapshots.                                                |
| Failure policy                     | Preserve last valid cache and report per-repository failures.                                             |
| Packages capability                | Omit until GitHub provides a reliable repository-level mapping.                                           |
| Logging levels                     | Map specification levels to Pino `info`, `warn`, `error`, `debug`, and `trace`.                           |

If any decision changes, update this plan before implementing the affected
contract.

## Architectural Boundaries

Dependencies must point inward:

```text
CLI / commands
    -> application services
        -> provider, cache, serializer, clock, logger interfaces
            -> versioned domain models and schemas

GitHub adapter -> Octokit
filesystem adapters -> Node.js filesystem
JSON/YAML adapters -> serialization libraries
```

Rules:

- Only `src/providers/github/**` may import Octokit or GitHub response types.
- Domain models contain no filesystem paths, environment variables, or CLI
  concepts.
- Services depend on interfaces, not concrete filesystem or GitHub adapters.
- Serialized top-level documents contain `schemaVersion`.
- Arrays and object keys are normalized before serialization so identical input
  produces byte-stable output.
- Tokens must never appear in models, cache, output, logs, or thrown errors.

## Milestone 0 — Close Decisions and Stabilize the Scaffold

Deliverables:

- Add ADR-0002 containing all Phase One boundary decisions.
- Update the specification so Phase One has no contradictory or open
  acceptance criteria.
- Configure repository line-ending behavior so `npm run format:check` behaves
  consistently on Windows and Linux.
- Make the installed-entry-point test portable on Windows, using a junction,
  hard link, permission-aware skip, or platform-specific assertion without
  weakening Linux symlink coverage.
- Define CLI exit codes:
  - `0`: success
  - `2`: usage or validation error
  - `3`: operational failure
  - `4`: partial synchronization
  - `5`: authentication or authorization failure
  - `6`: rate-limited before completion

Verification:

```text
npm run format:check
npm run lint
npm run typecheck
npm test
npm run build
node dist/cli.js --help
```

Exit criteria:

- The full check suite passes on Windows and GitHub Actions.
- The specification, ADR, and checklist describe the same Phase One.

## Milestone 1 — Domain Contracts and Canonical Schemas

Create:

```text
src/models/
  common.ts
  project.ts
  repository.ts
  release.ts
  branch.ts
  contributor.ts
  statistics.ts
  summary.ts
  documents.ts
src/serialization/
  canonicalize.ts
  json-schema.ts
tests/fixtures/models/
```

Implement:

- Branded or validated identifiers, URLs, ISO timestamps, visibility, account
  type, and JSON-value primitives.
- `Project`, `Repository`, `LanguageStatistics`, `Release`, `ReleaseAsset`,
  `Branch`, `Contributor`, `RepositoryStatistics`, and `Summary`.
- Versioned top-level `ProjectsDocument`, `StatisticsDocument`, and
  `SummaryDocument`.
- Zod schemas as the source of truth, with TypeScript types inferred from them.
- Deterministic normalization rules for topics, languages, contributors,
  branches, releases, and projects.
- JSON Schema generation for `projects.schema.json`.
- Fixtures for minimum, complete, private, archived, fork, template, and
  Unicode repository data.

Exit criteria:

- Valid fixtures round-trip through JSON without semantic changes.
- Invalid schema versions, timestamps, URLs, percentages, and duplicate IDs
  fail with useful paths.
- Language percentages use a documented rounding rule and total 100 within the
  chosen precision.
- No provider type appears in a domain model.

## Milestone 2 — Ports, Configuration, and Secret Safety

Create:

```text
src/configuration/
  schema.ts
  defaults.ts
  load.ts
src/contracts/
  cache.ts
  clock.ts
  logger.ts
  serializer.ts
src/providers/provider.ts
src/logging/
  pino-logger.ts
  redact.ts
tests/fixtures/configuration/
```

Implement:

- A versioned `github.config.json` schema with repository filters, cache/output
  directories, export formats, concurrency, request budget, and token
  environment-variable name.
- Precedence: CLI option, environment override, config file, safe default.
- Path resolution relative to the config file, not the current process.
- Provider-neutral discovery and detail-fetch contracts with rate-limit and
  partial-failure results.
- Clock, logger, cache, and serializer interfaces.
- Pino redaction for authorization headers, known token fields, request errors,
  and nested causes.

Exit criteria:

- A raw token cannot be represented by the configuration schema.
- Missing, unreadable, malformed, and incompatible configuration files produce
  stable errors and exit codes.
- Secret canary tests prove tokens do not reach stdout, stderr, logs, or
  serialized errors.

## Milestone 3 — GitHub Adapter and Repository Discovery

Create:

```text
src/providers/github/
  client.ts
  github-provider.ts
  mapper.ts
  pagination.ts
  rate-limit.ts
tests/providers/github/
```

Implement:

- Octokit construction from the resolved environment token.
- Authenticated-user connectivity check.
- Paginated owned-repository discovery.
- Configurable fork, archived, disabled, private, and template filters.
- Mapping from GitHub responses to provider-neutral discovery records.
- Central request wrapper for ETags, rate-limit data, retries, error
  classification, and redaction.
- Bounded concurrency; begin conservatively and make it configurable.

Test with mocked HTTP responses:

- Empty, one-page, and multi-page accounts.
- Filtering combinations.
- Private repositories and missing optional fields.
- 401, 403, 404, 429, 5xx, network interruption, and response-shape drift.
- Primary and secondary rate limits.

Exit criteria:

- Octokit types and imports remain under `providers/github`.
- Every owned repository is discovered exactly once.
- Errors carry repository/request context without secrets.

## Milestone 4 — Metadata and Statistics Collection

Build an endpoint-and-budget table before implementation. For every field,
record its endpoint, pagination behavior, ETag support, cost, fallback, and
whether absence is partial failure or valid null.

Implement:

- Core repository metadata and capability flags with reliable GitHub mappings.
- Language byte counts and normalized percentages.
- Releases and latest release.
- Tags and latest tag.
- Branches, default flag, protection flag where available, and last commit.
- Contributors and contribution counts.
- Open/closed issues and pull requests with documented counting semantics.
- Nullable commit count according to the Phase One decision.
- Aggregate statistics and summary selection with deterministic tie-breakers.

Exit criteria:

- Request count is bounded and observable for a fixture account.
- Large paginated fixtures do not lose or duplicate records.
- Unavailable optional statistics produce `null` plus diagnostics rather than
  corrupting otherwise valid repository data.

## Milestone 5 — Cache and Incremental Synchronization

Create:

```text
src/cache/
  manifest.ts
  filesystem-cache.ts
  atomic-write.ts
src/services/
  synchronize.ts
  cache-validation.ts
tests/cache/
tests/services/synchronize.test.ts
```

Define a versioned manifest containing:

- Schema and cache format versions.
- Authenticated owner identity.
- Last complete synchronization time.
- Per-resource ETags and successful fetch times.
- Repository identity and content hash.
- Tombstones or deletion reconciliation state.
- Partial-failure diagnostics that contain no secrets.

Implement:

- First synchronization.
- Conditional requests and reuse of valid unchanged data.
- Repository addition, change, rename, transfer, archive, and deletion
  reconciliation.
- Staging-directory writes followed by atomic replacement.
- Startup cleanup of abandoned staging data.
- Cache integrity validation and incompatible-version handling.

Exit criteria:

- An interrupted write cannot damage the last valid cache.
- An unchanged second sync produces identical canonical data and fewer requests.
- Partial failure returns exit code `4`, retains prior valid data for failed
  resources, and records actionable diagnostics.

## Milestone 6 — Serializers and Exports

Create:

```text
src/serialization/
  json.ts
  yaml.ts
src/output/
  exporter.ts
tests/serialization/
tests/output/
```

Implement atomic, deterministic output for:

- `projects.json`
- `projects.schema.json`
- `statistics.json`
- `summary.json`
- `projects.yaml`

Rules:

- UTF-8 with LF and one trailing newline.
- Stable property and collection ordering.
- JSON and YAML represent the same normalized project data.
- Output replacement is all-or-nothing where the filesystem permits it.

Exit criteria:

- Golden-file tests are byte-stable across repeated runs.
- Every emitted document validates against its schema.
- Export failure leaves the previous complete output set intact.

## Milestone 7 — Application Services and CLI Commands

Split argument parsing, command dispatch, and process I/O:

```text
src/commands/
  sync.ts
  list.ts
  stats.ts
  export.ts
  validate.ts
src/services/
  application.ts
src/cli.ts
```

Implement:

- Global `--config`, `--cache`, `--output`, `--log-level`, `--json`, and
  `--quiet` options.
- Command-specific help and strict option validation.
- `sync`: authenticate, discover, collect, and update cache.
- `list`: read valid cache and print a deterministic table or JSON.
- `stats`: calculate/read statistics and print human or JSON output.
- `export`: write the canonical output set from valid cache.
- `validate`: validate config, token presence, connectivity when requested,
  cache, and output paths.
- Stable exit codes and machine-readable error envelopes.

Exit criteria:

- Command tests use injected services and do not require network or the real
  filesystem.
- End-to-end CLI tests cover success, invalid use, authentication failure,
  partial sync, rate limiting, corrupt cache, and export failure.
- Help text and README examples match actual options.

## Milestone 8 — Docker, Documentation, and Release Readiness

Implement:

- Read-only configuration mount support in `run.ps1` and Docker documentation.
- Container health/smoke validation for help, validate, and fixture-backed sync.
- User documentation for quick start, token setup, configuration, commands,
  schemas, cache recovery, rate limits, troubleshooting, and migration.
- Recorded HTTP fixtures or a controlled GitHub fixture account for end-to-end
  tests; never use a developer’s live account in CI.
- Package provenance, license/files review, container labels, and pinned release
  workflow.

Release gate:

- `npm ci && npm run check` passes.
- Docker image builds and runs as non-root with writable mounted cache/output.
- Fixture end-to-end flow runs `validate -> sync -> list -> stats -> export`.
- A second unchanged sync demonstrates cache reuse.
- Generated output validates and is byte-identical on repeat.
- No secret canary appears anywhere in build artifacts, cache, output, or logs.
- Phase One checklist and documentation contain no unresolved items.

## Suggested Pull Request Sequence

Keep reviews bounded and preserve a green branch:

1. Decisions, specification cleanup, and cross-platform scaffold fixes.
2. Domain schemas, canonicalization, JSON Schema, and fixtures.
3. Ports, configuration, logging, and secret redaction.
4. GitHub authentication, discovery, pagination, and rate limits.
5. Metadata/statistics collection and aggregation.
6. Cache manifest, conditional requests, and atomic synchronization.
7. JSON/YAML output and atomic export.
8. CLI commands and application wiring.
9. Docker completion, end-to-end fixtures, documentation, and release workflow.

Each pull request must update `TODO-next.md`, include tests for its acceptance
criteria, and leave `npm run check` passing.

## Definition of Done

Phase One is complete only when:

- All decisions are recorded and the specification is internally consistent.
- All five commands perform their documented work.
- GitHub/Octokit types do not escape the adapter.
- Repeated unchanged synchronization is deterministic and avoids unnecessary
  requests.
- Partial and interrupted synchronization preserve the last valid state.
- All serialized documents are explicitly versioned and schema-valid.
- The Windows, Linux CI, local, and Docker validation paths pass.
- Documentation takes a new user from token setup through validated export.
