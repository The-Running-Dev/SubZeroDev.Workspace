# ADR-001: Plugins Execute Out of Process

## Status

Accepted

Originally drafted as ADR-003 in a single global sequence, renumbered when the specifications split
by destination repository. Numbering is per repository.

## Context

The Automator has to run plugin code. The cheap way is to load a plugin assembly into the
control-plane process and call it: no serialization, no process spawn, no marshalling, and a stack
trace that crosses the boundary intact.

The draft rejected that with a list of one-word reasons — isolation, failure containment, version
independence — which are the right reasons but do not say where the line is. "By default" invites the
question of what the exceptions are, and an unbounded exception is how in-process loading arrives
anyway, one trusted plugin at a time.

The specific hazard is that in-process loading makes the plugin's dependency graph the host's
dependency graph. Two plugins wanting different versions of the same library becomes a host problem;
a plugin that leaks memory becomes a host leak; a plugin that calls `exit` takes the control plane
with it. None of that is recoverable by careful coding on the host side.

## Decision

**Plugins execute out of process. The Automator never loads independently versioned plugin code into
the control-plane process.**

Not "by default" — the draft's hedge is removed. There is no trusted-plugin exception, because trust
in the signing sense says who published something, not whether its dependency graph is compatible
with the host's or whether its native library segfaults.

What remains in-process is the host's own code: runtime hosts, adapters, and the projection layer.
These ship with the Automator, version with it, and are not plugins.

The boundary a plugin crosses is the one the contract already defines — argv in, environment in,
envelope out on stdout, logs on stderr, exit code, artifacts on disk. This ADR adds no new mechanism;
it commits to the boundary already specified being the only one.

## Consequences

- Every invocation pays process-start cost. For a plugin that runs on a schedule and does real
  network work, that cost is noise. Accepted deliberately: the workload is not latency-sensitive, and
  a design tuned for a latency budget nobody has would trade away containment for nothing.
- Failures are contained. A plugin that crashes, hangs, exhausts memory, or exits the process affects
  one execution.
- The capability model is enforceable, because a separate process can be given a restricted
  environment. In-process code shares the host's ambient authority, so the manifest's capability
  declarations would become documentation.
- Plugin and host dependency graphs never meet, so a plugin can pin whatever it needs.
- Language independence is a consequence rather than a goal here — a process boundary makes the host
  language irrelevant to the plugin's, which is what ADR-001 in the contract requires.
- Debugging crosses a process boundary, so a plugin failure reads as an exit code and an envelope
  rather than an exception. The envelope's `errors[]` exists partly to make that readable.

## Alternatives considered

**In-process by default, out-of-process for untrusted plugins.** Fastest, and it matches how many
extension systems start. Rejected: the isolation properties that matter most — dependency isolation,
crash containment, capability enforcement — are exactly the ones the in-process path cannot offer, so
the fast path is the one without the guarantees.

**In-process with an assembly load context per plugin.** Solves dependency conflicts within .NET
specifically. Rejected: it does nothing for crash containment, capability enforcement, or non-.NET
plugins, and it would apply to a shrinking fraction of the ecosystem.

**Out of process by default with a trusted-plugin exception, as drafted.** Rejected: the exception
has no principled boundary. First-party publication is not evidence that a plugin's native
dependencies are safe to load into the control plane.
