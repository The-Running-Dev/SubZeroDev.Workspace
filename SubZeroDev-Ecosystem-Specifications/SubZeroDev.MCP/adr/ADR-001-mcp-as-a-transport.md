# ADR-001: MCP Is a Transport Projected From the Manifest

## Status

Accepted

## Context

A specification arrived for porting the `todo-to-github` Claude Code skill to a standalone Python MCP
server, so it could be reached from clients other than Claude Code. It was a good specification —
detailed, honest about its own open questions, and carrying the fixes for four bugs found in
testing.

It also described a program with no manifest, no result envelope, no exit codes, no container, and no
conformance: **a plugin being built outside the plugin system.** Not through carelessness — the
plugin contract did not mention MCP, so there was nothing to build inside.

Left alone, that produces a second, parallel way to package a capability. The first plugin to exist
in both forms would then have two implementations of auth, errors, dry-run, and approval, and they
would diverge.

Three requirements were being conflated:

1. Platform provides "MCP conventions" — reusable hosting and authorization primitives.
2. The Automator "may expose approved plugin commands as MCP tools" — brokered access, with policy.
3. A plugin must be reachable from Claude Desktop today, with no Automator in existence — direct
   access.

## Decision

**MCP is a transport, not a runtime, and its tool surface is projected from the plugin manifest.**

### It does not join the runtime enumeration

Runtime types answer _how does this code execute_. MCP answers _how does an AI client discover and
invoke it_. A plugin serving MCP is still a container with a CLI; MCP is an additional surface over a
different wire. Adding `mcp` to `runtimes` would conflate the two and make a manifest ambiguous about
what it actually runs.

### One projection, two hosts

A command's `inputSchema` becomes an MCP tool's input schema by mechanical projection. The direct
server and the Automator's brokered server both use it.

This is the whole point of the decision. Hand-written tool definitions drift from the manifest that
the CLI implements, and then the plugin's own MCP surface disagrees with the Automator's projection
of the same plugin. That is ADR-003's duplication failure arriving through a different door, and the
projection is what prevents it.

### The `mcp` command is optional

A plugin implements `mcp` to be directly reachable. A plugin without it is fully conforming and is
still reachable through the Automator.

### Secrets are never tool parameters

The reviewed specification proposed an optional per-call `token` parameter, and was candid that it
would land in client logs and conversation history. That is the reason to reject it, not a caveat to
accept alongside it.

MCP arguments are worse than `argv`, which the contract already forbids: they enter the model's
context and therefore any provider the client forwards to, they persist in logs and conversation
history far longer than a process, and a model that saw a value once may reuse it. A credential that
has been in a model's context should be treated as disclosed.

Direct mode reads the environment of the process the client launched. Brokered mode uses the
Automator's scoped secrets, never visible to the calling model.

### Plan-apply is promoted to the contract

The reviewed specification's strongest idea was making the approval gate structural: a read-only
`plan` returns an opaque token, and `apply` accepts only that token.

It generalizes. The release plugin defaults to dry run, the package plugin refuses on mismatch, and
the Requirements Compiler runs compile-approve-publish. All three are the same shape, expressed three
ways. It belongs in the contract as one pattern rather than being reinvented per plugin — which is
exactly the test ADR-003 sets.

Under MCP it stops being a nicety. A prose instruction to "stop and wait for approval" works when a
skill file is loaded alongside; another client's model never reads it. The gate has to be structural
or it does not exist.

## Consequences

- The contract gains an optional `mcp` command and the plan-apply pattern. Conformance gains checks
  for both.
- The Automator's MCP server becomes a consumer of the projection layer rather than bespoke code.
- The capability becomes the conforming **Backlog** plugin rather than a standalone server: it gains a manifest,
  a container, exit codes, and the envelope, and it loses its own auth model.
- Its `plan`/`apply`/`validate` tools become plugin commands, projected. The MCP-specific work
  shrinks to the projection, which is shared.
- A projection implementation is needed per language. Python is first; the second will show whether
  the projection is genuinely language-neutral or only appeared so.
- Direct mode has no audit trail, by nature. Anything needing one runs brokered, and that is stated
  rather than left to be discovered.

## Alternatives considered

**Build the standalone MCP server as specified.** Fastest to a working tool, and the specification
was ready to implement. Rejected: it creates a second packaging path for capabilities, and the first
capability wanting both would immediately have two implementations to keep in step.

**Add `mcp` as a runtime type.** Superficially tidy — one enumeration, one place to look. Rejected:
it answers a different question from every other value in that list, and a manifest declaring `mcp`
as its runtime would not say what actually executes.

**Only brokered MCP; no direct mode.** Simplest security story, since everything is audited and
policed. Rejected: it makes every plugin useless to an AI client until the Automator exists, which
contradicts the contract's rule that plugins must be independently executable — the rule that makes
plugins developable at all.
