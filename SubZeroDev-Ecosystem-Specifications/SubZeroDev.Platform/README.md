# SubZeroDev Platform

The reusable application framework underneath the Automator: hosting, configuration, persistence,
observability, events and notifications, tenancy, billing, and licensing.

Platform is infrastructure a product other than the Automator would want unchanged. **Platform never
depends on the Automator or on a plugin** — the dependency runs one way, and it is enforced by the
build rather than by intent.

## Contents

| Document                          | Covers                                             |
| --------------------------------- | -------------------------------------------------- |
| `02-platform-specification.md`    | Purpose, packages, and boundaries                  |
| `07-events-and-notifications.md`  | Event envelope, bus, outbox, notification channels |
| `10-tenancy-billing-licensing.md` | Multi-tenancy, metering, licensing                 |
| `11-observability.md`             | Logging, metrics, and tracing primitives           |

## Scope: minimal, deliberately

Six packages ship alongside the Automator:

```text
SubZeroDev.Platform.Abstractions
SubZeroDev.Platform.Core
SubZeroDev.Platform.Hosting
SubZeroDev.Platform.Persistence
SubZeroDev.Platform.Observability
SubZeroDev.Platform.Testing
```

Everything else is deferred until a second consumer needs it. A capability with one consumer lives
inside the Automator, where changing it is cheap; promoting it here makes its API a commitment.

The first draft of this specification listed twenty-four packages, none of which had a consumer. The
guard exists so the minimal six do not become those twenty-four by increments, each addition looking
reasonable on its own.

## Where the other halves went

Several documents were split by product. Execution events and artifacts, operations, and the security
model live in the Automator repository — they are about running things, which is not Platform's job.

## Status

Specification only. The repository exists; the packages are work packages W2.4 and W2.5.
