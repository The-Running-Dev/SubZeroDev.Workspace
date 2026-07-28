# SubZeroDev.Automator Specification

## Purpose

SubZeroDev.Automator is a plugin-based automation runtime and control plane built on SubZeroDev.Platform.

It discovers capabilities, executes commands, composes workflows, schedules work, tracks history, routes artifacts, exposes APIs, and coordinates remote agents.

## Core rule

Automator owns orchestration.

Plugins own business logic.

## Primary use cases

- run a plugin manually
- execute a plugin through PowerShell
- expose plugin commands through REST
- expose approved plugin commands through MCP
- chain plugin commands into workflows
- schedule recurring workflows
- execute work on another machine
- collect logs and artifacts
- notify users of completion or failure
- manage multiple active software projects
- provide a common execution layer for homelab and SaaS use

## Major components

```text
Automator API / UI / CLI / PowerShell / MCP
                    │
                    ▼
              Control Plane
                    │
    ┌───────────────┼────────────────┐
    ▼               ▼                ▼
Plugin Registry  Workflow Engine  Scheduler
    │               │                │
    └───────────────┼────────────────┘
                    ▼
             Execution Coordinator
                    │
          Runtime Host Resolution
                    │
    ┌───────────────┼────────────────────────────┐
    ▼               ▼             ▼              ▼
Docker Host     .NET Host      Node Host      Remote Agent
```

## Functional requirements

### Plugin registry

The registry stores:

- plugin ID
- display name
- description
- version
- manifest schema version
- runtime implementations
- commands
- input/output schemas
- required capabilities
- required secrets
- compatibility
- installation source
- image digest/package checksum
- enabled state
- trust state
- tenant visibility
- health
- update information

### Plugin installation

Installation may support:

- OCI registry reference
- local manifest path
- NuGet package
- npm package
- Python package/virtual environment
- PowerShell module
- executable bundle
- remote API registration

Installation must not mean in-process loading by default.

### Plugin command execution

An invocation includes:

- invocation ID
- plugin ID
- plugin version or constraint
- command ID
- typed inputs
- secret references
- artifact references
- requested execution target
- timeout
- retry policy
- priority
- actor
- tenant
- correlation ID
- dry-run flag
- idempotency key

### Execution states

```text
Queued → Running → Succeeded
                 → Failed
                 → Cancelled
                 → TimedOut
                 → Orphaned
```

Six terminal-or-active states, not thirteen. `Skipped` and `Compensated` only mean something once
workflows and compensation exist, and `Created`, `Validated`, `Resolving`, and `Starting` are
internal transitions within queueing and dispatch — persisting each as a distinct state adds rows and
migration surface without giving an operator anything they can act on.

`Orphaned` is terminal and is reached when an execution's lease expires without a heartbeat. It is
never retried automatically: the control plane cannot know whether the work completed, partially
completed, or never started, and guessing is how a non-idempotent command runs twice. See
`07-execution-events-and-artifacts.md`.

Workflow-level states are separate and are specified in `06-workflow-engine.md`.

### Execution result

The result contains:

- status
- exit code
- start and end time
- duration
- normalized output
- warnings
- structured errors
- produced artifacts
- log stream reference
- runtime host metadata
- agent metadata
- retry history

## Manual execution

Every plugin should be executable outside Automator whenever practical.

Automator must not be the only way to run a plugin.

For CLI-capable plugins:

```bash
subzerodev-github sync --output ./artifacts
```

Automator invokes the same behavior through a runtime host.

## Workflow engine

A workflow is a versioned directed graph of steps.

Step types:

- plugin command
- conditional
- parallel group
- approval
- delay
- sub-workflow
- transform
- notification
- artifact publish
- compensation

Workflow requirements:

- explicit dependencies
- typed input mapping
- output references
- retry policy
- timeout
- cancellation
- concurrency controls
- conditions
- failure strategy
- artifact passing
- resumability where feasible
- immutable execution snapshot

## Scheduling

Schedule types:

- manual
- one-time
- cron
- fixed interval
- event-triggered
- webhook-triggered
- dependency-triggered
- condition watch, future

Schedules refer to workflow versions or plugin commands.

## Remote agents

An agent represents an execution node.

Agent metadata:

- ID
- name
- OS
- architecture
- runtimes
- Docker availability
- labels
- capabilities
- health
- concurrency
- trust zone
- network access profile
- last seen
- installed plugin cache

Agent selection uses:

- explicit target
- required runtime
- required labels
- OS
- resource constraints
- trust zone
- data locality
- queue load

## Artifacts

Automator tracks artifact metadata but storage is provided by Platform.

Artifact fields:

- ID
- name
- type
- content type
- size
- checksum
- storage URI
- producing execution
- retention
- tenant
- visibility
- metadata
- schema version

## Secrets

Automator stores secret references, not plaintext in workflow definitions.

Secrets may be scoped to:

- user
- tenant
- project
- workflow
- plugin
- agent
- environment

A plugin receives only declared and authorized secrets.

## Logs

Required log dimensions:

- execution ID
- workflow execution ID
- workflow step ID
- plugin ID
- command ID
- agent ID
- tenant
- correlation ID
- severity
- timestamp
- stream: stdout, stderr, structured

## REST API

Initial resources:

- plugins
- plugin versions
- commands
- executions
- workflows
- workflow versions
- schedules
- agents
- artifacts
- secrets metadata
- events
- health

## MCP

Automator may expose approved plugin commands as MCP tools.

MCP exposure must be explicit or policy-driven. Installing a plugin must not automatically expose every command to every AI client.

## PowerShell

PowerShell is a first-class client.

Initial commands:

```powershell
Get-SzPlugin
Get-SzPluginCommand
Invoke-SzPlugin
Get-SzExecution
Stop-SzExecution
Get-SzWorkflow
Invoke-SzWorkflow
Get-SzArtifact
Get-SzAgent
```

Generated plugin-specific wrappers are optional and can be produced by ContainerPSGenerator.

## Web UI

Initial UI:

- dashboard
- plugins
- run command
- executions
- logs
- workflows
- schedules
- agents
- artifacts
- settings

A visual workflow designer is not required for Phase One.

## Persistence

Suggested initial persistence:

- SQLite for local mode
- PostgreSQL for server mode
- Platform persistence abstractions
- append-only execution event history where practical
- immutable workflow version snapshots

## Deployment modes

### Local mode

- single process
- SQLite
- local filesystem artifacts
- local runtime hosts
- no mandatory authentication

### Server mode

- ASP.NET Core
- PostgreSQL
- object storage
- authentication
- multiple users
- remote agents

### SaaS mode

- multi-tenant
- billing through Platform
- hosted control plane
- customer-hosted agents
- tenant-isolated artifacts and secrets

## Non-goals

Automator is not:

- a source control provider
- a build system itself
- a documentation generator
- an AI model
- a package manager
- a replacement for existing CI systems in Phase One
- a general BPM suite
- a low-code platform

## Phase scope

Phase numbering is defined once in `SubZeroDev.Ecosystem/18-roadmap.md`. This document previously
maintained a separate "Phase One" listing fifteen items, which described a different milestone from
the roadmap's and made the term mean two things depending on which document was open.

**Phase 3 — Automator MVP:**

- plugin registry, installing from an OCI reference and verifying the digest
- **Docker runtime host only**
- execution model and the six-state machine
- manual invocation, log capture, artifact registration
- SQLite persistence and execution history
- secret storage, injection, and output scanning
- capability policy evaluation and enforcement binding

Deliberately excluded from the MVP:

- **The local process host.** It cannot enforce any declared capability, so shipping it beside the
  policy engine would make policy decorative on the host that most needs it. Phase 6.
- REST API, PowerShell client, workflows, and cron. Docker host plus manual invocation plus execution
  history is enough to prove the orchestration model; those follow in Phase 4.

**Phase 4** adds REST, the PowerShell client, sequential workflows, cron scheduling with an explicit
overlap policy, and notifications.

**Phase 6** adds the remaining runtime hosts, remote agents, DAG workflows, PostgreSQL, and object
storage.

**Phase 7** adds MCP, approvals, and the AI project workflow. **Phase 8** is the commercial layer.
