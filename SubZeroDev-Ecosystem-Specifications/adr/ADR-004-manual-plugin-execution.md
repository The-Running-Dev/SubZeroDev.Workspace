# ADR-004: Plugins Must Be Independently Executable

## Status

Proposed

## Decision

Plugins should be manually executable without Automator wherever practical.

Automator orchestration is an additional integration layer, not a requirement for basic use.

## Consequences

- faster plugin development
- simpler debugging
- CI reuse
- less coupling
- CLI contract becomes important
