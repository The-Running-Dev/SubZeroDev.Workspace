# ADR-001: Docker Image Inheritance for Documentation Extensibility

## Status

Accepted

Originally drafted as ADR-005 in a single global sequence, renumbered when the specifications split
by destination repository. Numbering is per repository.

The draft recorded the status as "Accepted in existing practice", which is not an ADR state. What it
meant is captured in the context below: this ADR ratifies a pattern already in use rather than
proposing a new one.

## Context

A shared Docusaurus image already carries the theme, navigation shell, build pipeline, and search
configuration. Individual projects derive from it and overlay only their own content.

The pattern predates this specification set and works. The question was not whether to adopt it but
whether to keep it once documentation becomes a plugin under the contract, given the alternatives —
vendoring the tooling per project, or publishing it as an npm package each project installs.

## Decision

**Keep image inheritance as the documentation plugin's primary container implementation.** A project's
documentation image derives `FROM` the shared base and adds content, configuration overrides, and
nothing else.

Two constraints make it safe under the contract.

**The base image is pinned by digest, not by tag.** The plugin contract already requires this for
non-development Docker runtimes, and inheritance is where a mutable tag does the most damage: a base
rebuild would silently change every derived project's output, breaking the determinism requirement in
a way nobody would attribute to the base.

**Derived images add content, not tooling.** A project that needs a build-step change needs it in the
base, where every project gets it. A project-local tooling override is the beginning of the drift the
shared base exists to prevent, and it re-creates the per-project vendoring this decision rejects.

## Consequences

- Tooling is centralized, so a theme or pipeline change is made once.
- A project's repository carries only its own content, which is the delta worth reviewing.
- Local preview and CI deployment use the same image, so "works locally" means something.
- Base image versioning has to be managed deliberately. A base change reaches every project on its
  next rebuild, so the base needs its own release discipline — semantic versioning, a changelog, and
  digest pinning downstream so the upgrade is an explicit commit rather than an ambient event.
- Projects cannot upgrade independently of what the base offers. Accepted: divergence is the cost
  this pattern is chosen to avoid.

## Alternatives considered

**Vendor the tooling into each project.** Maximum independence, no base to coordinate. Rejected: a
theme change becomes N pull requests, and the configurations drift apart between them.

**Publish the tooling as an npm package each project installs.** Lighter than an image and versioned
conventionally. Rejected: it centralizes the JavaScript but not the environment, so Node versions,
system dependencies, and build steps still drift per project. The image is what makes the environment
identical, and the documentation build is sensitive to it.
