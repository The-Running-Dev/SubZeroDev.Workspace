# PowerShell and CLI Integration

## Principle

Manual execution remains a first-class use case.

Each tool should have a native CLI or equivalent callable interface.

PowerShell is a first-class user interface, not the only implementation language.

## Generic Automator PowerShell module

Proposed module:

```text
SubZeroDev.Automator.PowerShell
```

Core commands:

```powershell
Connect-SzAutomator
Get-SzPlugin
Get-SzPluginCommand
Invoke-SzPlugin
Get-SzExecution
Watch-SzExecution
Stop-SzExecution
Get-SzWorkflow
Invoke-SzWorkflow
Get-SzSchedule
Get-SzAgent
Get-SzArtifact
Save-SzArtifact
```

## Generated plugin wrappers

ContainerPSGenerator can generate ergonomic wrappers.

Example:

```powershell
Sync-SzGitHubProject `
    -OutputPath ./artifacts `
    -IncludePrivate
```

The wrapper may invoke:

- local CLI
- Docker image
- Automator REST API

The user-facing command should preserve equivalent input semantics.

## CLI conventions

- POSIX-style long options
- stable command names
- `--help`
- `--version`
- JSON output mode
- no interactive prompts unless explicitly requested
- stdin support where useful
- predictable exit codes
- stdout for normal output
- stderr for diagnostics
- no secrets printed
- `--dry-run` where side effects exist

## Structured output

Every CLI command should support:

```text
--output-format text
--output-format json
```

YAML is optional.

## Shell completion

Generate completion for:

- PowerShell
- Bash
- Zsh
- Fish, future

## Config precedence

```text
CLI arguments
→ environment variables
→ config file
→ defaults
```

## Authentication

PowerShell and CLI clients should support:

- local mode
- API token
- OAuth device flow, future
- environment-based token
- profile storage using OS credential facilities
