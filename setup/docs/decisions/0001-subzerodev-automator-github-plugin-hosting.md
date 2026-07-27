# ADR-0001: Host SubZeroDev.Automator.Plugins.GitHub as a CLI-First Plugin

**Status:** Accepted
**Date:** 2026-07-27

## Context

SubZeroDev.Automator.Plugins.GitHub needs to run independently today and may later be consumed by
SubZeroDev.Automator. Building it around Automator now would couple the provider,
models, and synchronization behavior to a runtime that does not yet exist.

## Decision

Implement SubZeroDev.Automator.Plugins.GitHub in this repository at
`plugins/SubZeroDev.Automator.Plugins.GitHub`.

The plugin owns its domain models, provider interface, synchronization services,
cache, configuration, and serialization. Its first runner is a standalone CLI.
Automator integration is deferred and will later call the plugin's public
contracts as another runner.

The npm package is named `@subzerodev/automator-plugin-github`. The executable is named
`subzerodev-github` to avoid colliding with unrelated system commands.

## Consequences

- The core remains usable without Automator.
- CLI concerns must remain outside provider and service implementations.
- Future runners can reuse the same contracts.
- The repository temporarily contains both the workstation toolkit and this
  product plugin.
