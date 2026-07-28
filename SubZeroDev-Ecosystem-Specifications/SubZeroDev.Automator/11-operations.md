# Operations

Split from `11-observability-and-operations.md`. The observability primitives moved to
`SubZeroDev.Platform/11-observability.md`. This document covers what an operator does with a running
Automator.

## Operational goals

- explain every execution after the fact
- identify what is running now
- diagnose a failure without reproducing it
- correlate control-plane activity with agent activity
- detect stuck work rather than waiting for someone to notice
- preserve enough history to answer "what changed"

## Execution log dimensions

Every log line emitted during an execution carries: execution ID, workflow execution ID, workflow
step ID, plugin ID, command ID, agent ID, tenant, correlation ID, severity, timestamp, and stream.

`stream` is one of `stdout`, `stderr`, or `structured`, and the distinction is load-bearing: the
plugin contract makes stdout the machine channel, so a line arriving on stdout that is not the result
envelope is itself a defect worth surfacing.

### Log volume

Plugin output is untrusted in size. A plugin in a retry loop can emit gigabytes.

- Per-execution log capture is capped, default 100 MB.
- On exceeding the cap, capture switches to head-and-tail retention with a gap marker, rather than
  truncating the end — the beginning explains what started and the end explains what failed, and the
  middle of a runaway loop is the least informative part.
- Exceeding the cap is itself recorded on the execution.

## Metrics

Domain metrics, all with bounded label sets — never labelled by execution ID:

| Metric                         | Labels                   | Purpose                     |
| ------------------------------ | ------------------------ | --------------------------- |
| Executions started / completed | plugin, command, outcome | Throughput and failure rate |
| Execution duration             | plugin, command          | Performance regression      |
| Queue time                     | plugin, priority         | Capacity pressure           |
| Retry count                    | plugin, command          | Flakiness                   |
| Timeouts                       | plugin, command          | Timeout tuning              |
| Active executions              | agent                    | Saturation                  |
| Orphaned executions            | agent                    | Agent instability           |
| Agent availability             | agent                    | Fleet health                |
| Plugin startup time            | plugin, runtime          | Image or cache problems     |
| Artifact bytes stored          | retention class          | Storage growth              |
| Rate-limit events              | plugin                   | External quota pressure     |

**Orphaned executions deserves an alert, not just a dashboard.** A rising orphan count means agents
are dying mid-work, and it is otherwise invisible until a singleton schedule stops firing.

## Traces

```text
API / MCP / CLI request
→ execution created
→ queued
→ runtime resolved
→ dispatched to agent
→ plugin process or container
→ artifact upload
→ notification
```

Trace context propagates into the plugin environment, so a plugin that chooses to emit spans joins
the same trace. A plugin that does not still appears as a single span.

## Health

| Scope         | Checks                                                                                       |
| ------------- | -------------------------------------------------------------------------------------------- |
| Control plane | database, storage, event processing, outbox drain, scheduler, secret provider, agent gateway |
| Agent         | connectivity, disk, runtime availability, Docker daemon, plugin cache, concurrency headroom  |
| Plugin        | install validation, runtime availability, optional health command                            |

**Outbox drain is the check most likely to be forgotten.** A stalled outbox means events stop
flowing and therefore notifications stop firing, while everything else looks healthy — a silent
failure that presents as "nothing is wrong" right up until someone asks why they got no alerts.

## Detecting stuck work

Three distinct conditions, often conflated:

| Condition        | Signal                                          | Action                          |
| ---------------- | ----------------------------------------------- | ------------------------------- |
| Running too long | Duration exceeds the command's declared timeout | Timeout handling, exit `124`    |
| Lease expired    | No heartbeat within the lease window            | Orphan, terminal                |
| Queued too long  | Queue time exceeds a threshold with no capacity | Alert; not an execution failure |

The third is a capacity problem, not an execution problem, and treating it as a failure produces
noise and hides the real cause.

## Administrative actions

- disable a plugin
- quarantine a specific plugin version
- cancel an execution
- drain an agent, letting in-flight work finish while accepting nothing new
- retry an execution
- replay an event, restricted and audited
- expire an artifact
- rotate a secret
- rebuild the plugin cache
- run a database migration

Every action in this list is audited with actor, target, and outcome. Quarantine, trust change,
policy override, and event replay are the ones that change security posture and must never be
silent.

**Drain before stop.** An agent stopped without draining orphans everything it was running, which is
recoverable but noisy. Drain is the graceful path and should be the documented default.

## Backup

| Item                              | Backed up           | Why                                                         |
| --------------------------------- | ------------------- | ----------------------------------------------------------- |
| Database                          | Yes                 | Execution history, registry, schedules                      |
| Workflow definitions and versions | Yes                 | Immutable snapshots executions reference                    |
| Configuration                     | Yes                 | —                                                           |
| Secret store and metadata         | Yes, encrypted      | Restoring without secrets restores a system that cannot run |
| Audit logs                        | Yes                 | Often a compliance requirement                              |
| Artifacts                         | Per retention class | Release artifacts always; temporary never                   |
| Plugin cache                      | No                  | Reconstructible by pulling images again                     |

A restore drill belongs in the release checklist. An untested backup is a hypothesis.

## Open questions

1. What is the default log cap, and is it per execution or per workflow?
2. Does quarantining a plugin version cancel executions already running on it, or only prevent new
   ones?
3. Is event replay available in Phase One, or deferred until the event history is proven stable?
