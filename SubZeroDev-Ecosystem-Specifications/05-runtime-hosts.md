# Runtime Hosts

## Purpose

A runtime host knows how to execute one implementation of a plugin.

Automator resolves a plugin command to a runtime host based on manifest metadata, execution policy, installation state, and target capabilities.

## Common host contract

Conceptual interface:

```csharp
public interface IPluginRuntimeHost
{
    string Type { get; }

    Task<RuntimeAvailability> CheckAvailabilityAsync(
        PluginRuntime runtime,
        ExecutionTarget target,
        CancellationToken cancellationToken);

    Task<ExecutionHandle> StartAsync(
        PluginInvocation invocation,
        PluginRuntime runtime,
        ExecutionContext context,
        CancellationToken cancellationToken);

    Task CancelAsync(
        ExecutionHandle handle,
        CancellationToken cancellationToken);
}
```

## Docker host

Responsibilities:

- pull or locate image
- validate image digest
- build command
- create isolated container
- map inputs
- mount workspace and artifact directories
- inject secrets
- configure network
- stream logs
- enforce timeout
- stop and remove container
- collect result and artifacts

Security defaults:

- non-root where possible
- read-only root filesystem where possible
- explicit writable mounts
- no Docker socket by default
- no privileged mode by default
- dropped capabilities
- resource limits
- network denied unless declared
- image digest pinning in production

## Local process host

Executes native commands or scripts.

Responsibilities:

- resolve executable
- set working directory
- set environment
- inject secret values securely
- stream output
- capture exit code
- enforce timeout
- terminate process tree

Use for development and trusted local tools.

## .NET host

Two modes:

1. Out-of-process `dotnet <assembly>`
2. In-process module loading, future and trusted-only

Out-of-process is the default to preserve isolation and version independence.

## Node host

Execution forms:

- `node dist/cli.js`
- npm package binary
- package-local command

Must support pinned Node versions or a declared compatible range.

## Python host

Execution forms:

- isolated virtual environment
- Python module
- console script
- packaged executable

Dependencies should not install into the global interpreter.

## PowerShell host

Execution forms:

- script file
- module command
- packaged module

Requirements:

- PowerShell version validation
- no implicit use of caller profile
- controlled module path
- structured output capture
- correct propagation of terminating errors and exit codes

## Remote API host

Treats an external HTTP service as a plugin implementation.

Responsibilities:

- endpoint discovery
- authentication
- request mapping
- polling or callback for long-running operations
- cancellation where supported
- result normalization
- retry behavior
- health checks

## Agent host

Routes invocation to a connected Automator Agent.

The agent performs local runtime resolution and returns streamed logs, state transitions, and artifacts.

## Runtime resolution

Selection order may consider:

1. explicit runtime requested
2. target agent compatibility
3. policy
4. installed runtime
5. preferred runtime
6. version compatibility
7. trust level
8. cache state
9. resource availability

Resolution must be recorded in execution metadata.

## Host isolation rule

Automator should avoid loading independently versioned plugin code into the control-plane process.

Out-of-process execution is the default.
