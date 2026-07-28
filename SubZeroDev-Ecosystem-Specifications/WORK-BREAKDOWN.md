# Work Breakdown

Derived from the specifications and `REVIEW.md`, ordered by dependency. Sizes are rough: **S** under
a day, **M** a few days, **L** a week or more.

Build order follows the decision taken: **GitHub plugin → second plugin → Automator MVP.** A
contract validated by one implementation is a contract fitted to that implementation, and the
orchestrator has nothing to orchestrate until two things exist.

---

## W0 — Contract repository (blocking everything)

The contract is depended on by every plugin and by the Automator, and depends on nothing. It must
exist as a tagged artifact before anything can pin it.

| ID   | Work                                                                                    | Size | Depends on |
| ---- | --------------------------------------------------------------------------------------- | ---- | ---------- |
| W0.1 | Create the contract repository from `SubZeroDev.PluginContract/`                        | S    | —          |
| W0.2 | Publish `plugin-manifest.schema.json` at a versioned path and tag `v1.0.0`              | S    | W0.1       |
| W0.3 | Add `result-envelope.schema.json` — currently prose in `04`, not a schema               | S    | W0.1       |
| W0.4 | Manifest canonicalization: YAML → canonical JSON, with a restricted YAML profile        | M    | W0.2       |
| W0.5 | Schema test suite: the reference manifest validates, and each negative case is rejected | S    | W0.2       |

**W0.4 detail.** YAML is the authoring format and JSON is what gets validated and eventually signed.
The restricted profile matters because manifests will eventually be loaded from untrusted third
parties: YAML 1.2 core schema only, no anchors or aliases, no custom tags, duplicate keys rejected,
and a document size limit. Signing must operate on the canonical JSON, never the YAML — otherwise
two byte-different YAML files with identical meaning produce different signatures.

The starting harness for W0.5 already exists: the schema was validated during this review against
the reference manifest plus twelve negative cases, all of which reject. That check should become a
committed test rather than a one-off.

---

## W1 — GitHub plugin to conformance

The plugin is already scaffolded, building, and green in CI. This is the work to make it satisfy the
contract.

| ID    | Work                                                                             | Size | Depends on  |
| ----- | -------------------------------------------------------------------------------- | ---- | ----------- |
| W1.1  | Domain models and canonical schemas; identity on the immutable provider ID       | M    | W0.2        |
| W1.2  | Configuration, ports, logging to **stderr**, secret redaction and canary tests   | M    | W1.1        |
| W1.3  | `manifest` command, working in a bare container                                  | S    | W0.2, W1.2  |
| W1.4  | Result envelope emission, with `--json` mode                                     | S    | W0.3, W1.2  |
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

**W1.7 supersedes the fixed request budget** in ADR-0002. Collection profiles make API cost an
explicit user choice rather than an implementer's constant, which is the better design and came from
the ChatGPT draft.

Already done on the current branch: scaffold, cross-platform CI, line-ending policy, specification
1.1, and ADR-0002.

---

## W2 — Conformance suite

The suite is what makes "use the GitHub plugin as a template" verifiable rather than aspirational.
It tests the contract, not the copy.

| ID   | Work                                                                                | Size | Depends on |
| ---- | ----------------------------------------------------------------------------------- | ---- | ---------- |
| W2.1 | Conformance runner: takes an image or a local command, runs the nine checks in `04` | M    | W0.2, W0.3 |
| W2.2 | Fixture plugins: echo, failing, timeout, artifact-producing, secret-leaking         | M    | W2.1       |
| W2.3 | Wire conformance into plugin CI as a required check                                 | S    | W2.1       |

**W2.2 matters more than it looks.** The secret-leaking and failing fixtures are how you prove the
suite detects problems rather than merely passing everything you point it at. A conformance suite
that has never failed is not evidence.

---

## W3 — Second plugin

Where the contract discovers what it assumed. Requirements Compiler is the more valuable capability;
the documentation plugin is the cheaper test because the image already exists.

| ID   | Work                                                             | Size | Depends on |
| ---- | ---------------------------------------------------------------- | ---- | ---------- |
| W3.1 | Choose the second plugin — see Decisions below                   | S    | —          |
| W3.2 | Implement it against the contract, passing conformance           | L    | W2.1, W3.1 |
| W3.3 | Record every contract change it forced, and cut contract `1.1.0` | S    | W3.2       |

**W3.3 is the actual deliverable of this phase.** The plugin is the means; the list of things the
contract got wrong is the output.

---

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

## W5 — Automator interfaces

| ID   | Work                                             | Size | Depends on |
| ---- | ------------------------------------------------ | ---- | ---------- |
| W5.1 | REST API over the execution model                | M    | W4.5       |
| W5.2 | PowerShell client module                         | M    | W5.1       |
| W5.3 | Sequential workflows                             | L    | W4.5       |
| W5.4 | Cron scheduling, with an explicit overlap policy | M    | W5.3       |
| W5.5 | Notifications                                    | M    | W5.3       |

**W5.4 detail.** The overlap policy — what happens when a schedule fires while the previous run is
still going — is currently undefined. Skip, queue, or run concurrently are all defensible; silence
is not.

---

## W6 — Platform extraction

Platform is extracted from a working Automator rather than designed against no consumer. The
repository exists; this is when it gets filled.

| ID   | Work                                                                | Size | Depends on |
| ---- | ------------------------------------------------------------------- | ---- | ---------- |
| W6.1 | Identify what Automator built that generalizes                      | S    | W5.5       |
| W6.2 | Extract hosting, configuration, persistence, observability, testing | L    | W6.1       |
| W6.3 | Prove reuse by building the second consumer on it                   | L    | W6.2       |

**Sequencing note.** The specification in `02` lists 24 packages compared to ABP. Frameworks earn
their abstractions from the second and third consumer; designed from zero consumers they encode
guesses. Extraction is mechanical; premature abstraction is not. This ordering was recommended in
review and is not yet an accepted decision — see Decisions.

---

## W7 — Later phases

Multi-runtime hosts, remote agents, DAG workflows, PostgreSQL and object storage, MCP, approvals,
and the commercial layer. Specified in the roadmap; not broken down until W4 exists, because the
breakdown would be guesswork.

---

## Cross-cutting work

Not owned by any single phase.

| ID      | Work                                                             | Size | Notes                                                                                               |
| ------- | ---------------------------------------------------------------- | ---- | --------------------------------------------------------------------------------------------------- |
| ~~X1~~  | ~~Split `07`, `11`, `17` by destination repository~~             | —    | **Done.** Also split `08` and the five build-tooling plugins                                        |
| X2      | Renumber ADRs per repository once split                          | S    | Two sequences currently exist with different zero-padding                                           |
| X3      | Retire the superseded contract draft under `setup-llm/`          | S    | Superseded by `04`; ADR-0003 there needs marking                                                    |
| ~~X4~~  | ~~Signing ADR: mechanism, trust root, verification, revocation~~ | —    | **Done.** `PluginContract/adr/ADR-004`; all four trust levels now establishable                     |
| ~~X5~~  | ~~Orphan-execution handling~~                                    | —    | **Designed** in `07-execution-events-and-artifacts.md`: lease, heartbeat, terminal `Orphaned` state |
| ~~X6~~  | ~~Artifact identity on deterministic re-run~~                    | —    | **Decided**: content-addressed blob, per-execution record                                           |
| X7      | Choose the Docker plugin's builder — rootless or socket          | M    | **Owned outside this workspace.** Decides whether socket access is ever granted                     |
| X8      | Manifest-driven generation in ContainerPSGenerator               | M    | **Owned outside this workspace.** Replaces `--help` inference with declared input schemas           |
| ~~X9~~  | ~~Update `18` and `19` to the decisions taken~~                  | —    | **Done.** `18` now owns the phase vocabulary; `19` separates open from resolved                     |
| ~~X10~~ | ~~Update `16-repository-layout-and-packaging.md`~~               | —    | **Done.** Move-don't-copy is now a rule, with the two incidents that motivated it                   |

---

## Decisions still needed

One, and it is owned outside this workspace: the Docker plugin's builder, and ContainerPSGenerator's
generation path.

Everything else is decided. `SubZeroDev.Ecosystem/19-open-questions.md` records the full set, and
each document states what would change a decision that rests on an assumption.

## Critical path

```text
W0.1 → W0.2 → W1.1 → W1.2 → W1.5 → W1.6 → W1.9 → W1.12 → W1.14 → W3.2 → W3.3 → W4.1 → W4.3 → W4.5
```

W2.1 must land before W1.14, and can be built in parallel with W1.5 onward. Everything in W5 and W6
sits off the critical path until W4.5 completes.

The two steps that most reduce risk are **W1.6**, the first run against a real account, and **W3.3**,
the list of things the second plugin proved the contract got wrong. Both are cheap; both prevent
expensive rework.
