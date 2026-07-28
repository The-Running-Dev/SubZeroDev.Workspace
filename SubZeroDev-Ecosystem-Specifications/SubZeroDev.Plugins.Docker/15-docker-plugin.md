# Docker Plugin

Split from `15-build-tooling-plugins.md`.

| Field     | Value                                                    |
| --------- | -------------------------------------------------------- |
| Plugin ID | `subzerodev.docker`                                      |
| CLI       | `subzerodev-docker`, alias `sz-docker`                   |
| Status    | Sketch — the trust question below must be answered first |

## Purpose

Build, tag, push, inspect, and scan container images as a plugin command rather than as build-agent
logic.

## The architectural tension

**This plugin needs Docker access, and the security model says Docker access is the thing you least
want to grant.**

`10-security-model.md` lists Docker socket access as a threat surface, and the Docker runtime host's
defaults include "no Docker socket by default". A plugin that mounts the Docker socket can start a
privileged container, mount the host filesystem, and read every other container's secrets. Granting
it is equivalent to granting root on the host.

So this plugin is a deliberate exception, and it must be an explicit one:

- `capabilities.dockerAccess: true` is declared in the manifest and is refused by default policy.
- Only **first-party** trust may be granted it. There is no version of this that is safe for a
  third-party plugin.
- Every execution granted Docker access is audited, per the audit list in the security model.

### Three ways to build, none free

| Approach                                     | Isolation                          | Cost                                                   |
| -------------------------------------------- | ---------------------------------- | ------------------------------------------------------ |
| Mount the host Docker socket                 | **None** — equivalent to host root | Simplest, and the usual choice                         |
| Docker-in-Docker, privileged                 | Weak — privileged container        | Slow, nested storage, still effectively root           |
| Rootless builder (BuildKit, Buildah, Kaniko) | Real                               | No daemon needed; some Dockerfile features unsupported |

**Recommendation: a rootless builder for `build`**, and socket access only for commands that
genuinely require a daemon, such as `inspect` against local images.

This matters because `build` is the common case and the one that would otherwise justify granting
socket access permanently. If building does not need the socket, the exception shrinks to something
rarely used.

## Commands

| Command   | Idempotency   | Notes                                                                                                                  |
| --------- | ------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `build`   | `idempotent`  | Same context and Dockerfile produce the same image; reproducibility is not guaranteed unless the base is digest-pinned |
| `tag`     | `idempotent`  | Local operation                                                                                                        |
| `push`    | `conditional` | Idempotent when the digest already exists in the registry; a mutable tag move is not                                   |
| `inspect` | `idempotent`  | Read-only                                                                                                              |
| `scan`    | `idempotent`  | Read-only; results vary as the vulnerability database updates                                                          |

`compose` is deliberately excluded. Composing multiple services is orchestration, and orchestration
belongs to the Automator's workflow engine, not to a plugin.

## Determinism

Image builds are not byte-reproducible in general — timestamps, package mirrors, and base image
drift all defeat it. The conformance determinism check therefore applies to this plugin's
**artifacts**, not to the image itself.

The artifact is the build report: image digest, base image digest, build arguments, and layer sizes.
Two builds of unchanged inputs may produce different digests, and the report records both so the
difference is visible rather than assumed away.

**Base images must be digest-pinned**, not tag-pinned, or the plugin cannot report what it actually
built on.

## Artifacts

| Artifact            | Content                                                          |
| ------------------- | ---------------------------------------------------------------- |
| `build-report.json` | Image digest, base digest, build args, duration, layer summary   |
| `scan-report.json`  | Vulnerabilities by severity, scanner version, database timestamp |
| `sbom.json`         | Software bill of materials, where the builder can produce one    |

## Secrets

Registry credentials by environment variable, declared in the manifest. Build secrets use the
builder's secret mount rather than build arguments — **a build argument is recorded in image
history and is readable from the published image**, which is a frequent and quiet credential leak.

## Decisions on previously open points

**`scan` moves to a separate security plugin.** Vulnerability databases update daily; this plugin's
release cadence is nowhere near that. Coupling them means either a stale database or a release every
time a feed updates. A separate plugin also lets scanning apply to artifacts this plugin never
built.

**`push` refuses to move an existing tag**, requiring `--allow-tag-move` to do so. Consistent with the
release plugin's refuse-rather-than-overwrite rule: silently moving a tag is how a pinned build stops
being reproducible, and the failure appears at someone else's next pull.

## Still open

1. Which builder — rootless BuildKit, Buildah, or Kaniko. This decides whether Docker socket access is
   ever granted at all, which makes it the most consequential question in the tooling set. _Owned
   outside this workspace._
