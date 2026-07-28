# SubZeroDev Ecosystem Specifications

Status: Working architecture specification, split by destination repository
Scope: SubZeroDev.Platform, SubZeroDev.Automator, the plugin contract, and the initial plugins

## How this directory is organized

Each top-level directory holds the specifications destined for one repository. They are grouped here
so they can be copied out; this directory is a staging area, not their permanent home.

| Directory                           | Destination repository           | Contents                                                                                                              |
| ----------------------------------- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `SubZeroDev.Ecosystem/`             | Architecture repository          | Vision, logical architecture, repository layout, testing strategy, roadmap, open questions                            |
| `SubZeroDev.Platform/`              | Platform repository (exists)     | Platform specification; tenancy, billing, and licensing                                                               |
| `SubZeroDev.Automator/`             | Automator repository             | Automator specification, runtime hosts, workflow engine, events, clients, REST and MCP, observability, security model |
| `SubZeroDev.PluginContract/`        | Its own repository               | The contract every plugin satisfies, plus the manifest schema and reference manifest                                  |
| `SubZeroDev.Plugins.GitHub/`        | GitHub plugin repository         | GitHub plugin specification                                                                                           |
| `SubZeroDev.Plugins.Requirements/`  | Requirements Compiler repository | Requirements Compiler specification                                                                                   |
| `SubZeroDev.Plugins.Documentation/` | Documentation plugin repository  | Documentation plugin specification                                                                                    |
| `SubZeroDev.Plugins.BuildTooling/`  | Build tooling repositories       | ContainerPSGenerator, build, Docker, package, and release plugins                                                     |

`REVIEW.md` and `WORK-BREAKDOWN.md` stay here. They are working documents about the specifications,
not part of any product's documentation.

### Copying rule

**Move, do not copy.** `16-repository-layout-and-packaging.md` originally proposed that
specifications live centrally and be "copied/versioned into product repositories". Copying documents
between repositories is how this repository ended up tracking two byte-identical copies of the
GitHub plugin specification and ADR-0001 under both `setup/` and `setup-llm/`, which had to be found
and deleted. A second copy drifts the moment either is edited. Reference by tag or submodule
instead.

## Reading order

For someone new to the ecosystem:

1. `SubZeroDev.Ecosystem/00-vision-and-boundaries.md`
2. `SubZeroDev.Ecosystem/01-ecosystem-architecture.md`
3. `SubZeroDev.PluginContract/04-plugin-contract.md`
4. `SubZeroDev.Automator/03-automator-specification.md`
5. `SubZeroDev.Platform/02-platform-specification.md`
6. Whichever plugin you are working on

`REVIEW.md` explains why several documents read the way they now do, and `WORK-BREAKDOWN.md` says
what to build in what order.

## Architectural rule

```text
SubZeroDev.Platform
        ↓
SubZeroDev.Automator
        ↓
Plugins / Workflows / Products
```

Platform never depends on Automator or on product-specific plugins. Automator never absorbs plugin
business logic. Plugins never depend on Automator internals.

The plugin contract sits outside this stack: it is depended on by Automator and by every plugin, and
depends on nothing, which is why it gets its own repository rather than living inside Platform.

## Current stance

A plugin may be implemented as a Docker image, a .NET application, a Node or Python application, a
PowerShell module, a native executable, or a remote HTTP service.

Docker is the preferred distribution and execution option, and the only runtime that can actually
enforce the declared capability model — but it is not the definition of a plugin.

## Decisions taken

Recorded here so the documents are read in light of them:

| Decision          | Choice                                                         |
| ----------------- | -------------------------------------------------------------- |
| Contract home     | Its own repository, versioned and tagged independently         |
| Platform          | Repository exists; specifications split out for manual copying |
| Build order       | GitHub plugin → second plugin → Automator MVP                  |
| CLI naming        | `subzerodev-<name>` canonical, `sz-<name>` alias               |
| Repository layout | Platform, Automator, and one repository per substantial plugin |
| GitHub plugin     | Moves to its own repository soon; preparation only for now     |

## Status of this set

The four blocking defects found in review are fixed: the exit-code table is canonical and lives only
in the contract, the manifest schema now enforces the prose it encodes, unknown capability keys are
refused rather than ignored, and capability enforcement is bound to the runtime host that can
actually provide it.

Remaining open questions are listed per document and consolidated in
`SubZeroDev.Ecosystem/19-open-questions.md`.
