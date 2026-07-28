# ADR-001: Separate Platform from Automator

## Status

Proposed

## Context

Reusable concerns such as hosting, identity, billing, notifications, storage, configuration, and observability apply across multiple products.

Automation-specific concerns such as plugin execution, workflows, agents, and schedules belong to a separate product.

## Decision

Create:

- `SubZeroDev.Platform`
- `SubZeroDev.Automator`

Automator depends on Platform.

Platform does not depend on Automator.

## Consequences

Positive:

- reusable infrastructure
- cleaner product boundaries
- independent evolution
- future non-automation products reuse Platform

Negative:

- more repositories/packages
- version coordination
- additional architectural discipline
