# ADR-003: Out-of-Process Execution by Default

## Status

Proposed

## Decision

Plugins execute out of process by default.

Automator does not dynamically load independently versioned plugin assemblies into the control-plane process except for explicitly trusted future scenarios.

## Rationale

- isolation
- independent dependencies
- failure containment
- language independence
- version independence
- security policy enforcement
