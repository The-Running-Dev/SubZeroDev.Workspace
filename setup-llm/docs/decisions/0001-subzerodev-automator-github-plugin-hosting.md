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

## Versioning

The plugin uses semantic versioning for the npm package and for published
container tags. It starts at `0.1.0`, and the pre-`1.0.0` range signals that the
public contracts are still changing across the remaining Phase One milestones.

The date-based `YYYY.MM.DD` convention documented under `docs-template/` applies
to that vendored documentation site and does not extend to this plugin. Two
reasons:

- `YYYY.MM.DD` is not valid semantic versioning, because leading zeros are not
  permitted in numeric identifiers. `2026.07.27` and `2026.10.05` are both
  invalid, and `semver.validRange('^2026.07.27')` is `null`, so a consumer could
  not express a range dependency on the package. npm does not reject the value
  locally, so the failure would surface only at publication or consumption.
- Even in an unpadded form such as `2026.7.27`, a caret range covers every
  release until the end of the calendar year, which would advertise breaking
  contract changes as compatible.

Package version and schema version are deliberately separate. `SCHEMA_VERSION`
governs the compatibility of exported documents and is required in every
serialized model; the package version describes the distributed code.

## Consequences

- The core remains usable without Automator.
- CLI concerns must remain outside provider and service implementations.
- Future runners can reuse the same contracts.
- The repository temporarily contains both the workstation toolkit and this
  product plugin.
- The plugin and `docs-template/` follow different versioning conventions, so
  repository-wide version rules must be scoped rather than applied uniformly.
- Reaching `1.0.0` requires the Phase One contracts to be stable.
