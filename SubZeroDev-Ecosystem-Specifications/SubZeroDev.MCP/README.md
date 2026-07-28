# SubZeroDev MCP

How a language model calls a SubZeroDev plugin.

## Contents

| Document                            | Covers                                                      |
| ----------------------------------- | ----------------------------------------------------------- |
| `20-mcp-strategy.md`                | What MCP is for here, and what it is not                    |
| `21-mcp-tool-projection.md`         | How a manifest becomes a tool surface — the mechanical part |
| `22-mcp-security-and-consent.md`    | Exposure, consent, and the threat model                     |
| `adr/ADR-001-mcp-as-a-transport.md` | MCP is a transport; tools are projected from the manifest   |

## The design in one paragraph

A plugin does not become an MCP server. Its tool surface is **projected from its manifest**, and one
projection serves two hosts: direct, where a plugin runs its own `mcp` command over stdio, and
brokered, where the Automator exposes many plugins behind one endpoint. The manifest stays the single
source of the tool surface, so there is nothing to keep in agreement.

## Why the security model is separate

Under every other invocation path the caller is a person or a scheduler. Under MCP the caller is a
language model acting on text it did not author — text that may have been written by someone
hostile.

That changes what counts as a control. A prose instruction to stop and ask for approval works only
when the documentation happens to be loaded; another client's model never reads it. Gates here are
structural: the plan-apply pattern in the plugin contract, where the apply command accepts an opaque
single-use token and nothing else, so an instruction injected into a plugin's input cannot fabricate
one.

Secrets are never tool arguments. They arrive by environment variable, as they do everywhere else.

## Status

Specification. MCP arrives with the second plugin — the Backlog plugin needs a direct MCP surface —
and the brokered Automator endpoint follows in a later phase. Six open questions remain, listed in
each document and consolidated in the Architecture repository's `19-open-questions.md`. None blocks
Phase 1.
