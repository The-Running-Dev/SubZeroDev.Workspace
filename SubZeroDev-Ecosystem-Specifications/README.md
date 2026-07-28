# SubZeroDev Ecosystem Specifications

Status: Working architecture specification, split by destination repository
Scope: SubZeroDev.Platform, SubZeroDev.Automator, the plugin contract, and the initial plugins

## How this directory is organized

Each top-level directory holds the specifications destined for one repository. They are grouped here
so they can be copied out; this directory is a staging area, not their permanent home.

| Directory                                  | Destination repository           | Contents                                                                                                                                   |
| ------------------------------------------ | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `SubZeroDev.Ecosystem/`                    | Architecture repository          | Vision, logical architecture, pipeline composition, repository layout, testing strategy, roadmap, open questions                           |
| `SubZeroDev.Platform/`                     | Platform repository (exists)     | Platform specification; events and notifications; observability; tenancy, billing, and licensing                                           |
| `SubZeroDev.Automator/`                    | Automator repository             | Automator specification, runtime hosts, workflow engine, execution events and artifacts, clients, REST and MCP, security model, operations |
| `SubZeroDev.PluginContract/`               | Its own repository               | The contract, CLI conventions, conformance suite, manifest and envelope schemas, reference manifest                                        |
| `SubZeroDev.MCP/`                          | Its own repository               | MCP strategy, tool projection from the manifest, security and consent                                                                      |
| `SubZeroDev.WorkItems/`                    | Its own repository               | Shared work-item model and reconciliation library — a library, not a plugin                                                                |
| `SubZeroDev.Plugins.GitHub/`               | GitHub plugin repository         | GitHub plugin                                                                                                                              |
| `SubZeroDev.Plugins.Backlog/`              | Backlog plugin repository        | Backlog plugin — the second plugin                                                                                                         |
| `SubZeroDev.Plugins.Requirements/`         | Requirements Compiler repository | Requirements Compiler                                                                                                                      |
| `SubZeroDev.Plugins.Documentation/`        | Documentation plugin repository  | Documentation plugin                                                                                                                       |
| `SubZeroDev.Plugins.ContainerPSGenerator/` | ContainerPSGenerator repository  | PowerShell module generation                                                                                                               |
| `SubZeroDev.Plugins.Build/`                | Build plugin repository          | Restore, build, test, normalized reports                                                                                                   |
| `SubZeroDev.Plugins.Docker/`               | Docker plugin repository         | Image build, push, scan                                                                                                                    |
| `SubZeroDev.Plugins.Package/`              | Package plugin repository        | NuGet, npm, PowerShell Gallery, archives                                                                                                   |
| `SubZeroDev.Plugins.Release/`              | Release plugin repository        | Notes, tagging, forge releases                                                                                                             |
| `SubZeroDev.Plugins.ProjectSetup/`         | Project Setup plugin repository  | Provisioning a repository from a directory, and holding it to a stated configuration                                                       |

Documents that spanned two products were split rather than assigned to one: events and notifications
(Platform) from execution events and artifacts (Automator); observability (Platform) from operations
(Automator); CLI conventions (contract) from client modules (Automator); the testing layer model
(Ecosystem) from the conformance suite (contract); and the five build-tooling plugins into one
directory each.

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

### Precedence

**The contract outranks every plugin specification.** A plugin document contains only what is true of
that plugin and false of another; anything generic lives in the contract and is referenced, never
restated. See `SubZeroDev.PluginContract/adr/ADR-003`.

## Current stance

A plugin may be implemented as a Docker image, a .NET application, a Node or Python application, a
PowerShell module, a native executable, or a remote HTTP service.

Docker is the preferred distribution and execution option, and the only runtime that can actually
enforce the declared capability model — but it is not the definition of a plugin.

## Decisions taken

Recorded here so the documents are read in light of them:

| Decision            | Choice                                                                  |
| ------------------- | ----------------------------------------------------------------------- |
| Contract home       | Its own repository, versioned and tagged independently                  |
| Contract precedence | The contract outranks plugin specifications                             |
| Platform            | Minimal — six packages alongside Automator, the rest deferred           |
| Build order         | GitHub plugin → Backlog plugin → Automator MVP                          |
| Second plugin       | Backlog — Python, writes externally, needs a direct MCP surface         |
| Local process host  | Out of the Automator MVP                                                |
| CLI naming          | `subzerodev-<name>` canonical, `sz-<name>` alias                        |
| Repository layout   | Platform, Automator, contract, WorkItems, and one repository per plugin |
| MCP                 | A transport, not a runtime; tools projected from the manifest           |
| Signing             | Sigstore cosign, keyless; manifest published as a signed attestation    |
| Secrets             | Environment only — never argv, never config, never tool arguments       |
| GitHub plugin       | Decoupled from Automator; moves to its own repository soon              |

## Status of this set

The four blocking defects found in review are fixed: the exit-code table is canonical and lives only
in the contract, the manifest schema now enforces the prose it encodes, unknown capability keys are
refused rather than ignored, and capability enforcement is bound to the runtime host that can
actually provide it.

Every specification now lives in exactly one place. The two GitHub plugin specifications are merged,
the superseded contract draft is deleted, and all ADRs sit with the repository they belong to,
renumbered from `001` per repository. Nothing about the ecosystem remains under `setup-llm/docs/`,
which now holds only workstation-toolkit documentation.

**No ADR is left in `Proposed`.** The five carried over from the draft are now decided and written
out with their context, consequences, and rejected alternatives, and each records the number it
carried in the original global sequence so the renumbering is traceable.

**Every destination repository carries its own instructions.** A `README.md` saying what it is, an
`AGENTS.md` with the invariants and the placement rules for that repository, and a `CLAUDE.md`
pointing at `AGENTS.md` rather than repeating it. They are written to survive the split — a
repository that arrives with a bare `12-github-plugin.md` and nothing else tells a new reader
nothing.

The split map above also gained three directories it had never listed: `SubZeroDev.MCP/`,
`SubZeroDev.WorkItems/`, and `SubZeroDev.Plugins.Backlog/` all existed without a recorded
destination.

**Both normative schemas exist.** `plugin-manifest.schema.json` and `result-envelope.schema.json`
live in `SubZeroDev.PluginContract/schemas/` and are validated under ajv strict mode. The contract
states that the schemas — not any generated types — are the normative artifact, so an envelope
specified only in prose was a gap in the contract's own terms.

Remaining open questions are listed per document and consolidated in
`SubZeroDev.Ecosystem/19-open-questions.md`.

One known piece of debt is deliberately left: the `NN-` filename prefixes number a single
ecosystem-wide document set that no longer exists. Six files are numbered `15`, and five other
numbers appear in two repositories each. Renaming them now would break every cross-document
reference; it belongs to each repository's split commit, and is tracked as X12 in
`WORK-BREAKDOWN.md`.
