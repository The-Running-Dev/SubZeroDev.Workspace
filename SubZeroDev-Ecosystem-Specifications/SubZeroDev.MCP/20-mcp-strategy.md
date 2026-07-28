# MCP Strategy

| Field       | Value                                                                                         |
| ----------- | --------------------------------------------------------------------------------------------- |
| Status      | Draft                                                                                         |
| Destination | `SubZeroDev.MCP` — a shared projection layer, its own repository or `SubZeroDev.Platform.Mcp` |
| Decision    | `adr/ADR-001`                                                                                 |

## The question this answers

The ecosystem already mentions MCP in three places — Platform provides "MCP conventions", the
Automator "may expose approved plugin commands as MCP tools", and a plugin now needs to be reachable
from Claude Desktop directly. Those are not the same requirement, and treating them as one produces
either a second plugin system or a second implementation of the first.

## MCP is a transport, not a runtime

The plugin manifest's runtime types — `docker`, `process`, `dotnet`, `node`, `python`, `powershell`,
`remote` — answer _how does this code execute_. MCP answers _how does an AI client discover and
invoke a capability_. They are orthogonal, and adding `mcp` to the runtime enumeration would
conflate them.

A plugin that speaks MCP is still a container with a CLI. MCP is a surface it presents, alongside
the CLI, over a different wire.

## Two surfaces, one projection

```text
                          ┌─────────────────────────┐
Claude Desktop ─ stdio ──►│  plugin `mcp` command   │
or other client           └───────────┬─────────────┘
                                      │  both project the same manifest
AI client ─ HTTP ──► Automator MCP ───┘
                          server
```

**Direct.** A plugin runs `plugin mcp`, serving its own commands over MCP stdio. No Automator, no
registry, no orchestration — the case a developer has today with Claude Desktop.

**Brokered.** The Automator exposes approved commands from every installed plugin as MCP tools, with
policy, audit, execution history, and workflow composition around them.

The important part: **both derive their tool schemas from the same manifest.** A command's
`inputSchema` becomes an MCP tool's input schema by mechanical projection. That projection is the
`SubZeroDev.MCP` layer, and it is why this is one library rather than two servers.

Without it, every plugin hand-writes its MCP tool definitions, they drift from the manifest, and the
Automator's projection disagrees with the plugin's own. That is the same duplication failure ADR-003
was written about, arriving through a different door.

## What each surface is for

|             | Direct                      | Brokered                       |
| ----------- | --------------------------- | ------------------------------ |
| Consumer    | One developer's AI client   | Team, automation, workflows    |
| Auth        | Local environment           | Automator identity and policy  |
| Audit       | None                        | Full execution record          |
| Composition | None                        | Workflows, scheduling, retries |
| Available   | Before the Automator exists | After                          |

Direct is not a lesser version to be retired. It is the mode where a plugin is useful on day one,
which is what ADR-004 in the contract repository — plugins must be independently executable —
already requires. MCP is that rule extended to AI clients.

## What this is not

- **Not a plugin runtime.** MCP does not appear in the manifest's `runtimes` enumeration.
- **Not a replacement for the CLI.** The CLI remains the normative surface; MCP projects from the
  same manifest the CLI implements.
- **Not automatic exposure.** Installing a plugin must not publish its commands to every AI client;
  see `22-mcp-security-and-consent.md`.
- **Not a general MCP framework.** This layer projects SubZeroDev manifests. It is not a toolkit for
  writing arbitrary MCP servers.

## Consequences

- The contract gains an optional `mcp` command, specified in `21-mcp-tool-projection.md`. A plugin
  that does not implement it is still fully conforming — it is simply not directly reachable from an
  AI client.
- The Automator's MCP server stops being bespoke and becomes a consumer of this layer.
- Plugins written in any language need a projection implementation for that language. The first is
  Python, for the Backlog plugin; the second will tell us whether the projection is really
  language-neutral or merely looked it.

## Open questions

1. Does the projection layer ship as one package per language, or as a specification with
   independent implementations? The first is less work now; the second is what the contract's
   language-neutrality principle would predict.
2. Should the Automator's MCP server support the direct plugins as upstreams — brokering to a
   plugin's own MCP server rather than invoking its CLI? It would work, and it adds a hop for no
   obvious gain.
