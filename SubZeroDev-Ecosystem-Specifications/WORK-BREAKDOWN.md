# Work Breakdown

Derived from the specifications and `REVIEW.md`, ordered by dependency. Sizes are rough: **S** under
a day, **M** a few days, **L** a week or more.

## Mapping to roadmap phases

`SubZeroDev.Ecosystem/18-roadmap.md` owns phase numbering for the ecosystem. This document numbers
work packages, and they are not free to drift:

| Work package | Roadmap phase                                                                                         |
| ------------ | ----------------------------------------------------------------------------------------------------- |
| W0           | Phase 0 — contract stabilization                                                                      |
| W1           | Phase 1 — GitHub plugin to conformance                                                                |
| W2           | Phase 2 — conformance suite and minimal Platform                                                      |
| W3           | Phase 3 — Backlog plugin, with MCP projection and WorkItems                                           |
| W4           | Phase 4 — Automator MVP                                                                               |
| W5           | Phase 5 — Automator interfaces and the Documentation plugin                                           |
| W6           | Platform packages beyond the minimal set; the roadmap folds these into Phases 5–8 as consumers appear |
| W7           | Phases 6–8 — multi-runtime, agents, AI, commercial                                                    |

Build order follows the decision taken: **GitHub plugin → second plugin → Automator MVP.** A
contract validated by one implementation is a contract fitted to that implementation, and the
orchestrator has nothing to orchestrate until two things exist.

---

## W0 — Contract repository (blocking everything)

The contract is depended on by every plugin and by the Automator, and depends on nothing. It must
exist as a tagged artifact before anything can pin it.

| ID       | Work                                                                                    | Size | Depends on |
| -------- | --------------------------------------------------------------------------------------- | ---- | ---------- |
| W0.1     | Create the contract repository from `SubZeroDev.PluginContract/`                        | S    | —          |
| W0.2     | Publish `plugin-manifest.schema.json` at a versioned path and tag `v1.0.0`              | S    | W0.1       |
| ~~W0.3~~ | ~~Add `result-envelope.schema.json`~~ — **done**, authored and validated in place       | —    | —          |
| W0.4     | Manifest canonicalization: YAML → canonical JSON, with a restricted YAML profile        | M    | W0.2       |
| W0.5     | Schema test suite for both schemas: every positive case accepts, every negative rejects | S    | W0.2       |

**W0.4 detail.** YAML is the authoring format and JSON is what gets validated and eventually signed.
The restricted profile matters because manifests will eventually be loaded from untrusted third
parties: YAML 1.2 core schema only, no anchors or aliases, no custom tags, duplicate keys rejected,
and a document size limit. Signing must operate on the canonical JSON, never the YAML — otherwise
two byte-different YAML files with identical meaning produce different signatures.

The starting harness for W0.5 already exists: both schemas were validated during review — the
manifest against the reference document plus twelve negative cases, and the envelope against nine
positive and twenty-seven negative cases. Every negative case rejects and every positive case
accepts, under ajv strict mode. Those checks should become committed tests rather than one-offs, and
W0.5 is that work.

**Two envelope rules are not expressible in JSON Schema** and belong to the conformance suite
instead: the 256 KiB cap on `data`, and `finishedAt` being at or after `startedAt`. They are listed
in the contract's conformance section so they are not lost between the schema and the suite.

---

## W1 — GitHub plugin to conformance

The plugin is already scaffolded, building, and green in CI. This is the work to make it satisfy the
contract.

| ID    | Work                                                                             | Size | Depends on  |
| ----- | -------------------------------------------------------------------------------- | ---- | ----------- |
| W1.1  | Domain models and canonical schemas; identity on the immutable provider ID       | M    | W0.2        |
| W1.2  | Configuration, ports, logging to **stderr**, secret redaction and canary tests   | M    | W1.1        |
| W1.3  | `manifest` command, working in a bare container                                  | S    | W0.2, W1.2  |
| W1.4  | Result envelope emission, with `--json` mode                                     | S    | W1.2        |
| W1.5  | Octokit adapter: discovery, pagination, rate limits, ETags                       | M    | W1.2        |
| W1.6  | **First runnable slice** — `validate` → `sync` → `list` against one real account | S    | W1.5        |
| W1.7  | Collection profiles: Basic, Standard, Detailed                                   | M    | W1.6        |
| W1.8  | Statistics with the documented counting semantics                                | M    | W1.7        |
| W1.9  | Cache, conditional requests, atomic per-file replacement                         | M    | W1.6        |
| W1.10 | Serializers, exports, `sync-report.json`, optional `raw/`                        | M    | W1.8, W1.9  |
| W1.11 | Portfolio overrides keyed by immutable ID                                        | S    | W1.10       |
| W1.12 | Remaining CLI commands and exit-code wiring                                      | M    | W1.10       |
| W1.13 | Docker: labels, digest pinning, non-root verified both ways                      | S    | W1.12       |
| W1.14 | Pass the conformance suite (W2.1)                                                | S    | W2.1, W1.13 |
| W1.15 | Move to its own repository: CI, workflows, docs, `.gitattributes`                | M    | W1.14       |

**W1.6 is the de-risking step.** Everything after it is built against real payloads rather than
against mocks that encode the same assumptions as the code. It is deliberately placed before the
expensive statistics and cache work.

**W1.7 supersedes the fixed request budget** in the GitHub plugin's ADR-002. Collection profiles make API cost an
explicit user choice rather than an implementer's constant, which is the better design and came from
the ChatGPT draft.

Already merged to `main`: scaffold, cross-platform CI, line-ending policy, specification 1.1,
and the GitHub plugin's ADR-002.

---

## W2 — Conformance suite and minimal Platform

The suite is what makes "use the GitHub plugin as a template" verifiable rather than aspirational.
It tests the contract, not the copy.

| ID   | Work                                                                           | Size | Depends on |
| ---- | ------------------------------------------------------------------------------ | ---- | ---------- |
| W2.1 | Conformance runner: takes an image or a local command, runs the checks in `17` | M    | W0.2       |
| W2.2 | Fixture plugins: echo, failing, timeout, artifact-producing, secret-leaking    | M    | W2.1       |
| W2.3 | Wire conformance into plugin CI as a required check                            | S    | W2.1       |
| W2.4 | Minimal Platform: Abstractions, Core, Hosting                                  | L    | —          |
| W2.5 | Minimal Platform: Persistence, Observability, Testing                          | L    | W2.4       |
| W2.6 | Extract the shared GitHub client from the GitHub plugin                        | M    | W1.5       |
| W2.7 | Project Setup plugin: plan/apply, inference, rulesets                          | M    | W2.6       |

**W2.2 matters more than it looks.** The secret-leaking and failing fixtures are how you prove the
suite detects problems rather than merely passing everything you point it at. A conformance suite
that has never failed is not evidence.

**W2.6 is the extraction guard being satisfied, not bypassed.** The rule is that a capability becomes
a shared component when a _second_ consumer needs it. The GitHub client now has four candidates — the
GitHub plugin, the Project Setup plugin, the Release plugin, and Backlog — so the condition is
met several times over. The language boundary limits what sharing can mean: the three Node consumers
share a package, and Backlog keeps its own Python path. That the answer differs by language is itself
the argument for the contract being a process boundary rather than a library.

**W2.7 is not the second plugin.** It lands in Phase 2 because W2.6 is where its dependency appears,
not because it displaces Backlog. The build order — GitHub → Backlog → Automator — is about which
implementation validates the contract, and Backlog holds that slot because it is Python, writes
externally, and needs MCP. Project Setup is Node and reuses the transport the GitHub plugin
established, so it tests nothing new about the contract.

**W2.7 cannot provision its own repository.** The first repositories are created by hand; the plugin
exists for the ones after, and for reconciling drift in all of them.

**W2.4 and W2.5 run in parallel with the conformance track**, per roadmap Phase 2. These six packages
are the ones genuinely hard to retrofit — hosting shape, transaction boundaries, observability
wiring, and test infrastructure all cost far more to introduce later than to start with. Everything
else waits for a second consumer.

---

## W3 — Backlog plugin, MCP projection, and WorkItems

Where the contract discovers what it assumed. The plugin is the means; the list of contract
corrections is the deliverable.

| ID    | Work                                                                           | Size | Depends on |
| ----- | ------------------------------------------------------------------------------ | ---- | ---------- |
| W3.1  | Port `parse_todo.py` and `sync_lib.py` unchanged; 115 tests must pass unedited | S    | —          |
| W3.2  | Extract `SubZeroDev.WorkItems`: model, stable IDs, markers, reconciliation     | M    | W3.1       |
| W3.3  | GitHub tracker provider behind the library's write interface                   | M    | W3.2       |
| W3.4  | Plan store: opaque token, TTL, single use, state fingerprint                   | S    | W3.2       |
| W3.5  | Plugin CLI: `validate`, `plan`, `apply`, `manifest`                            | M    | W3.3, W3.4 |
| W3.6  | Round trip against a fake tracker returning floats for number fields           | M    | W3.5       |
| W3.7  | `SubZeroDev.MCP` projection library, Python implementation                     | M    | W0.2       |
| W3.8  | `mcp` command projecting the manifest                                          | S    | W3.5, W3.7 |
| W3.9  | Live verification against a throwaway repository                               | S    | W3.6, W3.8 |
| W3.10 | Conformance, signing, publish                                                  | S    | W3.9, W2.1 |
| W3.11 | **Record every contract change it forced; cut contract `1.1.0`**               | S    | W3.10      |

**W3.6 is not optional.** Three of the four known bugs were invisible to unit tests and appeared only
under a replayed round trip. The fake must return number fields as floats — that single quirk is what
broke convergence and what the unit tests missed.

**W3.11 is the actual output of this phase.**

## W4 — Automator MVP

Deliberately smaller than `03`'s Phase One, which lists fifteen items including a REST API, a
PowerShell client, cron scheduling, and workflows. That is a product, not a milestone.

| ID   | Work                                                                       | Size | Depends on |
| ---- | -------------------------------------------------------------------------- | ---- | ---------- |
| W4.1 | Plugin registry: install from OCI reference, store manifest, verify digest | M    | W3.3       |
| W4.2 | Execution model and state machine — **6 states, not 13**                   | M    | W4.1       |
| W4.3 | Docker runtime host with the security defaults from `05`                   | L    | W4.2       |
| W4.4 | Capability policy evaluation and enforcement binding                       | M    | W4.3       |
| W4.5 | Manual invocation, log capture, artifact registration                      | M    | W4.3       |
| W4.6 | SQLite persistence and execution history                                   | M    | W4.2       |
| W4.7 | Secret storage, injection, and output scanning                             | M    | W4.5       |

**Cut from the MVP, with reasons.** The local process host is out because it cannot enforce the
capability model, which would make policy decorative on the one host that most needs it. REST,
PowerShell, cron, and workflows are out because Docker host plus manual invocation plus execution
history is enough to prove the orchestration model works.

**W4.2 detail.** The thirteen states in `03` include `Skipped` and `Compensated`, which only mean
something once workflows and compensation exist, and `Validated`/`Resolving`/`Starting`, which are
internal transitions that may not need persisting. Six suffice: `Queued`, `Running`, `Succeeded`,
`Failed`, `Cancelled`, `TimedOut`.

---

## W5 — Automator interfaces and the Documentation plugin

| ID   | Work                                                                     | Size | Depends on |
| ---- | ------------------------------------------------------------------------ | ---- | ---------- |
| W5.1 | REST API over the execution model                                        | M    | W4.5       |
| W5.2 | PowerShell client module                                                 | M    | W5.1       |
| W5.3 | Sequential workflows                                                     | L    | W4.5       |
| W5.4 | Cron scheduling, with an explicit overlap policy                         | M    | W5.3       |
| W5.5 | Notifications                                                            | M    | W5.3       |
| W5.6 | Documentation plugin: wrap the existing Docusaurus image in the contract | M    | W2.1       |

**W5.6** is cheap by design: the image already exists, so the work is wrapping it in the contract
rather than building a capability. It gives the workflow engine a second real plugin to compose.

**W5.4 detail.** The overlap policy — what happens when a schedule fires while the previous run is
still going — is currently undefined. Skip, queue, or run concurrently are all defensible; silence
is not.

---

## W6 — Platform packages beyond the minimal set

The minimal Platform — Abstractions, Core, Hosting, Persistence, Observability, Testing — is built in
W2, alongside the conformance suite. This phase is the remainder.

| ID   | Work                                                                     | Size | Depends on |
| ---- | ------------------------------------------------------------------------ | ---- | ---------- |
| W6.1 | Identify what Automator built that a second consumer would also want     | S    | W5.5       |
| W6.2 | Promote configuration, events, notifications, storage, and jobs packages | L    | W6.1       |
| W6.3 | Prove reuse by building the second consumer on them                      | L    | W6.2       |

**The guard, restated because it is the whole risk.** A candidate becomes a package when a _second_
consumer needs it, not when the first one does. Until then it lives inside Automator, where it is
cheap to change. Without that guard the minimal six becomes the original twenty-four by increments,
one reasonable-looking addition at a time.

## W7 — Later phases

Multi-runtime hosts, remote agents, DAG workflows, PostgreSQL and object storage, the Automator's
brokered MCP endpoint, approval steps, and the commercial layer. The MCP **projection** is not here —
it ships in W3 with the first plugin that needs it. Specified in the roadmap; not broken down until W4 exists, because the
breakdown would be guesswork.

---

## Cross-cutting work

Not owned by any single phase.

| ID      | Work                                                             | Size | Notes                                                                                               |
| ------- | ---------------------------------------------------------------- | ---- | --------------------------------------------------------------------------------------------------- |
| ~~X1~~  | ~~Split `07`, `11`, `17` by destination repository~~             | —    | **Done.** Also split `08` and the five build-tooling plugins                                        |
| ~~X2~~  | ~~Renumber ADRs per repository once split~~                      | —    | **Done.** Filenames, titles, and status format now agree; each ADR records its former number        |
| ~~X3~~  | ~~Retire the superseded contract draft under `setup-llm/`~~      | —    | **Done.** Nothing about the ecosystem remains there; it holds workstation-toolkit docs only         |
| ~~X4~~  | ~~Signing ADR: mechanism, trust root, verification, revocation~~ | —    | **Done.** `PluginContract/adr/ADR-004`; all four trust levels now establishable                     |
| ~~X5~~  | ~~Orphan-execution handling~~                                    | —    | **Designed** in `07-execution-events-and-artifacts.md`: lease, heartbeat, terminal `Orphaned` state |
| ~~X6~~  | ~~Artifact identity on deterministic re-run~~                    | —    | **Decided**: content-addressed blob, per-execution record                                           |
| X7      | Choose the Docker plugin's builder — rootless or socket          | M    | **Owned outside this workspace.** Decides whether socket access is ever granted                     |
| X8      | Manifest-driven generation in ContainerPSGenerator               | M    | **Owned outside this workspace.** Replaces `--help` inference with declared input schemas           |
| ~~X9~~  | ~~Update `18` and `19` to the decisions taken~~                  | —    | **Done.** `18` now owns the phase vocabulary; `19` separates open from resolved                     |
| ~~X10~~ | ~~Update `16-repository-layout-and-packaging.md`~~               | —    | **Done.** Move-don't-copy is now a rule, with the two incidents that motivated it                   |
| ~~X11~~ | ~~Per-repository `README.md`, `AGENTS.md`, and `CLAUDE.md`~~     | —    | **Done.** Every destination repository now carries its own instructions                             |
| X12     | Retire the numeric filename prefixes when each repository splits | S    | They number one document set, not fifteen — see below                                               |
| X14     | Settle a plugin naming convention and rename accordingly         | S    | **Before first publish.** No rule connects the current names; free now, expensive after publish     |
| X13     | Check each repeated conventions block against the canonical copy | S    | A repeated block that nothing compares is a copy that drifts. Suggested in review of PR #13         |

**X12 detail.** The `NN-` prefixes order a single ecosystem-wide document set, and that set no longer
exists. Six files are numbered `15`, and `07`, `08`, `10`, `11`, and `17` each appear in two
repositories. Inside `SubZeroDev.Plugins.Build`, a lone `15-build-plugin.md` implies fourteen missing
predecessors.

Not done now, because renaming thirty files would break every cross-document reference in the same
change. It belongs to each repository's split commit, where the reference rewrite is local: drop the
prefix, keep the name. `README.md` in each repository already carries the ordering the prefixes were
doing.

---

## Decisions still needed

**Two are owned outside this workspace** and block their own plugins rather than the critical path:
the Docker plugin's builder (X7) and ContainerPSGenerator's generation path (X8).

**Nine remain open inside it**, none blocking Phase 1: six on MCP — how the projection layer ships,
whether the Automator brokers direct plugins as upstreams, whether prompts are projected, whether
`outputSchema` becomes required, whether direct mode authenticates, and where the exposure allowlist
lives; one on WorkItems — whether the Requirements Compiler publishes directly or composes; and two
on the Backlog plugin — multi-repository targeting, and whether it shares a GitHub provider library
with the GitHub plugin.

`SubZeroDev.Ecosystem/19-open-questions.md` is the consolidated register and must agree with the sum
of the per-document lists. It once claimed one open item while ten had accumulated, which is why the
count is stated here rather than described.

## Critical path

```text
W0.1 → W0.2 → W1.1 → W1.2 → W1.5 → W1.6 → W1.9 → W1.12 → W1.14 → W3.2 → W3.3 → W4.1 → W4.3 → W4.5
```

W2.1 must land before W1.14, and can be built in parallel with W1.5 onward. Everything in W5 and W6
sits off the critical path until W4.5 completes.

The two steps that most reduce risk are **W1.6**, the first run against a real account, and **W3.11**,
the list of things the second plugin proved the contract got wrong. Both are cheap; both prevent
expensive rework.
