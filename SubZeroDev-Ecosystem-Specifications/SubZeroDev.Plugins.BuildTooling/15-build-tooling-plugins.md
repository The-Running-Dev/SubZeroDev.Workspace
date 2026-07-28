# Build and Tooling Plugins

## Purpose

Separate build capabilities from the Automator orchestrator.

The build agent becomes thin and delegates to independent tools.

## Candidate plugins

### ContainerPSGenerator

Existing capability:

- inspect repositories
- infer commands
- generate PowerShell modules
- expose container CLIs through native PowerShell
- generate help and Markdown
- package and validate output

### Build plugin

Potential commands:

- restore
- build
- test
- package
- publish

Avoid making this a universal language-specific build system. Prefer adapters or language-specific commands.

### Docker plugin

Commands:

- build
- tag
- push
- inspect
- scan
- compose

### Package plugin

Providers:

- NuGet
- npm
- PowerShell
- archives

### Release plugin

- generate notes
- create GitHub release
- attach artifacts
- tag version
- publish release metadata

## Thin build agent model

```text
Build Agent
  - receive job
  - resolve tools
  - execute plugins
  - stream logs
  - return artifacts
```

The agent should not contain documentation, package, or language-specific build logic.

## Daisy chaining

Example:

```text
repository.inspect
→ build.restore
→ build.test
→ container-ps-generator.generate
→ documentation.build
→ package.nuget
→ docker.build
→ release.github
→ notification.discord
```
