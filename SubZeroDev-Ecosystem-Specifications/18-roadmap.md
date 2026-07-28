# Roadmap

## Phase 0 — Architecture stabilization

- review this document set
- resolve open questions
- create ADRs
- define naming
- define package boundaries
- define manifest schema
- define normalized invocation/result contracts

## Phase 1 — Independent plugins

Prioritize tools already useful manually:

1. GitHub plugin
2. Requirements Compiler
3. Documentation plugin packaging
4. ContainerPSGenerator alignment with plugin contract

Deliver:

- CLI
- Docker
- manifest
- schemas
- tests
- docs

## Phase 2 — Platform foundation

- core abstractions
- hosting
- configuration
- events
- persistence
- notifications
- storage
- observability
- API conventions
- testing

## Phase 3 — Automator local MVP

- plugin registry
- local process host
- Docker host
- execution model
- SQLite
- REST
- PowerShell
- logs
- artifacts
- sequential workflows
- cron
- local mode

## Phase 4 — Multi-runtime and remote agents

- Node host
- .NET host
- Python host
- PowerShell host
- agent protocol
- agent selection
- PostgreSQL
- object storage
- DAG workflows

## Phase 5 — AI and project workflow

- Requirements Compiler integration
- GitHub project publishing
- MCP
- AI workspace/project context
- approval steps
- model/provider policies

## Phase 6 — Commercial platform

- identity
- organizations
- tenancy
- billing
- licensing
- usage
- hosted control plane
- customer-hosted agents

## Explicit deferrals

- marketplace
- Kubernetes
- low-code visual designer
- distributed event bus
- plugin hot loading in control process
- enterprise SSO
- automatic destructive reconciliation
