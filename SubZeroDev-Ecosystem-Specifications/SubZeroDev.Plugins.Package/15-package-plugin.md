# Package Plugin

Split from `15-build-tooling-plugins.md`.

| Field     | Value                                    |
| --------- | ---------------------------------------- |
| Plugin ID | `subzerodev.package`                     |
| CLI       | `subzerodev-package`, alias `sz-package` |
| Status    | Sketch                                   |

## Purpose

Produce and publish distributable packages for NuGet, npm, PowerShell Gallery, and plain archives,
behind one provider boundary.

## The property that shapes everything

**Most package registries treat a published version as permanent.** npm restricts unpublishing, NuGet
delists rather than deletes, PowerShell Gallery is similar. Publishing the wrong bytes under a
version number is effectively unrecoverable — the remedy is always a new version, never a correction.

So `publish` is dry run by default, and the plugin's job is to make the irreversible step as
well-checked as possible before it happens.

## Commands

| Command   | Idempotency   | Default mode         |
| --------- | ------------- | -------------------- |
| `pack`    | `idempotent`  | Executes             |
| `verify`  | `idempotent`  | Executes — read-only |
| `publish` | `conditional` | **Dry run**          |

### Conditional idempotency, stated

`publish` is idempotent when the version already exists in the registry **with a matching digest**,
in which case it succeeds without republishing. It **fails** when the version exists with different
content, because that is a genuine conflict and the only correct resolution is a human choosing a new
version.

It never overwrites. Where a registry permits overwriting, the plugin still refuses.

## Provider boundary

`pack` and `publish` differ substantially per ecosystem — manifest formats, versioning rules,
authentication, and what "already published" means. Each registry is a provider behind a common
interface, exactly as GitHub is a provider inside the GitHub plugin.

Ecosystem-specific behaviour worth capturing per provider:

| Registry           | Notable constraint                                                           |
| ------------------ | ---------------------------------------------------------------------------- |
| npm                | Scoped packages default to private; publishing public needs an explicit flag |
| NuGet              | Symbol packages are separate; version normalization can surprise             |
| PowerShell Gallery | Manifest metadata is validated on push, not locally                          |
| Archive            | No registry semantics; digest and naming convention are the whole contract   |

## Verification before publish

`verify` runs against a packed artifact, not against source, so what is checked is what would ship:

- the version is not already present with different content
- required metadata is complete — license, description, repository URL, authors
- no development or local dependency references remain
- **no secret canary appears in the package contents**, catching a `.env` or a config file swept in
  by an over-broad include
- the package installs into a clean environment

That last check is worth its cost. A package that builds but does not install is a failure that
otherwise reaches users first.

## Artifacts

| Artifact              | Content                                                     |
| --------------------- | ----------------------------------------------------------- |
| `package-report.json` | Package identity, version, digest, size, dependency summary |
| `verify-report.json`  | Each check with its outcome                                 |

The packed file itself is an artifact too, and is what `publish` consumes — `publish` never re-packs,
so the bytes verified are the bytes published.

## Secrets

Registry tokens by environment variable, one per registry, scoped to publish only where the registry
supports scoping. A token that can publish is a token that can ship code under the project's name,
and it should not be reused for reads.

## Open questions

1. Is provenance or signing produced here, or by the release plugin?
2. Does `publish` support a staged or pre-release channel per registry?
3. Should the plugin refuse to publish a version whose git tag does not exist?
