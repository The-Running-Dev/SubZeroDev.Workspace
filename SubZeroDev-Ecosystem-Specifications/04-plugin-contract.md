# Plugin Contract

## Definition

A plugin is an independently versioned capability that exposes one or more commands through a stable manifest and invocation contract.

A plugin is not defined by its implementation language or packaging format.

## Required properties

Every plugin must have:

- globally stable ID
- semantic version
- display name
- description
- manifest schema version
- one or more commands
- at least one runtime implementation
- input schemas
- output schemas
- declared secrets
- declared artifact behavior
- documentation
- license metadata
- compatibility metadata

## Plugin ID

Recommended format:

```text
subzerodev.github
subzerodev.requirements
subzerodev.documentation
subzerodev.container-ps-generator
```

IDs are lowercase, stable, and never reused for a different capability.

## Command ID

Recommended format:

```text
sync
list
stats
export
validate
```

A fully qualified command is:

```text
subzerodev.github.sync
```

## Manifest example

```yaml
schemaVersion: "1.0"
id: subzerodev.github
name: SubZeroDev GitHub
version: 1.0.0
description: Collects and normalizes GitHub repository metadata.

commands:
  - id: sync
    description: Synchronize repository metadata.
    inputSchema: schemas/sync.input.schema.json
    outputSchema: schemas/sync.output.schema.json
    timeout: PT15M
    idempotent: true
    artifacts:
      - name: projects
        type: application/json
        required: true

runtimes:
  - id: docker
    type: docker
    image: ghcr.io/the-running-dev/subzerodev-github:1.0.0
    entrypoint: ["github"]
  - id: node
    type: node
    packagePath: "."
    entrypoint: "dist/cli.js"

secrets:
  - id: github-token
    required: true
    environmentVariable: GITHUB_TOKEN
    sensitive: true

capabilities:
  network:
    required: true
  filesystem:
    read:
      - workspace
    write:
      - output
```

## Command input model

Inputs may originate from:

- CLI options
- environment variables
- mounted files
- mounted directories
- artifact references
- stdin
- secret injection
- structured JSON payload

All inputs must normalize into one command input object before execution.

## Command output model

A command should produce:

1. exit code
2. human-readable console output
3. machine-readable result
4. zero or more artifacts

Recommended output envelope:

```json
{
  "schemaVersion": "1.0",
  "status": "succeeded",
  "command": "sync",
  "summary": "Synchronized 42 repositories.",
  "data": {},
  "warnings": [],
  "artifacts": []
}
```

## Exit codes

Baseline:

- `0`: success
- `1`: general failure
- `2`: invalid input
- `3`: authentication or authorization failure
- `4`: external dependency failure
- `5`: partial success
- `124`: timeout
- `130`: cancelled/interrupted

Plugins may define additional codes but must document them.

## CLI baseline

CLI-capable plugins should support:

```text
--help
--version
describe --format json
capabilities --format json
<command> --help
```

## Idempotency

Commands must declare whether they are:

- idempotent
- conditionally idempotent
- non-idempotent

Commands creating external resources should support an idempotency key where the provider allows it.

## Cancellation

Runtime hosts should propagate cancellation:

- process signal
- cancellation token
- container stop
- HTTP cancellation
- agent cancellation request

Plugins should perform graceful cleanup.

## Trust model

Plugins may be:

- trusted first-party
- trusted signed third-party
- untrusted
- development-local

Trust affects:

- allowed runtime
- network access
- filesystem access
- secrets
- MCP exposure
- UI visibility
- automatic updates

## Compatibility

Manifest should declare:

- minimum Automator version
- supported OS
- supported architectures
- runtime requirements
- required external tools
- schema versions
- breaking changes

## Distribution

Supported:

- OCI image
- NuGet
- npm
- PyPI or wheel
- PowerShell Gallery/package
- archive bundle
- remote service registration

Distribution and execution runtime are separate concepts.
