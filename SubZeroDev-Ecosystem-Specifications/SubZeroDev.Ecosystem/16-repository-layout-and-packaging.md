# Repository Layout and Packaging

## Repositories

Decided, not proposed:

| Repository                  | Contents                                                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `SubZeroDev.Platform`       | The reusable application framework. Exists.                                                                                  |
| `SubZeroDev.Automator`      | The orchestration product.                                                                                                   |
| `SubZeroDev.PluginContract` | The contract, manifest schema, envelope schema, and conformance suite.                                                       |
| `SubZeroDev.MCP`            | MCP strategy, tool projection, security and consent.                                                                         |
| `SubZeroDev.WorkItems`      | The shared work-item model and reconciliation. A library, not a plugin.                                                      |
| One per substantial plugin  | GitHub, Backlog, Project Setup, Requirements Compiler, Documentation, ContainerPSGenerator, Build, Docker, Package, Release. |
| Architecture                | Cross-cutting specifications and ADRs that belong to no single product.                                                      |

`SubZeroDev.MCP` is separate from the Automator because the projection serves both hosts — a plugin's
own `mcp` command and the Automator's brokered endpoint. Inside the Automator it would become the
brokered host's private concern, and the direct host would grow a second projection.

`SubZeroDev.WorkItems` is separate from both of its consumers for the reason any shared model is: two
plugins expressing the same model independently would disagree, and the disagreement would surface as
two tools each claiming to be authoritative about what a work item is.

### Every repository carries its own instructions

Each repository holds a `README.md` describing what it is, an `AGENTS.md` with the working
instructions for that repository — its invariants, what belongs in it, and what belongs elsewhere —
and a `CLAUDE.md` pointing at `AGENTS.md` rather than repeating it.

The cross-repository conventions block inside each `AGENTS.md` is repeated verbatim, with the
canonical copy in the Architecture repository. That is the one place duplication is permitted, and
only because a repository has to stand alone once the split happens: instructions that work only
inside the staging monorepo stop working exactly when they are needed.

### Why the contract gets its own repository

It is depended on by the Automator and by every plugin, and depends on nothing.

Inside Platform it would version on Platform's cadence and make a Python plugin author conceptually
depend on a .NET framework repository. Inside the architecture repository it would turn a documents
repository into a build-time dependency for every plugin. Its own repository is the only home that
matches its actual dependency shape, and it is what lets a plugin pin a contract version.

## Specifications move, they are never copied

**A specification has exactly one home.** Products reference it by tag or submodule.

An earlier draft proposed that specifications "live in a central architecture repository and be
copied/versioned into product repositories". That practice has already cost this project twice:
once when a repository rename left two byte-identical copies of a plugin specification and an ADR
tracked at both `setup/` and `setup-llm/`, and again when two separate specifications came to
describe the GitHub plugin and disagreed about exit codes in a way that would have recorded
authentication failures as partial successes.

Both were found by review rather than by anything automated, which is the problem: a second copy
drifts silently the moment either is edited, and nothing tells you which one is stale.

Where a product genuinely needs the specification text alongside its code — for an offline build, or
for a published documentation site — it references a tagged commit rather than duplicating the file.

## Layouts

### Platform

```text
src/
  SubZeroDev.Platform.Abstractions/
  SubZeroDev.Platform.Core/
  SubZeroDev.Platform.Hosting/
  SubZeroDev.Platform.Persistence/
  SubZeroDev.Platform.Observability/
  SubZeroDev.Platform.Testing/
tests/
docs/
samples/
build/
Directory.Build.props
Directory.Packages.props
```

Six packages near-term. The remainder are candidates, added when a consumer needs them — see
`SubZeroDev.Platform/02-platform-specification.md`.

### Automator

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

### Plugin contract

```text
schemas/
  plugin-manifest.schema.json
  result-envelope.schema.json
conformance/
examples/
docs/
```

Schemas are published at version-pathed URLs, so a 2.0 schema cannot overwrite a pinned 1.0
reference.

### Plugin

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

`plugin.yaml` is the manifest, authored in YAML and canonicalized to JSON for validation and
signing.

## Packaging

| Product         | Artifacts                                                                                 |
| --------------- | ----------------------------------------------------------------------------------------- |
| Platform        | NuGet packages                                                                            |
| Automator       | Server image, agent image and binaries, PowerShell module; Helm chart future              |
| Plugin contract | Published schemas, conformance suite package                                              |
| Plugins         | OCI image, native package where appropriate, manifest, checksums, SBOM; signatures future |

## Versioning

- Semantic versioning throughout, with immutable release tags.
- **Images are pinned by digest in manifests**, never by tag. A version tag is mutable, so a
  tag-pinned manifest does not describe what will actually run. `latest` is development-only.
- The contract, each plugin, and each artifact schema version independently. Conflating them forces a
  version bump on unrelated changes.
- Date-based versions such as `YYYY.MM.DD` are not used for packages: they are not valid semantic
  versions, so a consumer cannot express a range dependency.

## Decisions on previously open points

**The architecture repository publishes its own documentation site and owns that pipeline.**
Specifications are read most by people who are not currently building, so they are worth publishing;
and keeping the pipeline with the content is what stops the published site drifting from the source.

**The plugin template lives in the contract repository**, not in the GitHub plugin. What a template
scaffolds is contract conformance — manifest, envelope, exit codes, conformance wiring — not
GitHub-shaped structure. Scaffolding from the GitHub plugin is how a Jira plugin ends up with a
`ProjectProvider` it never needed, which is precisely the inheritance problem ADR-003 exists to
prevent.
