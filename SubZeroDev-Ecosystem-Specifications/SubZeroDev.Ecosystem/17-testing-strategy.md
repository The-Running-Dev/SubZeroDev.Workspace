# Testing Strategy

Ecosystem-wide layer model. The plugin conformance suite is specified separately in
`SubZeroDev.PluginContract/17-conformance.md`, because it is a deliverable of the contract rather
than a testing convention.

## Layers

| Layer       | Scope                                  | Runs                  | Owner                                       |
| ----------- | -------------------------------------- | --------------------- | ------------------------------------------- |
| Unit        | One module, no I/O                     | Every commit, seconds | Each repository                             |
| Contract    | One boundary, both sides               | Every commit          | Contract repository, consumed by both sides |
| Integration | Real dependency, one process           | Every commit, minutes | Each repository                             |
| Conformance | A whole plugin at its process boundary | Every plugin release  | Contract repository                         |
| End-to-end  | Multiple products together             | Before release        | Automator repository                        |

The layer most often skipped is **contract**, and it is the one that pays here. Two independently
versioned repositories agreeing on a manifest schema is exactly what contract tests are for, and the
alternative is discovering the disagreement in end-to-end tests where the cause is furthest from the
symptom.

## Unit

Model validation, state transitions, mapping, policy evaluation, serialization, expression
evaluation. No network, no filesystem, no clock.

Anything reading the real clock is a flaky test waiting to happen. Inject it.

## Contract tests

Both sides of a boundary tested against the same shared definition:

- **Manifest schema.** The reference manifest validates; a corpus of negative cases is rejected. The
  negative corpus is the valuable half — a schema that accepts everything passes a positive-only
  suite.
- **Result envelope.** Producers emit envelopes that validate; consumers accept every valid shape,
  including ones with empty `errors` and absent optional fields.
- **Runtime host.** Every host implementation is driven through the same scenario set, so hosts stay
  interchangeable.
- **Provider adapters.** Each provider satisfies the same normalized-model expectations.

## Integration

Real database, real storage, real event bus, real Docker daemon. Test containers rather than
in-memory fakes wherever the real thing has behaviour worth testing — SQLite and PostgreSQL differ in
ways in-memory fakes hide.

## End-to-end

Install a plugin, invoke a command, stream logs, produce an artifact, run a workflow, cancel an
execution, retry a failure, invoke through MCP, invoke through PowerShell.

E2E is slow and brittle by nature. Keep it to journeys that cross products; anything provable at a
lower layer belongs there.

## Determinism

- Fake clock everywhere; no test reads the wall clock.
- Fixed seeds and fixed IDs where identifiers appear in output.
- Isolated temporary workspaces per test, never a shared directory.
- Snapshot tests compare canonical serialized output, so a formatting change fails loudly rather
  than silently passing.

## Security tests

Not a separate phase — these run alongside unit and integration tests:

- secret redaction across logs, output, artifacts, and errors
- unauthorized command invocation
- tenant isolation
- unsafe mount rejection
- untrusted plugin restricted to enforcing hosts
- path traversal in artifact paths
- command injection through inputs and workflow expressions
- oversized logs and artifacts hitting their caps rather than exhausting disk
- malicious manifest: unknown capability keys refused, not ignored

The last one is a regression test for a specific decision. It was the original schema's behaviour to
ignore them, and it would be easy to reintroduce by relaxing `additionalProperties`.

## Compatibility

Windows and Linux; x64 and arm64 where feasible; supported PowerShell versions; declared Node and
Python ranges; Docker engine versions.

Windows is where line endings, path separators, symlink permissions, and atomic-rename semantics all
differ. It needs a CI job, not developer goodwill — a platform claim no job enforces is not a claim.

## What is not tested

Stated so the gaps are deliberate:

- Performance and load. No targets are defined yet; adding tests before targets produces numbers
  nobody can interpret.
- Chaos and fault injection beyond the specific failure modes listed above.
- UI, which has no Phase One dependency.

## Open questions

1. Is there a coverage threshold, and is it enforced or reported?
2. Does end-to-end run against recorded fixtures, a controlled fixture account, or both?
3. Which repository owns the shared contract-test corpus — the contract repository, presumably, but
   consumed how?
