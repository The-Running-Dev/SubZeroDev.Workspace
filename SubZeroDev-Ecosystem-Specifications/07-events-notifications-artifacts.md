# Events, Notifications, and Artifacts

## Events

All major state changes emit typed events.

Event envelope:

```json
{
  "schemaVersion": "1.0",
  "eventId": "uuid",
  "eventType": "Automator.Execution.Completed",
  "timestamp": "ISO-8601",
  "correlationId": "uuid",
  "causationId": "uuid",
  "tenantId": null,
  "actorId": null,
  "data": {}
}
```

Events are not raw log messages.

## Notification integration

Automator emits events.

Platform notification handlers translate selected events into user notifications.

Notification routing rules may consider:

- event type
- severity
- workflow
- plugin
- tenant
- user preferences
- environment
- schedule
- deduplication

## Artifacts

Artifacts are immutable outputs from executions.

Examples:

- JSON
- YAML
- PowerShell modules
- NuGet packages
- documentation sites
- Docker image metadata
- reports
- logs
- generated specifications
- screenshots
- release bundles

## Artifact lifecycle

```text
Declared
→ Produced
→ Validated
→ Registered
→ Stored
→ Consumed
→ Expired
→ Deleted
```

## Artifact integrity

Store:

- checksum
- size
- media type
- producer
- schema version
- created time

Optionally sign release artifacts.

## Passing artifacts

Downstream steps receive artifact references, not arbitrary filesystem assumptions.

Local execution may optimize using paths, but the logical contract remains URI/reference based.

## Retention

Retention policies:

- execution logs
- temporary
- build
- release
- audit
- permanent

Policies may be configured per tenant, workflow, or artifact type.
