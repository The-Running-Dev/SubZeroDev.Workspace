# Testing Strategy

## Test layers

### Unit tests

- model validation
- state transitions
- mappings
- policies
- serialization
- expression evaluation

### Contract tests

- plugin manifest
- runtime host
- command input/output
- artifact contract
- provider adapters

### Integration tests

- database
- storage
- event bus
- notifications
- authentication
- Docker host
- remote agent

### End-to-end tests

- install plugin
- invoke command
- stream logs
- produce artifact
- run workflow
- cancel execution
- retry failure
- MCP invocation
- PowerShell invocation

## Determinism

Use:

- fake clock
- fixed IDs where appropriate
- test containers
- fixture plugins
- isolated temporary workspaces
- stable output snapshots

## Security tests

- secret redaction
- unauthorized command
- tenant isolation
- unsafe mount rejection
- untrusted plugin restrictions
- path traversal
- command injection
- malicious output
- oversized logs/artifacts

## Compatibility tests

- Windows
- Linux
- x64
- arm64 where feasible
- PowerShell supported versions
- Node/Python runtime ranges
- Docker engine versions

## Fixture plugins

Create minimal test plugins for each runtime:

- Docker echo
- .NET echo
- Node echo
- Python echo
- PowerShell echo
- failing plugin
- timeout plugin
- artifact plugin
