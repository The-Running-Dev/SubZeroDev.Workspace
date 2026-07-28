# Architecture Review — SubZeroDev Ecosystem Specifications

Reviewed at commit `6560d98`: 21 specifications, 5 ADRs, `schemas/plugin-manifest.schema.json`,
and both examples. Structured as `19-open-questions.md` requests: findings, critical changes,
recommended ADRs, revised phase plan, decisions needed.

**Overall.** The product decomposition is sound and several decisions are better than what most
systems of this kind ship with. The problems are concentrated in three places: the plugin contract
is specified more loosely than the schema that is supposed to enforce it, the security model
declares capabilities it cannot enforce on the hosts it plans to ship first, and the document set
contradicts both itself and the GitHub plugin work already committed to this branch.

None of that is structural. It is all fixable before implementation, which is the point of
reviewing now.

---

## What is right

Worth stating first, because the rest of this document is problems.

- **The Platform / Automator / plugin split with an explicit dependency direction.** "Automator
  owns orchestration, plugins own business logic" is phrased sharply enough to enforce in code
  review, which is rare for an architectural rule.
- **ADR-004, plugins must be independently executable.** This is the strongest decision in the set.
  It keeps every plugin debuggable, testable, and useful without the orchestrator, and it is why
  the GitHub plugin has value today rather than after Automator ships.
- **The Docker host security defaults** (`05`): non-root, read-only root filesystem, no Docker
  socket, dropped capabilities, resource limits, network denied unless declared, digest pinning.
  That list is more disciplined than most production systems.
- **Secret references rather than values in workflow definitions**, and secrets not flowing to
  downstream steps without re-authorization.
- **"Installing a plugin must not automatically expose every command to every AI client"** (`03`).
  A subtle call, and the right one.
- **Immutable workflow version snapshots per execution.**
- **Fixture plugins per runtime** (`17`) — this is a conformance suite by another name, and it is
  the right instinct.
- **The Requirements Compiler framing** (`13`): a compiler pipeline rather than one prompt, explicit
  classification of explicit/derived/assumption/open-question/conflict, dry-run publishing by
  default, and stable IDs for reconciliation. That last one is the genuinely hard problem and it was
  correctly identified.

---

## Findings

### C1 — Exit codes collide with the GitHub plugin already committed, and the collision is silent

`04-plugin-contract.md` defines a baseline that conflicts with `ADR-0002` and specification 1.1,
both committed to this branch three commits ago:

| Code        | `04-plugin-contract.md` | Committed GitHub plugin       |
| ----------- | ----------------------- | ----------------------------- |
| `1`         | general failure         | reserved (uncaught exception) |
| `2`         | invalid input           | usage or validation           |
| `3`         | **auth failure**        | **operational failure**       |
| `4`         | **external dependency** | **partial success**           |
| `5`         | **partial success**     | **auth failure**              |
| `6`         | —                       | rate-limited                  |
| `124`/`130` | timeout / cancelled     | —                             |

Codes `3`, `4`, and `5` mean different things in each, and `3`/`5` are effectively swapped. A host
reading exit `5` would record "partial success" for a run that failed to authenticate. Nothing
crashes; the data is just wrong, which makes this the most dangerous single conflict in the set.

Two secondary problems in the ecosystem table:

- **`1` as "general failure" destroys a distinction worth keeping.** Most runtimes — Node included —
  return `1` for an uncaught exception. If `1` also means "the plugin cleanly reported failure",
  a crash and a handled error are indistinguishable, and they warrant different retry behavior.
- **`124` and `130` are right and should be kept.** They follow `timeout(1)` and `128 + SIGINT`,
  so shell tooling and container runtimes already produce them. The committed table lacks them.

The merge is straightforward and is proposed in Critical Changes.

### C2 — The manifest schema does not enforce the contract it encodes

`schemas/plugin-manifest.schema.json` is permissive to the point of validating almost anything:

- `"additionalProperties": true` at the root, on `commands[]`, and on `runtimes[]`.
- `version` is `{"type": "string", "minLength": 1}` — `"banana"` validates as a semantic version.
- `schemaVersion` has no pattern or enum.
- `timeout` is an unconstrained string, while the examples use ISO-8601 durations (`PT15M`).
- **`secrets` is `{"type": "array"}` with no item schema**, despite `04` specifying
  `id`/`required`/`environmentVariable`/`sensitive`.
- **`capabilities` is `{"type": "object"}` — entirely unconstrained.**
- `commands[].artifacts` appears in the `04` example but does not exist in the schema at all; it
  validates only because additional properties are allowed.
- `required` omits `secrets` and `capabilities`, while `04`'s "Required properties" section says
  every plugin must declare secrets, artifact behavior, license metadata, and compatibility
  metadata. **The schema contradicts the prose it exists to enforce.**

`capabilities` is the serious one. `10-security-tenancy-billing.md` builds the entire plugin
permission model on manifest-declared capabilities that "Automator policy decides whether to
allow" — and you cannot write a policy engine against an unconstrained object. The security model
currently rests on a field with no shape.

Also: `$id` is `https://schemas.subzerodev.com/plugin-manifest.schema.json`, unversioned. Publishing
a 2.0 schema would overwrite 1.0 at the same URL, breaking every pinned reference.

### C3 — Unknown-field handling fails open, and that is a security decision nobody made

Because `additionalProperties` is `true` everywhere, a plugin declaring a capability the host does
not understand runs **without that capability being enforced**. A manifest asking for
`capabilities.devices` or `capabilities.gpu` against an older host silently gets neither the access
nor a refusal.

Forward-compatible field-ignoring is a reasonable default for descriptive metadata. It is the wrong
default for the security surface. `19` asks "What is the version compatibility policy?" — there
isn't one, and this is the part of it that matters.

### C4 — Capabilities are declared but unenforceable on a Phase One host

`03` puts both the Docker host and the local process host in Phase One. The Docker host can enforce
most declarations. **The local process host can enforce essentially none of them** — no filesystem
confinement, no network denial, no capability dropping.

So in Phase One a plugin's declared capabilities are enforced or ignored depending on which host
resolves it, and nothing in the specification says so. If policy is evaluated against declarations
that are not enforced, the policy is decorative.

This needs an explicit per-host enforcement level and a rule binding trust to hosts: untrusted
plugins must never resolve to the local process host.

### C5 — The trust model has no way to establish trust

`04` defines four trust levels and makes them govern runtime selection, network, filesystem,
secrets, and MCP exposure. `03` stores "trust state" in the registry. But nothing describes how
trust is _established or verified_: there is no trust root, no signing key, no verification step.
Signing appears only as a Phase Three roadmap item and an open question.

For Phases 1–2 the trust taxonomy is four labels with nothing behind them, and "trusted signed
third-party" is unimplementable. Shipping a taxonomy that cannot be enforced invites code that
branches on it as though it can.

### C6 — Secrets: one hedge and one probable regression

`10` says secrets should never be passed in command-line arguments **"when avoidable"**. It is
always avoidable, and on Linux `argv` is readable from `/proc` by any process of the same user. This
should be absolute; `ADR-0002` already made it absolute for the GitHub plugin.

More concretely, `12-github-plugin.md` lists Phase One authentication as `GITHUB_TOKEN`,
**"configuration reference"**, and optional GitHub CLI token reuse. "Configuration reference" is
ambiguous between _a reference to a secret in a store_ (fine) and _a token in the config file_
(a direct regression against `ADR-0002`, which decided the configuration schema must be incapable
of representing a token). It needs to say which.

GitHub CLI token reuse is a genuine convenience with a quiet catch: it inherits whatever scopes the
user's `gh` session holds, which is usually far broader than the read access this plugin needs. It
should be opt-in and recorded in the run report, not silently preferred.

Finally, nothing states that **plugin outputs are scanned for secret values before being persisted
or passed downstream**. A plugin that accidentally emits a token into its result envelope would have
it written to execution history and handed to the next step.

### C7 — The result envelope has no error channel, and three documents disagree about it

Three different result models appear:

- `01`: status, exit code, structured output, logs, warnings, **errors**, artifacts, timing, runtime metadata
- `04` envelope: schemaVersion, status, command, summary, data, warnings, artifacts — **no errors, no timing, no exit code**
- `03` execution result: status, exit code, timing, normalized output, warnings, **structured errors**, artifacts, log reference, host metadata, agent metadata, retry history

The plugin-emitted envelope (`04`) and the Automator-recorded result (`03`) legitimately differ, but
that distinction is never stated — and `04` having `warnings: []` with no `errors: []` is plainly an
oversight. A failing plugin has nowhere structured to say why.

### C8 — `data` is unbounded, and Phase One stores it in SQLite

`04`'s envelope carries `"data": {}` with no size limit. `03` persists normalized output in an
append-only execution history on SQLite. The GitHub plugin's first sync of a large account produces
a `projects.json` measured in megabytes.

If `data` is where results go, that payload lands in the database. `09` mentions output truncation
only for MCP. The rule should be general: **`data` is a bounded summary; payloads are artifacts.**
`12` already writes `projects.json` to `output/`, so the intent is right — it just is not stated,
and the envelope invites the opposite.

### C9 — Retry and idempotency will lose data as currently specified

- `04` defines "conditionally idempotent" without saying what the condition is or who evaluates it.
- `06` allows retry on "retryable exit codes" while the exit table is in flux (C1) and `1` means
  "general failure" — so a retry policy would retry crashes and deterministic failures alike.
- **A timeout followed by a retry can produce two concurrent runs.** Container stop is asynchronous;
  nothing requires the previous attempt to be confirmed dead before the next starts. For a
  non-idempotent publishing command that is a duplicate-write bug.
- Compensation is "best-effort and recorded separately", with nothing said about compensation
  failing. That is the classic saga hole and it is unaddressed.

### C10 — Two incompatible phase vocabularies

`03-automator-specification.md` has its own "Phase One" (15 items, including REST, PowerShell, cron,
workflows, notifications). `02-platform-specification.md` has a "Phase One Platform scope". And
`18-roadmap.md` defines a _different_ global sequence where Automator's MVP is **Phase 3** and
Platform is **Phase 2**.

So "Phase One" means at least three things depending on the document. This is the same drift that
existed between `TODO-next.md` and the implementation plan, corrected earlier on this branch. One
vocabulary, defined once in `18`, referenced everywhere else.

Separately, `03`'s 13-state execution machine is too large for a first release: `Skipped` and
`Compensated` only exist once workflows and compensation do, and `Validated`/`Resolving`/`Starting`
are internal transitions that may not warrant persisted states.

### C11 — The GitHub plugin spec contradicts the committed one, including two regressions

`12-github-plugin.md` conflicts with specification 1.1 and `ADR-0002`, already on this branch:

| Topic                 | `12` (new)                                    | Committed 1.1 / ADR-0002              |
| --------------------- | --------------------------------------------- | ------------------------------------- |
| CLI name              | `sz-github`                                   | `subzerodev-github`                   |
| Introspection command | `describe`                                    | `manifest`                            |
| Token source          | env, "configuration reference", `gh` CLI      | environment only                      |
| Capability flags      | includes **packages and releases indicators** | both dropped as non-existent          |
| Portfolio metadata    | overrides file keyed by **slug**              | `custom` object keyed by immutable ID |
| Forks                 | retained in raw, excluded from summary        | excluded by default, configurable     |
| Schema version        | `"1.0"`                                       | `"1.0.0"`                             |
| Outputs               | adds `sync-report.json`, `raw/`               | four canonical documents              |

Two are regressions rather than differences:

1. **Packages and releases indicators.** GitHub's REST repository object exposes `has_issues`,
   `has_projects`, `has_wiki`, `has_pages`, `has_downloads`, and `has_discussions`. There is no
   `has_packages` and no `has_releases`. Collecting them means either fabricating a value or probing
   an endpoint and inferring one, which `ADR-0002` explicitly prohibits.
2. **Overrides keyed by slug.** `owner/name` is mutable. Rename a repository and every hand-written
   portfolio override silently detaches from it. This is precisely the identity bug `ADR-0002`
   fixed by keying on the immutable numeric ID.

Note also that `03` itself uses `subzerodev-github sync` in its manual-execution example while `12`
uses `sz-github` — the new set disagrees with itself here.

**Three ideas in `12` are better than what is committed and should be adopted:**

- **Collection profiles (Basic / Standard / Detailed).** A better answer to API cost than the fixed
  per-repository budget in `ADR-0002`, because it makes cost an explicit user choice rather than an
  implementer's constant. Adopt this.
- **`sync-report.json`.** A per-run report maps naturally onto the result envelope and gives partial
  failure somewhere durable to live.
- **Optional `raw/` retention.** Genuinely useful for diagnosing provider drift. Must default off
  and be excluded from determinism comparisons.

### C12 — Naming is inconsistent in four dimensions

One capability currently appears as `subzerodev.github` (plugin ID), `sz-github` / `subzerodev-github`
(CLI), `ghcr.io/…/subzerodev-github` (image), `@subzerodev/automator-plugin-github` (npm), and
`SubZeroDev.Automator.Plugins.GitHub` (directory). Five schemes, no stated mapping.

Also unresolved: `04`'s CLI baseline requires **both** `describe --format json` and
`capabilities --format json` without saying how they differ, while `12` uses `describe` and the
committed contract draft uses `manifest`.

### C13 — Specifications are to be copied between repositories

`16-repository-layout-and-packaging.md` proposes specifications live centrally and "be
copied/versioned into product repositories". Copying documents across repositories is exactly how
this repository ended up with duplicate `setup/` and `setup-llm/` copies of this plugin's
specification and ADR-0001 — found and deleted four commits ago on this branch. A second copy drifts
the moment either is edited. Reference by tag or submodule; do not copy.

### C14 — Missing failure modes

Asked for explicitly in `19`. These are unspecified and each has a plausible wrong default:

- **Unparseable plugin output.** Nothing says what a host does when stdout is not valid JSON — the
  likeliest cause being a log line written to the wrong stream. Should be a defined operational
  failure that captures raw output rather than an exception in the coordinator.
- **Undeclared artifacts.** A plugin writes a file it never declared: accepted, ignored, or rejected?
- **Missing required artifacts.** `04`'s example marks an artifact `required: true`; the outcome when
  it is absent is unstated.
- **Artifact path traversal.** `17` tests for it, but no document states the rule: artifact paths must
  be relative, normalized, and confined to the output directory.
- **Agent disappearing mid-execution.** Agents have "last seen", but nothing says what happens to a
  run whose agent vanishes. Does it sit in `Running` forever? Orphan detection is missing.
- **Overlapping schedules.** Cron plus "singleton execution" is mentioned, but the default when a
  schedule fires while the previous run is still going is undefined. Skip, queue, or run concurrently
  are all defensible; silence is not.
- **Mutable image references.** `05` requires digest pinning in production, while `04`'s manifest
  example pins `image: …:1.0.0` — a tag, which is mutable.

### C15 — Over-engineering risks

Also asked for explicitly.

- **24 Platform packages** before a single product ships. `02` calls this "a target decomposition,
  not a requirement to create every package immediately", which helps, but specifying billing,
  licensing, and tenancy in detail invites building them.
- **Seven runtime hosts.** The GitHub plugin is Node _and_ ships a container, so the Docker host
  alone covers it. The Node host earns nothing in Phase One, and the two-runtime manifest example
  invites building it early.
- **A workflow engine with compensation, approvals, DAGs, resumability, and concurrency groups**,
  while `03`'s non-goals say Automator is "not a general BPM suite". That is close to the full BPM
  feature set; the tension deserves naming.
- **A 13-state execution machine** for a first release (see C10).

### C16 — Smaller items

- `05`'s `IPluginRuntimeHost` takes an `ExecutionContext`, which collides with
  `System.Threading.ExecutionContext`. Rename.
- `09` maps `subzerodev.github.sync` to MCP tool `github_sync`, dropping the namespace — two plugins
  with a `sync` command would collide. Use the full namespace.
- `06`'s `${{ }}` expressions need a defined grammar. "Constrained and deterministic" is the right
  intent, but an underspecified template language is a code-injection surface.
- Event naming is inconsistent: `Automator.Execution.Completed` (`07`) versus `WorkflowSucceeded`
  (`06`).
- ADR-005's status is "Accepted in existing practice", which is not an ADR status. Use `Accepted`
  with a context note.
- ADRs 001–004 are all `Proposed` while `18` Phase 0 asks to "create ADRs". They exist; they need
  accepting or revising.
- `12`'s project model includes `"status": "active"` with no definition — derived from `archived`,
  from `pushedAt` recency, or user-set?
- Manifest serialization is listed as an open question in `19`, but `plugin.yaml`, `04`, and `16`
  have already settled it as YAML. See D1 — YAML for a security-relevant file loaded from untrusted
  sources needs a restricted profile.

---

## Critical changes

Ordered. The first four block implementation.

### 1. One exit-code table, defined in the contract only

Merge the two, taking the shell conventions from the ecosystem set and the crash/failure distinction
from `ADR-0002`:

| Code  | Meaning                                 |
| ----- | --------------------------------------- |
| `0`   | Success                                 |
| `2`   | Usage or validation error               |
| `3`   | Operational failure                     |
| `4`   | Partial success                         |
| `5`   | Authentication or authorization failure |
| `6`   | Rate-limited or quota-exhausted         |
| `124` | Timed out                               |
| `130` | Cancelled or interrupted                |

`1` is reserved for uncaught exceptions and never assigned. `04` owns this table; specification 1.1
and `ADR-0002` reference it rather than restating it. Adopting the committed numbering for `2`–`6`
means the in-flight plugin needs no change; only `04` moves.

### 2. Harden the manifest schema until it enforces the prose

Add `$defs` and item schemas for `secrets` and `capabilities`; constrain `version` to semver and
`timeout` to ISO-8601 duration; add `artifacts` to the command schema; set `additionalProperties:
false` on `capabilities` and `secrets` while leaving it `true` on descriptive containers; version the
`$id` path. Then make `secrets` and `capabilities` required, or amend `04` to stop claiming they are.

### 3. Make unknown-capability handling fail closed

An unrecognized key under `capabilities` or `secrets` must cause the host to refuse to run the
plugin. Unrecognized descriptive metadata elsewhere may be ignored. State this as the compatibility
policy `19` asks for, alongside what a host does with a manifest whose `schemaVersion` major exceeds
its own.

### 4. Bind enforcement to hosts, and trust to enforcement

Give each runtime host a declared enforcement level for capabilities — `enforced`, `advisory`, or
`none` — and state the rule that only first-party or development-local plugins may resolve to a host
weaker than `enforced`. Until signing exists (C5), reduce the trust taxonomy to what can actually be
verified.

### 5. Split the envelope from the record, and bound it

State that `04` describes what a plugin emits and `03` describes what Automator stores. Add
`errors[]` to the plugin envelope. Cap `data` at a stated size and require anything larger to be an
artifact.

### 6. Reconcile the GitHub plugin documents

Fold `12` into specification 1.1 rather than maintaining both: adopt collection profiles,
`sync-report.json`, and optional `raw/`; drop the packages and releases indicators; key portfolio
overrides on the immutable ID; settle the CLI name and the introspection command name once.

### 7. Merge the two contract drafts and the two ADR sequences

`setup-llm/docs/specifications/subzerodev-automator-plugin-contract.md` and `04` overlap
substantially, and `setup-llm/docs/decisions/ADR-0003` overlaps `adr/ADR-003`. Two ADR sequences
with different zero-padding in one repository will be misread. Pick one home and one numbering, and
retire the loser explicitly.

---

## Recommended ADRs

| #   | Subject                                         | Why it needs a record                                                             |
| --- | ----------------------------------------------- | --------------------------------------------------------------------------------- |
| 1   | Canonical exit-code table                       | Two committed documents currently disagree; the resolution needs to be findable.  |
| 2   | Manifest compatibility and unknown-field policy | Fail-closed on capabilities is a security decision, not a schema detail.          |
| 3   | Capability enforcement levels per runtime host  | Records that declarations are only as strong as the host running them.            |
| 4   | Manifest serialization and canonicalization     | YAML authoring, restricted profile, canonical JSON for validation and signing.    |
| 5   | Artifact identity and immutability              | Whether a deterministic re-run creates a new artifact or reuses the existing one. |
| 6   | Retry, idempotency, and timeout interaction     | Specifically that a retry must confirm the prior attempt is dead.                 |
| 7   | Platform extraction timing                      | See the phase plan below; this is the largest reversible decision in the set.     |
| 8   | Naming and identity mapping                     | One rule mapping plugin ID to CLI name, image name, package name, and directory.  |

---

## Revised phase plan

The existing `18-roadmap.md` is close. One substantive change and one reordering.

**Build Platform by extraction, not by design.** `02` specifies a 24-package framework compared to
ABP, before any product using it exists. Frameworks earn their abstractions from the second and third
consumer; designed from zero consumers they encode guesses. Automator is the first real consumer, and
it does not exist yet. Building Platform first means committing to hosting, persistence, identity,
and eventing shapes with nothing to validate them against.

The alternative costs little: build Automator's MVP directly on ASP.NET Core with the minimum it
needs, then extract Platform when a second product wants the same pieces. The extraction is
mechanical; the premature abstraction is not.

**Prove the contract on a second plugin before building the orchestrator.** A contract validated by
one implementation is a contract fitted to that implementation. The second plugin is where a
manifest, capability model, and envelope discover what they assumed. It is also cheap insurance: the
orchestrator has nothing to orchestrate until two things exist.

| Phase | Contents                                                                                                | Change from `18`                                                                     |
| ----- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| 0     | Contract stabilization: exit codes, hardened schema, compatibility policy, ADR and naming merge         | Unchanged in intent; the blocking items are now enumerated                           |
| 1     | GitHub plugin to full conformance, plus a conformance suite                                             | Was Phase 1; add the suite as a deliverable                                          |
| 2     | **Second plugin** (Requirements Compiler or documentation) against the same contract                    | **New** — was folded into Phase 1                                                    |
| 3     | Automator local MVP: registry, Docker host, execution model, SQLite, manual invocation, logs, artifacts | Was Phase 3; **drops the local process host, REST, PowerShell, cron, and workflows** |
| 4     | REST, PowerShell client, sequential workflows, cron                                                     | **New** — split out of `03`'s Phase One                                              |
| 5     | Extract Platform from Automator; add persistence, events, notifications, observability packages         | **Moved after** Automator, was Phase 2                                               |
| 6     | Multi-runtime hosts, remote agents, DAG workflows, PostgreSQL, object storage                           | Was Phase 4                                                                          |
| 7     | AI workflow, MCP, approvals                                                                             | Was Phase 5                                                                          |
| 8     | Commercial: identity, tenancy, billing, licensing, hosted control plane                                 | Was Phase 6                                                                          |

The Phase 3 cut is deliberate. `03`'s Phase One lists fifteen items including a REST API, a
PowerShell client, cron scheduling, and workflows — that is a product, not a milestone. Docker host
plus manual invocation plus execution history is enough to prove the orchestration model, and
everything else can follow once it does.

---

## Decisions needed

Ordered by how much downstream work each unblocks.

1. **Platform: extract or design up front?** The largest reversible decision here. Extraction is
   recommended above, but it is a genuine trade — designing up front gives a cleaner package story
   and matches the ABP comparison, at the cost of validating those 24 packages against nothing.
2. **Does the second plugin come before the Automator MVP?** Recommended, and it is the cheapest
   available insurance against a contract fitted to one implementation.
3. **Which contract document survives** — `04`, the `setup-llm` draft, or a merge — and **which ADR
   sequence** is canonical.
4. **Is the local process host in the first Automator release?** Recommended out, because it cannot
   enforce the capability model that the security design depends on.
5. **What is the trust root?** Until this is answered, "trusted signed third-party" cannot be
   implemented and should not appear in the contract.
6. **`sz-` or `subzerodev-` for CLI names**, and `manifest`, `describe`, or `capabilities` for
   introspection. Small, but it is currently inconsistent across three documents and one shipped
   scaffold.
7. **Does the GitHub plugin adopt collection profiles** in place of the fixed request budget in
   `ADR-0002`? Recommended — it is the better design.
8. **Are portfolio overrides a separate file or the `custom` object** on the project model? Either
   works; both are currently specified, and whichever wins must key on the immutable ID.
