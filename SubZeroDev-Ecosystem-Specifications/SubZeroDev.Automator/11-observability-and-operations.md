# Observability and Operations

## Operational goals

- explain every execution
- identify current state
- diagnose failure quickly
- correlate control-plane and agent activity
- measure plugin performance
- detect stuck work
- preserve useful audit history

## Logs

Structured logs with:

- timestamp
- level
- message
- event ID
- execution ID
- workflow ID
- step ID
- plugin ID
- command
- agent
- correlation
- exception
- tenant

## Metrics

Examples:

- executions started/completed/failed
- execution duration
- queue time
- workflow duration
- retries
- timeouts
- active executions
- agent availability
- plugin startup time
- artifact bytes
- notification success/failure
- API request duration
- MCP calls
- rate-limit events

## Traces

Trace:

```text
API/MCP/CLI request
→ execution creation
→ queue
→ runtime resolution
→ agent dispatch
→ plugin process/container
→ artifact upload
→ notification
```

## Health

Control plane:

- database
- storage
- event processing
- scheduler
- secret provider
- agent gateway

Agent:

- connectivity
- disk
- runtime availability
- Docker
- plugin cache
- concurrency

Plugin:

- install validation
- runtime availability
- optional health command

## Operations

Administrative actions:

- disable plugin
- quarantine version
- cancel execution
- drain agent
- retry execution
- replay event, restricted
- expire artifact
- rotate secret
- rebuild cache
- migrate database

## Backup

Back up:

- database
- workflows
- schedules
- configuration
- secret metadata and encrypted store
- audit logs
- artifacts according to policy

Plugin caches do not require backup.
