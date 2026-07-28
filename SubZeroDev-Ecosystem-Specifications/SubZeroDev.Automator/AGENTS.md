# Working in the Automator

The Automator runs plugins: runtime hosts, workflows, schedules, agents, execution history,
artifacts, a REST API, and an MCP surface. It sits on Platform and orchestrates plugins.

## Two boundaries, both easy to erode

**Upward: the Automator never absorbs plugin business logic.** If the Automator needs to know what a
GitHub repository is, or how a backlog item maps to an issue, something is in the wrong place. It
knows about commands, envelopes, exit codes, and artifacts — the contract's vocabulary, and nothing
past it.

**Downward: a plugin must stay usable without the Automator.** This is the harder one, because
erosion here looks like generosity. The Automator offers retries, so a plugin stops handling its own
failures. It offers a credential broker, so a plugin stops reading the environment. Each step is
reasonable and the sum is a plugin that only runs under a host.

The rule from ADR-002 in `SubZeroDev.PluginContract`: **the Automator may add scheduling, history,
approvals, and credential brokering _around_ a run; it may not become part of what a run needs to
succeed.** Anything it offers must degrade to the standalone path. That constrains the Automator's
design, deliberately.

## Plugins execute out of process. There is no exception.

Not "by default" — see `adr/ADR-001`. The Automator never loads independently versioned plugin code
into the control-plane process, and there is no trusted-plugin carve-out, because signing establishes
who published something rather than whether its dependency graph is safe to load.

What runs in-process is the Automator's own code: runtime hosts, adapters, the projection layer.
These ship and version with the Automator and are not plugins.

Process-start cost is paid on every invocation and is accepted: the workload is not latency
sensitive, and a design tuned for a latency budget nobody has would trade containment for nothing.

## Capability enforcement is per runtime host

Only the Docker host enforces the capability model. Process-based hosts enforce nothing.

That difference must stay visible. A UI or API that reports a plugin's declared capabilities without
reporting whether the host can enforce them lets an operator believe a `process` runtime is
sandboxed. The plugin declares what it needs, the host declares what it can enforce, and the operator
sees both.

## Orphan detection

Execution liveness runs on a lease and heartbeat — 30-second heartbeat, 120-second lease. An
execution whose lease expires becomes `Orphaned`, which is **terminal and never auto-retried**.

The reason is that an orphan is precisely the case where the Automator does not know whether the work
completed. Retrying a non-idempotent command whose outcome is unknown is how you get two of
something. A retry must confirm the previous attempt is dead before starting, and container stop is
asynchronous.

## The execution record is not the result envelope

The envelope is what the **plugin** emits and is specified in the contract. The execution record is
the Automator's, and additionally carries queue timing, retry history, host and agent metadata, and a
log reference.

Conflating the two was an inconsistency in the original document set. Keep them separate, and do not
restate the envelope's shape here — reference the contract's schema.

## The workflow expression grammar is a security surface

`06-workflow-engine.md` uses `${{ }}` expressions. "Constrained and deterministic" is the right
intent, but an underspecified template language evaluated over workflow inputs is a code-injection
surface. It needs a defined grammar with an explicit function list before it is implemented, not
after. This is recorded as an open question and is not a detail to settle in code.

## Event naming

`Automator.Execution.Completed` — namespaced, dotted, past tense. The specifications currently
contain a second style (`WorkflowSucceeded`) inherited from the draft; the namespaced form wins, and
a plugin command name alone is not a unique event name, since two plugins with a `sync` command would
collide.

## What is here and what moved

| Here                                   | The half that went to Platform      |
| -------------------------------------- | ----------------------------------- |
| `07-execution-events-and-artifacts.md` | The event envelope, bus, and outbox |
| `11-operations.md`                     | Observability primitives            |
| `10-security-model.md`                 | Tenancy, billing, licensing         |
| `08-clients.md`                        | —                                   |

`08-clients.md` covers the Automator's own CLI and PowerShell modules. The conventions **plugins**
follow are `08-cli-conventions.md` in `SubZeroDev.PluginContract` — a different document with a
confusingly similar number.

## Before you finish

- Check that nothing you added requires the Automator to understand a plugin's domain.
- Check that nothing you added makes a plugin command meaningless without a host.
- If you touched the execution record, confirm you did not restate the envelope.

## Conventions

These hold in every SubZeroDev specification repository. The canonical copy of this block is
`AGENTS.md` in the Architecture repository; it is repeated here because a repository has to stand on
its own.

- **Reference, never restate.** A rule that lives in another document is linked, not copied. Two
  copies of a rule is a promise they will diverge and a guarantee nobody will notice which is stale.
- **The plugin contract outranks plugin specifications.** Where a plugin document and the contract
  disagree, the contract is correct and the plugin document has drifted. See ADR-003 in
  `SubZeroDev.PluginContract`.
- **A decision gets an ADR.** Status is exactly one of `Proposed`, `Accepted`, `Superseded`, or
  `Deprecated`, under a `## Status` heading. An accepted ADR states its context, the decision, the
  consequences _including the costs_, and the alternatives it rejected and why. "Accepted in existing
  practice" is not a status — ratifying current practice is a note in the context.
- **Move, never copy.** A specification has exactly one home. Where another repository needs the
  text, it references a tagged commit rather than duplicating the file.
- **Give reasons.** These documents are read by people deciding what to build. An assertion with no
  reason cannot be evaluated, and cannot be safely revised by someone who was not there when it was
  written.
- **Markdown is Prettier-formatted**, 100 columns, LF endings.
