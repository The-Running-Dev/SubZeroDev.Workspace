# Repository Layout and Packaging

## Monorepo versus multiple repositories

Recommended initial approach:

- Platform: its own repository
- Automator: its own repository
- each substantial plugin: its own repository
- shared plugin SDK/contracts: Platform or dedicated repository
- specifications may live in a central architecture repository and be copied/versioned into product repositories

## Platform repository

```text
src/
  SubZeroDev.Platform.Abstractions/
  SubZeroDev.Platform.Core/
  SubZeroDev.Platform.Hosting/
tests/
docs/
samples/
build/
Directory.Build.props
Directory.Packages.props
```

## Automator repository

```text
src/
  SubZeroDev.Automator.Domain/
  SubZeroDev.Automator.Application/
  SubZeroDev.Automator.Infrastructure/
  SubZeroDev.Automator.Api/
  SubZeroDev.Automator.Agent/
  SubZeroDev.Automator.PowerShell/
tests/
docs/
deploy/
examples/
```

## Plugin repository baseline

```text
src/
tests/
docs/
schemas/
examples/
plugin.yaml
Dockerfile
README.md
CHANGELOG.md
```

## Packaging

Platform:

- NuGet packages
- container samples
- templates, future

Automator:

- server image
- agent image/binaries
- PowerShell module
- Helm chart, future

Plugins:

- native package as appropriate
- OCI image
- manifest
- checksums
- SBOM
- signatures, future

## Versioning

- SemVer
- immutable release tags
- OCI digest recorded
- manifest references exact versions for production
- `latest` allowed only for development
