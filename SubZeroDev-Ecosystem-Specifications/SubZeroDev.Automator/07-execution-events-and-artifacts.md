# Execution Events and Artifacts

Split from `07-events-notifications-artifacts.md`. The event envelope, bus, outbox, and notification
channels moved to `SubZeroDev.Platform/07-events-and-notifications.md`. This document defines the
events Automator publishes and the artifacts it tracks.

## Event catalogue

All events use the Platform envelope and the `<Product>.<Aggregate>.<PastTenseVerb>` convention.

### Execution

```text
Automator.Execution.Created
Automator.Execution.Queued
Automator.Execution.Started
Automator.Execution.Succeeded
Automator.Execution.Failed
Automator.Execution.PartiallySucceeded
Automator.Execution.Cancelled
Automator.Execution.TimedOut
Automator.Execution.Orphaned
```

`PartiallySucceeded` is distinct from both success and failure, because partial success is a
first-class outcome in the plugin contract — exit code `4` — and collapsing it into either one loses
the information a notification rule most needs.

`Orphaned` covers the failure mode the original set had no answer for: see Orphan detection below.

### Workflow

```text
Automator.Workflow.Queued
Automator.Workflow.Started
Automator.Workflow.StepStarted
Automator.Workflow.StepSucceeded
Automator.Workflow.StepFailed
Automator.Workflow.StepSkipped
Automator.Workflow.Paused
Automator.Workflow.Resumed
Automator.Workflow.Succeeded
Automator.Workflow.Failed
Automator.Workflow.Cancelled
Automator.Workflow.CompensationStarted
Automator.Workflow.CompensationFailed
```

`CompensationFailed` matters more than it looks. Compensation is best-effort, so it can fail — and a
workflow left partially compensated is the one state an operator must be told about, because
automatic recovery is no longer possible.

### Registry and security

```text
Automator.Plugin.Installed
Automator.Plugin.Updated
Automator.Plugin.Quarantined
Automator.Plugin.TrustChanged
Automator.Secret.Accessed
Automator.Policy.Overridden
```

The last three are audit-relevant and correspond to actions listed in `10-security-model.md`.

## Orphan detection

**The gap the original set did not address.** An execution's agent disappears mid-run: the process
is gone, the container may or may not still exist, and nothing is going to report a terminal state.
Without detection the execution sits in `Running` forever, holds a concurrency slot, and blocks a
singleton schedule permanently.

Rules:

- Every running execution has a **lease** with an expiry, renewed by heartbeat from whatever is
  executing it.
- A lease that expires without renewal transitions the execution to `Orphaned` and publishes
  `Automator.Execution.Orphaned`.
- `Orphaned` is **terminal**. It is not a retry, because the control plane does not know whether the
  work completed, partially completed, or never started — and guessing is how a non-idempotent
  command runs twice.
- Whether an orphaned execution is retried is a policy decision per command, and defaults to **no**
  for anything not declared `idempotent`.
- On agent reconnect, an execution the agent reports as still running is reconciled rather than
  duplicated; the lease resumes.

Heartbeat interval and lease duration are configuration, and the lease must be comfortably longer
than the interval so a slow network does not orphan healthy work.

## Artifacts

Artifacts are immutable outputs of executions. Automator tracks metadata; Platform storage holds
bytes.

### Lifecycle

```text
Declared → Produced → Validated → Registered → Stored → Consumed → Expired → Deleted
```

`Declared` comes from the plugin manifest, before the run. That is what makes a missing required
artifact detectable rather than merely absent.

### Identity and immutability

**The question the original set left open.** Determinism means an unchanged re-run produces
byte-identical artifacts — so does the second run create a new artifact or reuse the first?

Decision: **artifacts are content-addressed by digest; registrations are per-execution.**

- The stored blob is keyed by `sha256`. An identical re-run stores nothing new.
- A new artifact _record_ is still created, referencing the same blob and naming the producing
  execution.

This separates two things that are genuinely different: the bytes, which are shared, and the claim
that a particular execution produced them, which is per-run provenance. Deduplicating the record as
well would lose the audit trail; deduplicating neither would store the same megabytes on every
scheduled run.

Consequences worth stating:

- Retention deletes a blob only when no live record references it.
- A digest match is proof of an unchanged result, which is what lets a workflow skip downstream work.

### Metadata

ID, name, type, media type, size, `sha256`, storage URI, producing execution, retention class,
tenant, visibility, schema version, and declared-versus-undeclared status.

### Validation

Before registration:

- The path is relative, normalized, and inside the output directory. A path escaping it is refused,
  not written — the contract states this and Automator enforces it on receipt as well, because a
  compromised or buggy plugin is exactly the case where the plugin's own check cannot be trusted.
- A declared `required: true` artifact that is absent makes the execution failed, whatever exit code
  the plugin returned.
- An artifact present but undeclared is registered and flagged. It is usually a manifest bug, and
  discarding it silently would hide that.
- Where a `schemaRef` is declared, the artifact is validated against it.

### Passing artifacts

Downstream steps receive artifact **references**, not filesystem paths. Local execution may optimize
by passing a path, but the logical contract stays reference-based so the same workflow survives being
run across two agents.

### Retention

| Class          | Default               | Rationale                                     |
| -------------- | --------------------- | --------------------------------------------- |
| Execution logs | 30 days               | Diagnostic value decays quickly               |
| Temporary      | 24 hours              | Intermediate step output                      |
| Build          | 90 days               | May be needed to reproduce a release          |
| Release        | Permanent             | Deleting a shipped artifact breaks provenance |
| Audit          | Per compliance policy | Not an engineering decision                   |

Configurable per tenant, workflow, or artifact type. Release artifacts should additionally be
signable.

## Decisions on previously open points

**Event history retention.** Append-only within a 90-day window, then compacted to terminal-state
summaries — one row per execution with its outcome, timing, and artifact references. Intermediate
events lose diagnostic value within days; terminal outcomes keep audit value indefinitely, and
unbounded append-only growth on SQLite is a slow failure that only appears once it is expensive.

**Lease and heartbeat.** Heartbeat every 30 seconds, lease 120 seconds — four missed heartbeats.
Long enough that a transient network loss does not orphan healthy work, short enough that a dead
agent is detected in two minutes, which is proportionate for jobs measured in minutes.

**Container reaping on reconnect.** Depends on what the agent reports. A container whose process has
already exited is reaped and the outcome recorded. A container still running is **reconciled, not
reaped** — the execution leaves `Orphaned` and resumes its lease, because killing work that is about
to succeed is worse than the tidiness gained.
