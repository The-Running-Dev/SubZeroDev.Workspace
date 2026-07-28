# Working on the MCP surface

MCP is how a language model calls a plugin. This repository specifies the projection from manifest to
tool surface, and the security model that projection needs.

## MCP is a transport, not a runtime

A plugin does not become an MCP server. Its **tool surface is projected from its manifest**, and one
projection serves both hosts: direct (a plugin's own `mcp` command over stdio) and brokered (the
Automator exposing many plugins).

Do not specify a second surface for the brokered case. Two projections of the same manifest is two
things to keep in agreement, and the agreement is exactly what a model consuming the tools depends
on. See `adr/ADR-001`.

The manifest stays the single source of the tool surface. If a tool needs something the manifest
cannot express, extend the manifest schema in `SubZeroDev.PluginContract` — do not add it to the
projection.

## The threat model here is different, and that is the point

Everywhere else in this ecosystem the caller is a person or a scheduler. Under MCP **the caller is a
language model acting on text it did not author, and that text may have been written by someone
hostile.**

Two consequences that must not be softened:

**A prose instruction is not a control.** "Ask for approval before applying" works when the
documentation is loaded alongside; a different client's model never reads it. Any gate must be
structural — the plan-apply pattern in the contract, where the apply command accepts a plan token and
nothing else, and an instruction injected into a plugin's input cannot fabricate a token.

**Secrets are never tool arguments.** A tool argument is model-visible, model-authored, and logged by
the client. Secrets arrive by environment variable, the same as every other invocation path. The
manifest cannot declare a secret as an input, and the projection must not create one.

## Consent belongs to the operator, not to the model

`22-mcp-security-and-consent.md` owns this. The model proposes; the operator disposes. A tool that
writes to an external system is exposed only when the operator has allowed it, and a plan is applied
only when a human has seen the rendering.

When adding a check, ask what it does against a _hostile_ input rather than a mistaken one. A control
that only catches honest errors is documentation.

## What belongs here, and what belongs in the contract

| Question                                     | Owner                                     |
| -------------------------------------------- | ----------------------------------------- |
| How a manifest command becomes a tool        | Here, `21-mcp-tool-projection.md`         |
| What the manifest can declare                | `SubZeroDev.PluginContract`               |
| The plan-apply pattern itself                | `SubZeroDev.PluginContract`               |
| Which tools an operator exposes, and consent | Here, `22-mcp-security-and-consent.md`    |
| The Automator's brokered endpoint            | `SubZeroDev.Automator/09-rest-and-mcp.md` |

The `mcp` command is optional in the manifest and is exempt from the result-envelope rule for its own
invocation, because it is a server rather than a command that returns. That exemption is narrow and
should not be widened — a plugin's other commands still emit exactly one envelope.

## Open questions live here until they are answered

Six of the ecosystem's open questions are MCP's: how the projection layer ships, whether the
Automator brokers direct plugins as upstreams, whether prompts are projected, whether `outputSchema`
becomes required, whether direct mode has any authentication, and where the exposure allowlist lives.

None blocks Phase 1. When one is answered, record it in the document that owns it **and** reconcile
`19-open-questions.md` in the Architecture repository in the same commit.

## Before you finish

- For any new surface, state what it does against a hostile input.
- Check that nothing you added makes a secret reachable from a tool argument.
- Check that the direct and brokered hosts still project the same surface.

## Conventions

These hold in every SubZeroDev specification repository. The canonical copy of this block is
`AGENTS.md` in the Architecture repository; it is repeated here because a repository has to stand on
its own.

- **Reference, never restate.** A rule that lives in another document is linked, not copied. Two
  copies of a rule is a promise they will diverge and a guarantee nobody will notice which is stale.
- **The plugin contract outranks plugin specifications.** Where a plugin document and the contract
  disagree, the contract is correct and the plugin document has drifted. See ADR-003 in
  `SubZeroDev.PluginContract`.
- **A decision gets an ADR.** Status is exactly one of `Proposed`, `Accepted`, `Superseded`, or
  `Deprecated`, under a `## Status` heading. An accepted ADR states its context, the decision, the
  consequences _including the costs_, and the alternatives it rejected and why. "Accepted in existing
  practice" is not a status — ratifying current practice is a note in the context.
- **Move, never copy.** A specification has exactly one home. Where another repository needs the
  text, it references a tagged commit rather than duplicating the file.
- **Give reasons.** These documents are read by people deciding what to build. An assertion with no
  reason cannot be evaluated, and cannot be safely revised by someone who was not there when it was
  written.
- **Markdown is Prettier-formatted**, 100 columns, LF endings.
