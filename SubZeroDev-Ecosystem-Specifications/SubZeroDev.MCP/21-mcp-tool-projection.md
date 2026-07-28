# MCP Tool Projection

How a plugin manifest becomes an MCP tool surface. This is the mechanical part; policy and consent
are in `22-mcp-security-and-consent.md`.

## Projection rules

| Manifest                  | MCP                                                     |
| ------------------------- | ------------------------------------------------------- |
| `commands[].id`           | Tool name, namespaced — see below                       |
| `commands[].description`  | Tool description, with the additions below              |
| `commands[].inputSchema`  | Tool `inputSchema`, verbatim                            |
| `commands[].outputSchema` | Tool `outputSchema` where the client supports one       |
| `artifacts[]`             | Referenced in results, never inlined — see Result shape |
| `secrets[]`               | **Never projected.** Not as parameters, not as anything |
| `capabilities`            | Surfaced to the host for policy; not a tool parameter   |

### Tool naming

```text
subzerodev.github.sync   →   subzerodev_github_sync
```

The full namespace is retained. Collapsing to `sync` or `github_sync` reads better until a second
plugin exposes a command of the same name, at which point two tools collide and the client binds
whichever registered last — silently, and differently between sessions.

### Tool descriptions carry what a skill file used to

This is the part most easily got wrong. A plugin invoked from the CLI has documentation, a README,
and a human reading them. A plugin invoked as an MCP tool has **the description and nothing else** —
the calling model decides whether and how to invoke it from that text alone.

Every projected description must state:

- what the command does
- whether it reads or writes
- any precondition, in particular a required plan token
- any failure mode that is silent rather than loud

The last one matters more than it looks. Where a command can produce a plausible-looking result from
malformed input — the todo-to-github plugin's free-form parse that yields empty epics is the worked
example — the description must say so, because the model has no other way to learn it and the user
will not see a warning they were not shown.

## The `mcp` command

A plugin that wants a direct surface implements one additional command:

```text
plugin mcp [--transport stdio|http] [--port N]
```

Serves that plugin's own commands over MCP, projected by the rules above. `stdio` is the default and
the only one required.

**It is optional.** A plugin without it is fully contract-conforming and remains reachable through
the Automator's brokered MCP server, which projects the same manifest.

The `mcp` command is exempt from the result-envelope rule for its own invocation — it is a server
loop, not a run — but every command it _serves_ returns the envelope, mapped as below.

## Result shape

The plugin contract's result envelope maps onto an MCP tool result:

| Envelope field           | MCP tool result                                              |
| ------------------------ | ------------------------------------------------------------ |
| `status`, `summary`      | Leading text content                                         |
| `warnings[]`, `errors[]` | Text content, **before** the summary when non-empty          |
| `data`                   | Structured content                                           |
| `artifacts[]`            | References with path, size, and digest — never file contents |
| `exitCode`               | Not projected; `status` carries it                           |

Two rules that follow from MCP's shape rather than the contract's:

**Warnings lead.** In a CLI, a warning on stderr is visible next to the output. In an MCP result the
model sees one blob and summarizes it for the user, so anything after the summary may never reach a
human. Warnings that indicate possible data loss go first or they effectively do not exist.

**Artifacts are referenced, never inlined.** The contract already caps `data` at 256 KiB; MCP makes
this sharper, because tool results enter the model's context and are billed and truncated there.
A 40 MB `projects.json` returned inline is a broken interaction, not a large one.

## Errors

An MCP tool error is read by a model that must decide what to do next, not by a human reading a
terminal. The contract's exit codes do not project directly — a model cannot act on `4`.

| Exit         | Tool result                                                                                |
| ------------ | ------------------------------------------------------------------------------------------ |
| `0`          | Success                                                                                    |
| `2`          | Error naming the parameter and what was wrong with it                                      |
| `3`          | Error stating the operation failed and whether retrying is sensible                        |
| `4`          | **Success** with partial status, plus the `errors[]` list. Not an error — the run did work |
| `5`          | Error naming the missing credential, never its value                                       |
| `6`          | Error stating rate-limited and roughly when to retry                                       |
| `124`, `130` | Error stating timed out or cancelled                                                       |

Exit `4` is the one worth stating explicitly: reporting a partial success as a tool error causes the
model to retry work that already succeeded.

## Long-running commands

MCP clients time out. Plugin commands can take minutes.

For anything that may exceed the client's tolerance, project a **two-tool pattern**: a fast tool that
starts the work and returns a handle, and a second that reports status. This is the same shape as
plan-and-apply, and the same shape the Automator's execution model already uses.

Under the Automator this is native — an execution ID is the handle. For a direct-mode plugin, the
handle is process-local and does not survive a restart, which must be said rather than discovered.

## Resources

A plugin may project MCP resources for documentation the calling model needs to use it correctly —
input formats, worked examples, schemas.

```text
subzerodev://<plugin-id>/<resource-name>
```

This is worth doing where a tool's correct use depends on a file format the model must generate. The
alternative is duplicating the format into every tool description, where it is both long and prone to
drifting from the real specification.

## Conformance

Where a plugin implements `mcp`, conformance additionally asserts:

1. Every command in the manifest projects to exactly one tool, and no tool exists without a command.
2. Tool input schemas are byte-identical to the manifest's `inputSchema`.
3. No secret name, value, or environment-variable name appears in any tool schema or description.
4. A partial-success run returns a successful tool result with populated `errors[]`, not a tool
   error.
5. Warnings indicating possible data loss appear before the summary in the result text.
6. Artifacts appear as references; no artifact body is inlined.

## Open questions

1. Does the projection support MCP prompts, or only tools and resources? Prompts are a convenience
   that can drift from the tools they wrap.
2. Should `outputSchema` be required in the manifest once MCP projection exists? It is optional
   today, and a projected tool is more useful with one.
