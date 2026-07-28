# Roadmap

**This document defines the phase vocabulary for the whole ecosystem.** No other document maintains
its own numbering; where one needs to state scope, it references a phase from here.

That rule exists because the original set used "Phase One" to mean three different things — the
Automator's fifteen-item milestone, Platform's package scope, and this roadmap's first plugin phase.

## Decisions this reflects

| Decision           | Choice                                                                                                                                      |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Platform           | Minimal Platform built alongside Automator; six packages, rest deferred                                                                     |
| Build order        | GitHub plugin → Backlog plugin → Automator MVP. Project Setup is Phase 2 tooling and does not sit in this sequence                          |
| Second plugin      | Backlog — Python, writes externally, and needs a direct MCP surface. "Second" means second to validate the contract, not second to be built |
| Local process host | Out of the MVP                                                                                                                              |
| Contract           | Its own repository, tagged independently                                                                                                    |

## Phase 0 — Contract stabilization

Blocking. Small.

- Create the contract repository and tag `v1.0.0`
- Publish the manifest and result-envelope schemas at version-pathed URLs. Both are written and
  validated; what remains is publishing them
- Manifest canonicalization: YAML authoring, restricted profile, canonical JSON for validation
- Schema test suite, including the negative corpus
- Resolve remaining specification contradictions. Naming and ADR numbering are settled
- **Reserve the `SubZeroDev.*` identifiers** on NuGet, npm, the container registry, and PowerShell
  Gallery. Free, and it has to happen before the first publish rather than after the first
  collision — see `adr/ADR-002`

## Phase 1 — GitHub plugin to conformance

The plugin is already scaffolded, building, and green. This is the work to make it satisfy the
contract.

Domain models on immutable identity; configuration and secret safety with logs on stderr; the
`manifest` command; the result envelope; the Octokit adapter; **a first runnable slice against one
real account**; collection profiles; statistics; cache; exports; and passing conformance.

The runnable slice is placed before the expensive statistics and cache work deliberately — it is the
cheapest available de-risking, and everything after it is built against real payloads rather than
mocks that encode the same assumptions as the code.

## Phase 2 — Conformance suite and minimal Platform

Two tracks that do not block each other.

**Conformance suite:** the runner, the checks specified in the contract's `17-conformance.md`, and
the fixture plugins — including the leaky,
noisy, nondeterministic, and traversing fixtures that must _fail_, because a suite that has never
failed is not evidence.

**Minimal Platform:** Abstractions, Core, Hosting, Persistence, Observability, Testing. Six packages,
chosen because they are the ones genuinely hard to retrofit. Everything else waits for a second
consumer.

**Project Setup plugin.** Provisioning and governing repositories, built here because it is the first
consumer that forces the shared GitHub client out of the GitHub plugin — the extraction guard being
satisfied rather than bypassed. It is kept out of Phase 1 because it needs the Octokit patterns Phase
1 establishes.

**It does not displace Backlog as the second plugin**, and the two orderings are not in conflict once
the terms are separated. The build order above is about **validating the contract**: Backlog is
second because it is Python, writes externally, and needs MCP — the three things the GitHub plugin
never exercises. Project Setup exercises none of them; it is Node, and it reuses the transport the
GitHub plugin already established. It is tooling that happens to land in Phase 2 because that is when
its dependency exists, not a contender for the second-implementation slot.

Note the ordering it cannot escape: it provisions repositories, and one of them is its own. The first
repositories are created by hand; the plugin exists for everything after, and for reconciling the
drift that accumulates in all of them.

## Phase 3 — Backlog plugin

The second plugin, and the point of it is not the plugin.

**This supersedes the earlier choice of the Documentation plugin.** Documentation was picked as the
cheapest contract test, since its image already exists. The Backlog plugin is a better one for the same
cost, and the difference is what it exercises:

|                 | Documentation             | Backlog                                             |
| --------------- | ------------------------- | --------------------------------------------------- |
| Language        | Node, as the first plugin | **Python** — a real test of language neutrality     |
| Direction       | Builds a site             | **Writes to a system other people see**             |
| Idempotency     | Rebuild is cheap          | **Convergence is its whole design**                 |
| Partial failure | Rare                      | **Expected on a large file**                        |
| Approval        | Not needed                | **Plan-apply, structurally enforced**               |
| MCP             | Not needed                | **First plugin needing a direct AI-client surface** |

It also arrives with a working implementation and 115 passing tests, so the contract is tested
against real code rather than against a design written to fit it.

The Documentation plugin remains valuable and moves to Phase 5, where wrapping an existing image is
straightforward once the contract has been proven twice.

**The deliverable is still the list of things the contract got wrong**, and a contract `1.1.0` cut
from it. The working plugin is the means.

Two shared pieces land here because this is the first plugin that needs them:

- **`SubZeroDev.MCP`** — the manifest-to-tool projection, used by this plugin's direct server and
  later by the Automator's brokered one.
- **`SubZeroDev.WorkItems`** — the work-item model, stable IDs, reconciliation, and tracker
  providers, extracted because the Requirements Compiler consumes the same code in Phase 7.
  Providers are in scope: convergence _is_ the write path, and reconciliation that cannot execute its
  own actions hands each consumer the half where all four known bugs lived.

Extracting `WorkItems` now rather than later is the one place the second-consumer rule is applied
early, and deliberately: the second consumer is already specified, and the alternative is writing
convergence twice.

## Phase 4 — Automator MVP

- plugin registry, installing from an OCI reference and verifying the digest
- Docker runtime host with the security defaults, and its capability enforcement binding
- execution model, six-state machine, lease and heartbeat with orphan detection
- manual invocation, log capture, artifact registration
- SQLite persistence and execution history
- secret storage, injection, and output scanning

No local process host, no REST, no workflows, no scheduling. This phase proves the orchestration
model; it is not the product.

## Phase 5 — Automator interfaces and the Documentation plugin

REST API, PowerShell client, sequential workflows, cron scheduling with an explicit overlap policy,
and notifications through Platform.

The Documentation plugin lands here: wrapping the existing Docusaurus image is straightforward once
the contract has been exercised twice, and it gives the workflow engine a second real plugin to
compose.

The Automator's brokered MCP server also lands here, consuming the projection layer built in
Phase 3 rather than reimplementing it.

## Phase 6 — Multi-runtime and remote agents

The remaining runtime hosts including local process, the agent protocol and selection, DAG workflows,
PostgreSQL, and object storage.

## Phase 7 — AI and project workflow

Requirements Compiler, GitHub project publishing, approval steps, and AI provider policy. MCP is not
new here — the projection ships in Phase 3 and the Automator's brokered endpoint in Phase 5; this
phase consumes both.

## Phase 8 — Commercial platform

Identity, organizations, tenancy, billing, licensing, usage metering, hosted control plane, and
customer-hosted agents.

Carry a tenant identifier from the first schema regardless; the feature waits, the column does not.

## Explicit deferrals

Marketplace, Kubernetes, low-code visual designer, distributed event bus, plugin hot-loading in the
control process, enterprise SSO, automatic destructive reconciliation.

## Critical path

```text
Phase 0 → GitHub to conformance → Backlog plugin → contract 1.1 → Automator MVP
```

The two steps that most reduce risk are the **first runnable slice** in Phase 1 and the
**contract-correction list** from Phase 3. Both are cheap; both prevent expensive rework.

The minimal Platform in Phase 2 sits off this path and can proceed in parallel.
