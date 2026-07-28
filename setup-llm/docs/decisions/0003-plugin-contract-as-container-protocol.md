# ADR-0003: Define the Plugin Contract as a Container Protocol

**Status:** Proposed — awaiting a fuller specification from the author
**Date:** 2026-07-28
**Amends:** [ADR-0001](0001-subzerodev-automator-github-plugin-hosting.md) if accepted

## Context

ADR-0001 deferred Automator integration entirely and said the plugin's "public
contracts" would later be consumed by another runner. That wording implied an
in-process language interface, and it left the shape of the boundary undecided.

The framing has since sharpened. The GitHub plugin is not a one-off: it is the
first of several plugins, meant to run as a container by hand today and to be
driven by an Automator host later. The Automator will support plugins written in
any language, through per-language adapters.

That last point decides most of what follows. A contract expressed as a
TypeScript interface would make "plugins in any language" false the moment it was
written, because every plugin would have to be TypeScript to satisfy it.

Deferring the boundary further is also not free. The plugin is about to grow
commands, an output shape, and a Docker surface. Each of those hardens into a
de-facto interface whether or not anyone designs it, and retrofitting a contract
onto three accidental ones is more work than defining it now.

## Decision

### The normative surface is a container image with a CLI entrypoint

A plugin is defined by what it does at the process boundary: the commands it
accepts, the JSON it writes to stdout, the exit code it returns, and the
artifacts it leaves behind. This is specified in
[the plugin contract](../specifications/subzerodev-automator-plugin-contract.md).

A Node in-process binding may be added later for a Node host. It would be an
optimization over the contract, never a second definition of it, and it is not
part of this decision.

### JSON Schemas are the normative artifact, not TypeScript types

Adapters are polyglot, so what they consume must be language-neutral. Zod may
remain the authoring source and TypeScript types may be inferred from it, but the
committed, versioned JSON Schema is what the contract publishes.

### Plugins are one-shot processes

A run starts, works, and exits. No progress streaming, no cooperative
cancellation, no resident service. A host that needs to stop a run kills it.

This is a deliberate scope cut rather than a claim that progress reporting is
worthless. It roughly doubles the protocol surface and the conformance suite, and
nothing needs it yet.

### Inter-plugin data flow is reserved, not designed

Every artifact is declared in the manifest with a schema reference, and every run
reports what it wrote with a hash. That is enough for a future host to route
artifacts without a contract break.

The part that would actually be hard — a shared cross-plugin type vocabulary —
is not designed, because there is exactly one plugin and designing a vocabulary
from a single example produces a vocabulary that fits one example.

### The host stays out of scope

Scheduling, orchestration, retry policy, and secret storage belong to the
Automator and are not specified here. The contract is written so that the host's
design can change without invalidating any plugin.

### The GitHub plugin is the reference implementation

It is both the first implementation and the worked example other plugins copy.
The reusable asset, though, is the contract plus its conformance suite — not the
plugin's source tree.

This distinction is worth holding onto. A reference implementation that doubles
as a template accumulates domain specifics that new plugins then inherit:
someone scaffolding a Jira plugin from this one should not end up with a
`ProjectProvider` because GitHub needed one. The conformance suite is what makes
the template checkable, because it tests the contract rather than the copy.

## Consequences

- Any language can implement a plugin, and the Automator's own runtime stops
  mattering to plugin authors.
- Every run pays process startup and JSON serialization. Accepted: this work is
  measured in seconds to minutes, and the contract discourages the chatty
  per-item shape where the overhead would matter.
- The GitHub plugin gains a `manifest` command, a result envelope, and image
  labels that were not previously planned, and its `--json` mode moves earlier
  than Milestone 7 because conformance depends on it.
- Structured logs must be written to stderr. Pino defaults to stdout, so this is
  an explicit construction requirement, and a single stray log line would corrupt
  the envelope for every adapter at once.
- `SUBZERODEV_GITHUB_CACHE` and `SUBZERODEV_GITHUB_OUTPUT` become
  `SUBZERODEV_PLUGIN_CACHE` and `SUBZERODEV_PLUGIN_OUTPUT`, so an adapter can
  mount working directories without per-plugin knowledge. This changes `run.ps1`,
  the Dockerfile, and the README.
- Exit codes are promoted from the GitHub plugin's specification to the contract,
  where they belong.
- A third versioned thing exists: contract version, plugin version, and artifact
  schema versions all move independently.
- ADR-0001's "Automator integration is explicitly deferred" now means the _host_
  is deferred. The _interface_ is not.

## Alternatives considered

**An in-process TypeScript interface.** Best ergonomics and type safety, and it
would have suited a Node host well. Rejected because it forecloses plugins in
other languages, which is a stated requirement.

**Deferring the contract until a second plugin exists.** Genuinely tempting —
designing an interface from one example is how over-general interfaces get built.
Rejected because the plugin is about to grow the exact surfaces the contract
governs, and those would harden into an accidental interface first. The
compromise is to specify the boundary now and leave the cross-plugin data
vocabulary explicitly reserved, which is the part that actually needs a second
example.

**A long-running plugin service over HTTP or a socket.** Lowest per-call
overhead. Rejected: it turns every plugin into a server with lifecycle, health,
and concurrency concerns, and it contradicts the existing non-goals covering
background services and REST APIs.
