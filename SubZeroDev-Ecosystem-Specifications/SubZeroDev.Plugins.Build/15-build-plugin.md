# Build Plugin

Split from `15-build-tooling-plugins.md`.

| Field     | Value                                       |
| --------- | ------------------------------------------- |
| Plugin ID | `subzerodev.build`                          |
| CLI       | `subzerodev-build`, alias `sz-build`        |
| Status    | Sketch — scope question below is unresolved |

## Purpose

Run restore, build, and test steps for a project, and report results in a normalized shape.

Packaging belongs to the package plugin; see Decisions below.

## The scope trap

The original note said "avoid making this a universal language-specific build system", which is the
right instinct and easy to lose. Every build system began as a thin wrapper.

The pressure is predictable: .NET needs a solution filter, Node needs a workspace flag, Python needs
an environment, and each addition looks small. Within a few iterations the plugin contains a build
matrix, a dependency graph, and caching logic — reimplementing MSBuild and npm badly.

**The boundary that holds:** this plugin _invokes_ a project's existing build tooling and _normalizes
the results_. It does not decide how to build. If a project needs something the plugin cannot
express, the answer is a project-level script the plugin invokes — not a new plugin feature.

The value delivered is normalization: a single result shape across ecosystems, so a workflow can
branch on "tests failed" without knowing whether it ran `dotnet test` or `vitest`.

## Commands

| Command   | Idempotency  | Notes                                                |
| --------- | ------------ | ---------------------------------------------------- |
| `detect`  | `idempotent` | Identify project type and available steps; read-only |
| `restore` | `idempotent` | Dependency resolution                                |
| `build`   | `idempotent` | Compile                                              |
| `test`    | `idempotent` | Run tests; a failing test is exit `3`, not a crash   |

## Adapters

One adapter per ecosystem, behind a provider boundary:

| Ecosystem  | Detection           | Invokes                                  |
| ---------- | ------------------- | ---------------------------------------- |
| .NET       | `*.sln`, `*.csproj` | `dotnet`                                 |
| Node       | `package.json`      | The package manager the lockfile implies |
| Python     | `pyproject.toml`    | The declared build backend               |
| PowerShell | `*.psd1`            | Module analysis and Pester               |

**Detection is reported, never guessed silently.** `detect` writes what it found and why; a project
matching two ecosystems is an error requiring explicit configuration, not a coin flip.

Adapters resolve the package manager from the lockfile rather than assuming — a repository with
`pnpm-lock.yaml` built with `npm` produces a different dependency tree, and the failure appears far
from the cause.

## Test result normalization

The genuinely useful part. Adapters parse native output into one shape:

```json
{
  "total": 142,
  "passed": 139,
  "failed": 2,
  "skipped": 1,
  "durationSeconds": 48.2,
  "failures": [{ "name": "…", "message": "…", "file": "…", "line": 42 }]
}
```

Prefer a machine-readable report the tool already produces — TRX, JUnit XML, JSON reporters — over
parsing console output. Console formats change between minor versions and parsing them is a standing
source of breakage.

**A failing test is a successful plugin run** in the sense that the plugin did its job. It exits `3`
with a populated report, not `0`. The distinction matters for the workflow that wants to publish test
results even when the build failed.

## Determinism

Build outputs are frequently not byte-reproducible — embedded timestamps, absolute paths, and
compiler versions all defeat it. Conformance determinism therefore applies to the plugin's **reports**,
not to compiled binaries.

Reports must exclude durations from the determinism comparison, or every run differs.

## Artifacts

| Artifact                 | Content                                     |
| ------------------------ | ------------------------------------------- |
| `build-report.json`      | Steps run, outcome, duration, tool versions |
| `test-report.json`       | Normalized results, as above                |
| `dependency-report.json` | Resolved dependency tree with versions      |

## Decisions on previously open points

**`package` belongs to the package plugin, not this one.** Two plugins claiming the same command is
exactly the boundary erosion this document warns about, and packaging is where registry semantics
live. The `package` command is **removed** from the table above; this plugin's `build` produces
compiled output and the package plugin turns it into a distributable.

**The toolchain must be present in the image.** One image per ecosystem, rather than a plugin that
installs SDKs at run time. Installing toolchains means network access during builds, non-deterministic
versions, and a plugin that is quietly a package manager. The cost is more images, which is the cheaper
problem.

**How much configuration is too much — a usable rule:** if a setting duplicates something the
ecosystem's native tooling already expresses, it does not belong here. A `.csproj` property, an npm
script, or a `pyproject.toml` field is the right place; a project-level script the plugin invokes is
the escape hatch. The moment this plugin needs its own build matrix, it has become a build system.
