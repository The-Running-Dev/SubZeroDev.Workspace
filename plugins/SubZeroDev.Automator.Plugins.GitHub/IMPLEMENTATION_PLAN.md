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
   capabilities directly, but neither a packages nor a releases capability is a
   repository property, and neither must be invented. The REST repository object
   provides `has_issues`, `has_projects`, `has_wiki`, `has_pages`,
   `has_downloads`, and `has_discussions`; the specification asks for two flags
   that do not exist.
8. **Cross-platform validation is not clean.** Prettier reports line-ending
   changes on the current Windows checkout, and the symlink entry-point test
   requires Windows Developer Mode or elevated symlink permission. Continuous
   integration also runs only on `ubuntu-latest`, so no Windows claim is
   currently enforceable.
9. **Duplicate specification and decision documents.** The merge that brought
   `main` into this branch resurrected `setup/docs/`, which the repository rename
   had replaced with `setup-llm/docs/`. Two byte-identical copies of the
   specification and ADR-0001 were tracked at once, so any specification update
   would have silently drifted. Resolved by deleting the `setup/` copies;
   `setup-llm/docs/` is canonical.
10. **Repository identity is unspecified.** Rename, transfer, and deletion
    reconciliation are required, but no immutable identifier was chosen. Keyed on
    `owner/name`, a rename is indistinguishable from a deletion plus an addition.
11. **This plan and `TODO-next.md` disagreed.** The checklist left decisions open
    that this plan had closed, closed the output-layout decision differently, and
    numbered its milestones one step out of alignment. This plan is authoritative
    for sequencing; the ADR is authoritative for decisions.

## Phase One Decisions

Record these decisions in ADR-0002 and update the specification before
implementing contracts:

| Topic                              | Phase One decision                                                                                                                       |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Repository scope                   | Repositories owned by the authenticated user only.                                                                                       |
| Forks                              | Excluded by default; configurable.                                                                                                       |
| Archived repositories              | Included by default; configurable and flagged.                                                                                           |
| Disabled and template repositories | Included by default; configurable and flagged.                                                                                           |
| Token source                       | `GITHUB_TOKEN` or a configurable environment-variable name. Do not accept or persist a raw token in JSON.                                |
| Output layout                      | Canonical consolidated documents only. Per-project documents are future scope.                                                           |
| Repository identity                | GitHub's immutable numeric `id`, namespaced by provider. `owner/name` is mutable metadata and is never a key.                            |
| Schema versioning                  | One `SCHEMA_VERSION` shared by all top-level documents. Accept the same major, reject otherwise. Pre-`1.0.0` is regenerate-only.         |
| Commit count                       | Collect through `per_page=1` plus the `Link` `rel="last"` page number, at one request per repository. Nullable when absent.              |
| Capability flags                   | Map only flags GitHub exposes directly. Omit packages and releases; never synthesize a flag from a probe request.                        |
| Optional versus null               | Serialized fields use `null`, not absence. A present `null` keeps output byte-stable and sidesteps `exactOptionalPropertyTypes`.         |
| Argument parsing                   | Keep `node:util` `parseArgs` with two-stage parsing: global options, then command-specific options. No parser dependency.                |
| Portfolio metadata                 | Optional provider-independent `custom` JSON object on `Project`.                                                                         |
| Most active                        | Latest repository `pushedAt`; tie-break by ascending repository identity.                                                                |
| Cache history                      | Atomically replace current state; no historical snapshots.                                                                               |
| Atomic replacement                 | Per-file `rename` onto existing targets. No directory swap, which is neither atomic nor permitted over an existing directory on Windows. |
| Failure policy                     | Preserve last valid cache and report per-repository failures.                                                                            |
| Logging levels                     | Map specification levels to Pino `info`, `warn`, `error`, `debug`, and `trace`.                                                          |

If any decision changes, update this plan before implementing the affected
contract.

### Request budget

Concrete numbers, so "bounded and observable" is testable rather than aspirational:

| Budget                    | Phase One value                                                                       |
| ------------------------- | ------------------------------------------------------------------------------------- |
| Default concurrency       | 4 in-flight requests; configurable.                                                   |
| Per-repository collection | 10 requests or fewer for a full, uncached collection.                                 |
| Primary rate limit        | 5000 per hour. Warn at 50% consumed; stop cleanly at 90% and report partial success.  |
| Search rate limit         | A separate bucket of roughly 30 per minute. Stay at or below 20; never burst.         |
| Conditional requests      | A `304` does not consume primary quota, which is what makes the cache pay for itself. |

A 200-repository account therefore costs at most ~2000 requests for a cold sync
and should approach zero primary-quota consumption for an unchanged one.

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

- Add `setup-llm/docs/decisions/0002-github-plugin-phase-one-boundaries.md`
  containing all Phase One boundary decisions. Plugin ADRs live beside the
  existing ADR-0001 under `setup-llm/docs/decisions/`; nothing is written to the
  pre-rename `setup/` path.
- Update the specification so Phase One has no contradictory or open acceptance
  criteria. In particular, reconcile the primary goal ("owned and contributed")
  with the Phase One discovery scope ("owned only"), remove the configuration-file
  token option, and drop the packages and releases capability flags.
- Realign `TODO-next.md` with this plan's milestone numbering and decisions.
- Configure repository line-ending behavior through a root `.gitattributes`, which
  does not yet exist, so `npm run format:check` behaves consistently on Windows
  and Linux.
- Make the installed-entry-point test portable on Windows, using a junction,
  hard link, permission-aware skip, or platform-specific assertion without
  weakening Linux symlink coverage.
- Add `windows-latest` to the `validate` job matrix, so the Windows claim below
  is enforced rather than asserted.
- Define CLI exit codes:
  - `0`: success
  - `2`: usage or validation error
  - `3`: operational failure
  - `4`: partial synchronization
  - `5`: authentication or authorization failure
  - `6`: rate-limited before completion

  `1` is deliberately unused: Node.js returns it for an uncaught exception, so
  reserving it keeps a crash distinguishable from a handled failure.

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

- The full check suite passes on Windows and Linux in GitHub Actions.
- The specification, ADR, and checklist describe the same Phase One.
- Exactly one copy of the specification and of each ADR is tracked.

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
- A provider-namespaced identity built on GitHub's immutable numeric `id`, with
  `owner` and `name` carried as mutable metadata. This is a contract decision, not
  a synchronization detail: without it the rename and transfer reconciliation in
  Milestone 5 cannot be written, and the schema would have to be re-cut after
  `projects.schema.json` is published.
- `Project`, `Repository`, `LanguageStatistics`, `Release`, `ReleaseAsset`,
  `Branch`, `Contributor`, `RepositoryStatistics`, and `Summary`.
- Versioned top-level `ProjectsDocument`, `StatisticsDocument`, and
  `SummaryDocument`, sharing one `SCHEMA_VERSION`.
- A version-compatibility check that accepts the same major version and rejects
  anything else with an actionable error. Pre-`1.0.0` documents are
  regenerate-only; no migration mechanism is built, and the documentation must
  say so rather than implying one exists.
- Zod schemas as the source of truth, with TypeScript types inferred from them.
  Prefer `null` over `.optional()` for serialized fields: `exactOptionalPropertyTypes`
  is enabled, and a present `null` is both easier to construct and more
  deterministic to serialize.
- Deterministic normalization rules for topics, languages, contributors,
  branches, releases, and projects.
- JSON Schema generation for `projects.schema.json` through `z.toJSONSchema()`,
  which ships in the installed Zod 4. Do not add `zod-to-json-schema`, which
  targets Zod 3.
- Fixtures for minimum, complete, private, archived, fork, template, and
  Unicode repository data.

Exit criteria:

- Valid fixtures round-trip through JSON without semantic changes.
- Invalid schema versions, timestamps, URLs, percentages, and duplicate IDs
  fail with useful paths.
- A renamed repository resolves to the same identity as before the rename.
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

## Milestone 3.5 — First Runnable Slice

Inserted deliberately, because every milestone after this one is otherwise built
without ever having run. `sync` is the only command that fills the cache and it
would not land until Milestone 7, so the serializers in Milestone 6 would be
written against data no one had yet seen, and first contact with real GitHub
payloads — where response-shape surprises actually live — would happen in the
second-to-last pull request. Mocked provider tests cannot surface a mapping
assumption that is wrong about the real API, because the mocks encode the same
assumption.

Implement the thinnest end-to-end path:

- `validate`: configuration, token presence, and an authenticated connectivity
  check.
- `sync`, limited to discovery and core repository metadata, written to the cache
  through the Milestone 2 contracts.
- Enough of `list` to read that cache back.

Deliberately excluded: statistics, conditional requests, exports, and YAML. This
milestone buys evidence, not features.

Exit criteria:

- `validate` then `sync` then `list` runs against one real account.
- Observed request counts are compared against the per-repository budget, and the
  budget is corrected if reality disagrees.
- Any mapping or shape correction is folded back into Milestone 1's fixtures
  before Milestone 4 builds on them.

## Milestone 4 — Metadata and Statistics Collection

Build an endpoint-and-budget table before implementation. For every field,
record its endpoint, pagination behavior, ETag support, cost, rate-limit bucket,
fallback, and whether absence is partial failure or valid null.

These GitHub behaviors are known in advance and must appear in that table.
Each one silently produces wrong data rather than an error:

- **`/stats/*` answers `202` with no body** while GitHub computes the result.
  This needs a bounded retry with backoff and a give-up path to `null`, not a
  parse of an empty response.
- **`/contributors` is capped at 500 contributors** and omits anonymous
  contributors by default. Contribution data is therefore not exact for large
  repositories, so the model needs a truncation flag rather than a count that
  quietly understates.
- **`open_issues_count` on the repository object includes pull requests.** Using
  it as the issue count is wrong by the number of open pull requests.
- **Closed issue and pull-request counts realistically need the Search API**,
  which uses a separate rate-limit bucket and is eventually consistent. It can
  disagree with itself between two syncs, which collides directly with the
  determinism requirement — record how that is handled.
- **Commit count has a bounded strategy**: request `commits?per_page=1` and read
  the `rel="last"` page number from the `Link` header, at one request per
  repository.

Implement:

- Core repository metadata and capability flags with reliable GitHub mappings.
- Language byte counts and normalized percentages.
- Releases and latest release.
- Tags and latest tag.
- Branches, default flag, protection flag where available, and last commit.
- Contributors, contribution counts, and a truncation flag.
- Open/closed issues and pull requests with documented counting semantics.
- Commit count through the `Link` `rel="last"` strategy, nullable when the
  header is absent.
- Aggregate statistics and summary selection with deterministic tie-breakers.

Exit criteria:

- Request count is bounded and observable for a fixture account, and stays
  within the per-repository budget defined above.
- Large paginated fixtures do not lose or duplicate records.
- Unavailable optional statistics produce `null` plus diagnostics rather than
  corrupting otherwise valid repository data.
- A `202` from a statistics endpoint never reaches a caller as data.

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
  reconciliation, keyed on immutable repository identity so a rename is not
  observed as a deletion plus an addition.
- Staging writes followed by per-file `rename` onto the live targets. Do not swap
  directories: directory replacement is not atomic on Windows and fails outright
  when the destination exists, and Windows is a supported target here.
- Startup cleanup of abandoned staging data.
- Cache integrity validation and incompatible-version handling.

Exit criteria:

- An interrupted write cannot damage the last valid cache, verified on Windows
  as well as Linux.
- An unchanged second sync produces identical canonical data and fewer requests,
  measured by the request counter rather than asserted.
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
- Each document is replaced by a single `rename` onto its live path. Five
  renames are not one transaction, so state the recovery position plainly: write
  every document to staging first and only begin renaming once all of them have
  serialized, which reduces the exposure to a filesystem failure between renames
  rather than eliminating it.

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
- Command-specific help and strict option validation, through two-stage
  `parseArgs`: parse global options up to the command token, then parse the
  remainder against that command's option table. A single global table would let
  every command accept every other command's flags, which is the opposite of
  strict validation.
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
- Container health/smoke validation for help, validate, and fixture-backed sync,
  added to the `container` workflow job, which currently builds the image without
  ever running it.
- User documentation for quick start, token setup, configuration, commands,
  schemas, cache recovery, rate limits, and troubleshooting. Document that
  incompatible exports are regenerated rather than migrated, so the absence of a
  migration path is stated rather than implied.
- Recorded HTTP fixtures or a controlled GitHub fixture account for end-to-end
  tests; never use a developer’s live account in CI.
- Package provenance, license/files review, container labels, and pinned release
  workflow.
- Decide whether `npm audit --audit-level=high` blocks a release. It runs in CI
  today but is absent from `npm run check`, so a new advisory in a transitive
  dependency can red the branch for reasons unrelated to any pull request.
- Decide whether test coverage is gated. No coverage tooling or threshold exists
  today, despite `coverage/` being ignored by both Git and Prettier.

Release gate:

- `npm ci && npm run check` passes on Windows and Linux.
- Docker image builds and runs as non-root with writable mounted cache/output,
  exercised both as the image's default UID 10001 and under the host-user
  override `run.ps1` applies on Linux. The default path is otherwise never
  tested.
- Fixture end-to-end flow runs `validate -> sync -> list -> stats -> export`.
- A second unchanged sync demonstrates cache reuse.
- Generated output validates and is byte-identical on repeat.
- No secret canary appears anywhere in build artifacts, cache, output, or logs.
- Phase One checklist and documentation contain no unresolved items.

## Suggested Pull Request Sequence

Keep reviews bounded and preserve a green branch:

| Pull request | Milestone | Scope                                                                |
| ------------ | --------- | -------------------------------------------------------------------- |
| 1            | M0        | Decisions, specification cleanup, and cross-platform scaffold fixes. |
| 2            | M1        | Domain schemas, canonicalization, JSON Schema, and fixtures.         |
| 3            | M2        | Ports, configuration, logging, and secret redaction.                 |
| 4            | M3        | GitHub authentication, discovery, pagination, and rate limits.       |
| 5            | M3.5      | First runnable slice against a real account.                         |
| 6            | M4        | Metadata/statistics collection and aggregation.                      |
| 7            | M5        | Cache manifest, conditional requests, and atomic synchronization.    |
| 8            | M6        | JSON/YAML output and atomic export.                                  |
| 9            | M7        | CLI commands and application wiring.                                 |
| 10           | M8        | Docker completion, end-to-end fixtures, documentation, and release.  |

Each pull request must update `TODO-next.md`, include tests for its acceptance
criteria, and leave `npm run check` passing.

## Definition of Done

Phase One is complete only when:

- All decisions are recorded and the specification is internally consistent, with
  exactly one tracked copy of each document.
- This plan, `TODO-next.md`, and the ADRs agree on scope, decisions, and
  milestone numbering.
- All five commands perform their documented work.
- GitHub/Octokit types do not escape the adapter.
- Repository identity survives a rename or transfer.
- Repeated unchanged synchronization is deterministic and avoids unnecessary
  requests, demonstrated by a measured request count rather than an assertion.
- Partial and interrupted synchronization preserve the last valid state.
- All serialized documents are explicitly versioned and schema-valid.
- The Windows, Linux CI, local, and Docker validation paths pass, each enforced
  by a job rather than by developer habit.
- Documentation takes a new user from token setup through validated export.
