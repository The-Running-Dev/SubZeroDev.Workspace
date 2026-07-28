# Clients: PowerShell and CLI

Split from `08-powershell-and-cli.md`. The conventions plugins must follow moved to
`SubZeroDev.PluginContract/08-cli-conventions.md`.

This document covers the clients that talk to the Automator. PowerShell is a first-class user
interface — it is not the implementation language of the products.

## Automator PowerShell module

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

### Conventions

- Approved PowerShell verbs only. `Get`, `Invoke`, `Stop`, `Save`, `Watch`, `Connect` are all
  approved; a module using unapproved verbs warns on import.
- Objects out, not text. `Get-SzExecution` returns typed objects the pipeline can filter, not a
  formatted table. Formatting is a display concern handled by format files.
- `-WhatIf` and `-Confirm` on every command with side effects, honoured properly rather than
  declared and ignored.
- Errors are terminating or non-terminating deliberately, and `$LASTEXITCODE` from any native call is
  checked rather than assumed. A native command exiting non-zero does not throw by default, which is
  a mistake this repository has already made once elsewhere.
- Credentials use `SecureString` or the platform credential store, never plain parameters, and never
  appear in command history.

### Invoke-SzPlugin

The central command. It must express everything an invocation carries: plugin, version constraint,
command, typed inputs, secret references, execution target, timeout, priority, dry-run, and
idempotency key.

```powershell
Invoke-SzPlugin -Plugin subzerodev.github -Command sync `
    -Input @{ profile = 'standard' } `
    -Target local -TimeoutMinutes 15 -Wait
```

Without `-Wait` it returns an execution object immediately; with it, it streams and blocks until a
terminal state. Both matter: interactive users want the former by default and the latter in scripts.

## Generated plugin wrappers

ContainerPSGenerator can generate ergonomic per-plugin wrappers from a manifest:

```powershell
Sync-SzGitHubProject -OutputPath ./artifacts -IncludePrivate
```

A wrapper may dispatch to a local CLI, a Docker image, or the Automator REST API. **The user-facing
parameters must be identical across all three**, or the wrapper becomes three different commands
wearing one name — and the failure appears only when someone switches transport.

Generation is driven by the manifest's input schemas, which is the practical payoff of requiring
those schemas in the first place.

## Authentication

- local mode with no authentication
- API token
- environment-based token
- profile storage using OS credential facilities — DPAPI on Windows, Keychain on macOS, Secret
  Service on Linux
- OAuth device flow, future

A token must never be written to a profile file in plaintext, and `Connect-SzAutomator` should refuse
to persist one where no secure store is available rather than silently falling back.

## CLI client

The Automator's own CLI follows the same conventions the plugin contract defines for plugins —
POSIX options, `--output-format`, stdout for machine output, stderr for logs, no interactive prompts.

Sharing one convention set means a script author learns it once, and it is why those conventions live
in the contract repository rather than here.

## Open questions

1. Is the Automator CLI a separate binary or a PowerShell-only client in Phase One?
2. Do generated wrappers ship with the plugin, or are they generated on demand at install time?
