# SubZeroDev.Automator.Plugins.GitHub — Next Work

This is the working checklist for implementing
[SubZeroDev.Automator.Plugins.GitHub](SubZeroDev-Ecosystem-Specifications/SubZeroDev.Plugins.GitHub/12-github-plugin.md).

Two companion documents own the detail, and this checklist defers to both:

- [`plugins/SubZeroDev.Automator.Plugins.GitHub/IMPLEMENTATION_PLAN.md`](plugins/SubZeroDev.Automator.Plugins.GitHub/IMPLEMENTATION_PLAN.md)
  is authoritative for sequencing, architectural boundaries, validation strategy,
  and the pull-request breakdown. Milestone numbers here match it exactly.
- The [plugin contract](SubZeroDev-Ecosystem-Specifications/SubZeroDev.PluginContract/04-plugin-contract.md)
  is authoritative for anything generic — exit codes, secrets, output channels,
  serialization, determinism. The ADRs under
  `SubZeroDev-Ecosystem-Specifications/SubZeroDev.Plugins.GitHub/adr/` own the
  GitHub-specific decisions. When this file disagrees with either, this file is
  wrong.

The [peer review](plugins/SubZeroDev.Automator.Plugins.GitHub/IMPLEMENTATION_PLAN_REVIEW.md)
records why several of the entries below exist.

## Milestone 0: Close Decisions and Stabilize the Scaffold

Phase One boundary decisions are now closed in the plan's decisions table and
are being recorded in ADR-0002:

- [x] Implement it here at `plugins/SubZeroDev.Automator.Plugins.GitHub`.
- [x] Use a standalone CLI as the first runner; defer Automator integration.
- [x] Limit Phase One discovery to repositories owned by the authenticated user.
- [x] Exclude forks by default and include archived repositories.
- [x] Defer organization and contributed repositories.
- [x] Collect commit count through `per_page=1` plus the `Link` `rel="last"` page
      number, at one request per repository, and leave it nullable when absent.
- [x] Emit consolidated canonical documents only; per-project output is future
      scope.
- [x] Atomically replace current cache; defer historical snapshots.
- [x] Carry portfolio metadata in an optional provider-independent `custom`
      object on `Project`.
- [x] Require an explicit schema version in every exported document.
- [x] Key repository identity on GitHub's immutable numeric ID, namespaced by
      provider.
- [x] Share one `SCHEMA_VERSION` across top-level documents, accept the same
      major version, and treat pre-`1.0.0` exports as regenerate-only.
- [x] Map only capability flags GitHub exposes directly; omit packages and
      releases.
- [x] Keep `node:util` `parseArgs` with two-stage parsing rather than adding a
      CLI parser dependency.
- [x] Remove the duplicate specification and ADR copies under `setup/`;
      `setup-llm/docs/` is canonical.

Remaining work:

- [x] Record every decision above in
      `SubZeroDev-Ecosystem-Specifications/SubZeroDev.Plugins.GitHub/adr/ADR-002-phase-one-boundaries.md`.
- [x] Update the specification to 1.1: reconcile the primary goal with the Phase
      One discovery scope, remove the configuration-file token option, drop the
      packages and releases capability flags, bind the counting and summary
      semantics, and close the questions the ADR answered.
- [x] Add a root `.gitattributes` so `npm run format:check` agrees across
      Windows and Linux.
- [x] Make the installed-entry-point test portable on Windows without weakening
      Linux symlink coverage.
- [x] Add `windows-latest` to the `validate` job matrix.
- [x] Define the CLI exit codes, leaving `1` reserved for uncaught exceptions.
      They are wired through the commands in Milestone 7.

Exit criteria:

- [ ] The full check suite passes on Windows and Linux in GitHub Actions.
      Awaiting the first Windows run.
- [x] The specification, ADRs, plan, and this checklist describe the same Phase
      One.
- [x] Exactly one copy of the specification and of each ADR is tracked.

## Milestone 1: Domain Contracts and Canonical Schemas

- [ ] Define versioned `Project`, `Repository`, `LanguageStatistics`,
      `Release`, `Branch`, `Contributor`, `RepositoryStatistics`, and `Summary`
      models.
- [ ] Define provider-namespaced identity on GitHub's immutable numeric ID, with
      `owner` and `name` as mutable metadata.
- [ ] Implement the schema-version compatibility check.
- [ ] Create Zod schemas and inferred TypeScript types, preferring `null` over
      `.optional()` for serialized fields.
- [ ] Generate `projects.schema.json` with `z.toJSONSchema()`; do not add
      `zod-to-json-schema`.
- [ ] Add fixture-based schema and serialization tests.

Exit criteria:

- [ ] No GitHub/Octokit type appears outside `providers/github`.
- [ ] JSON round trips deterministically.
- [ ] A renamed repository resolves to the same identity as before the rename.
- [ ] Schema validation rejects incompatible data with useful errors.

## Milestone 2: Ports, Configuration, and Secret Safety

- [ ] Define `github.config.json` with safe defaults.
- [ ] Load tokens from the environment only; the schema must not be able to
      represent a raw token.
- [ ] Validate configuration and output paths with Zod.
- [ ] Define cache, clock, logger, and serializer interfaces.
- [ ] Implement an authenticated connectivity check.
- [ ] Add redaction and secret-canary tests for errors and logs.

## Milestone 3: GitHub Provider and Repository Discovery

- [ ] Implement an Octokit adapter behind the provider interface.
- [ ] Discover all repositories in the agreed Phase One scope with pagination.
- [ ] Apply fork, archived, private, disabled, and template filters.
- [ ] Map GitHub responses into normalized models.
- [ ] Capture rate-limit information and count requests.
- [ ] Add mocked provider tests for pagination, filtering, partial failure, and
      response-shape changes.

## Milestone 3.5: First Runnable Slice

- [ ] Implement `validate` plus a discovery-and-core-metadata `sync`, and enough
      of `list` to read the cache back.
- [ ] Run `validate -> sync -> list` against one real account.
- [ ] Compare observed request counts against the per-repository budget and
      correct the budget if reality disagrees.
- [ ] Fold any mapping correction back into the Milestone 1 fixtures.

## Milestone 4: Metadata and Statistics

- [ ] Build the endpoint-and-budget table, including the `202`-while-computing,
      contributor-cap, `open_issues_count`-includes-pull-requests, and
      Search-API-bucket hazards.
- [ ] Collect required repository metadata.
- [ ] Collect language bytes and deterministic percentages.
- [ ] Collect releases, tags, branches, contributors, pull requests, and issues.
- [ ] Implement the commit-count strategy.
- [ ] Define "most active repository" deterministically.
- [ ] Bound concurrency and respect both rate-limit buckets.

## Milestone 5: Cache and Incremental Synchronization

- [ ] Define a versioned cache manifest.
- [ ] Track successful synchronization timestamps and ETags.
- [ ] Reuse unchanged cached data.
- [ ] Write updates atomically through per-file `rename`, never a directory swap.
- [ ] Preserve the last valid cache after partial or total failure.
- [ ] Test first sync, no-change sync, changed repository, rename, transfer,
      deletion, corruption, interruption, and rate limiting.

## Milestone 6: Serializers and Exports

- [ ] Produce deterministic `projects.json`, `projects.schema.json`,
      `statistics.json`, `summary.json`, and `projects.yaml`.
- [ ] Serialize every document to staging before renaming any of them.
- [ ] Add golden-file byte-stability tests.

## Milestone 7: CLI Commands and Application Wiring

- [ ] Implement `github sync`, `list`, `stats`, `export`, and `validate`.
- [ ] Implement global and command-specific options through two-stage
      `parseArgs`.
- [ ] Define stable exit codes and machine-readable error behavior.

## Milestone 8: Docker, Documentation, and Release Readiness

- [x] Run the CLI as a non-root container user.
- [x] Support writable cache/output mounts; add the read-only configuration
      mount when configuration loading is implemented.
- [x] Document token injection without placing secrets in image layers.
- [ ] Add container smoke validation to the `container` workflow job, which
      currently builds the image without running it.
- [ ] Add quick-start, configuration, command, schema, cache, and troubleshooting
      documentation, stating that incompatible exports are regenerated rather
      than migrated.
- [ ] Run an end-to-end test against a controlled GitHub fixture account or
      recorded API fixtures.
- [ ] Decide whether `npm audit` and test coverage gate a release.
- [ ] Clear the packaging blockers: `private: true` makes `npm publish` refuse,
      and neither `license` nor `repository` is declared.
- [ ] Version and publish the Phase One package and container.

## Definition of Done

- [ ] Every Phase One deliverable in the specification is implemented.
- [ ] Every non-goal remains outside the package.
- [ ] GitHub API and Octokit types do not leak beyond the provider.
- [ ] Repository identity survives a rename or transfer.
- [ ] Repeated unchanged synchronizations are deterministic and avoid unnecessary
      API calls, shown by a measured request count.
- [ ] Interrupted synchronization cannot destroy the last valid cache.
- [ ] Export schemas are explicitly versioned and validated.
- [ ] Documentation can take a new user from token setup to validated export.
