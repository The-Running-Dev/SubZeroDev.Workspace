# REST and MCP

## REST API

REST is the primary remote control-plane interface.

### Core endpoints

```text
GET    /api/plugins
GET    /api/plugins/{id}
GET    /api/plugins/{id}/commands
POST   /api/plugins/{id}/commands/{command}/executions

GET    /api/executions
GET    /api/executions/{id}
POST   /api/executions/{id}/cancel
GET    /api/executions/{id}/logs
GET    /api/executions/{id}/artifacts

GET    /api/workflows
POST   /api/workflows
POST   /api/workflows/{id}/executions

GET    /api/agents
GET    /api/schedules
```

### API requirements

- OpenAPI
- versioning
- authentication
- permission checks
- rate limiting
- idempotency keys
- request validation
- problem details
- pagination
- correlation IDs
- streaming logs where supported

## MCP server

Automator can expose approved commands and workflows as MCP tools.

### MCP tool generation

A plugin command can map to:

```text
Plugin command: subzerodev.github.sync
MCP tool: subzerodev_github_sync
```

The tool schema is generated from the command input schema.

The namespace is retained deliberately. Collapsing `subzerodev.github.sync` to `github_sync` reads
better until a second plugin exposes a `sync` command, at which point two tools collide and the AI
client picks whichever registered last.

### MCP safety

MCP exposure requires:

- command allowlist
- permission check
- actor identity
- secret policy
- execution target policy
- confirmation policy for destructive actions
- audit logging
- output truncation and artifact references
- timeout
- rate limits

### MCP resources

Potential resources:

- plugin catalog
- workflow catalog
- execution summaries
- project metadata
- artifact metadata
- logs with permission checks

### MCP prompts

Optional prompts may help AI clients:

- create project from specification
- analyze repository portfolio
- prepare release
- summarize failed workflow

Prompts are not a substitute for command contracts.
