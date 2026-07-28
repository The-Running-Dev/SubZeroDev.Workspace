# SubZeroDev Automator Plugin Contract

| Field                | Value                                         |
| -------------------- | --------------------------------------------- |
| Contract version     | 0.1 (draft)                                   |
| Status               | Design — not yet implemented                  |
| Normative surface    | Container image with a CLI entrypoint         |
| Decision record      | ADR-0003                                      |
| First implementation | `plugins/SubZeroDev.Automator.Plugins.GitHub` |

This document defines what a program must do to be an Automator plugin. It does
not define the Automator host, which is deliberately out of scope: the contract
is written so that a host in any language can drive a plugin in any language
through a thin adapter.

## Why a process contract rather than a language interface

The Automator will support plugins in any language, through adapters. A process
boundary is the only surface every language already shares. Defining the contract
as a TypeScript interface would make "any language" false the moment it was
written.

So the normative definition is: **a container image, a CLI, JSON on stdout, and an
exit code.** An in-process binding for a Node host may exist later as a
convenience, but it is an optimization over this contract, never a second
definition of it.

The cost is honest and accepted: one process per run, and JSON serialization at
the boundary. For work measured in seconds-to-minutes — which is what these
plugins do — that overhead is irrelevant. It would matter for a chatty, per-item
API, which is exactly the shape this contract discourages.

A second consequence follows: **the JSON Schemas are the normative artifact, not
the TypeScript types.** Types may be generated from the schemas, and the schemas
may in turn be generated from Zod, but what a .NET or Python adapter consumes is
the committed, versioned schema file.

## Two boundaries that are easy to confuse

The GitHub plugin has both, and they run in different directions:

```text
        ┌─────────────── plugin boundary (this document) ───────────────┐
host  →  adapter  →  [ container: CLI → services → provider → Octokit ] →  artifacts
                                              └── provider boundary ──┘
```

- The **provider boundary** is internal: GitHub versus GitLab versus Azure
  DevOps. It exists only in plugins that integrate a third-party service, and it
  is the plugin author's business.
- The **plugin boundary** is external: host versus plugin. Every plugin has it,
  and it is this contract.

Conflating them is the likeliest way to get this wrong — for instance by leaking
a domain type such as `Project` into the contract, which would only make sense
for plugins that happen to produce projects.

## Terms

| Term     | Meaning                                                                       |
| -------- | ----------------------------------------------------------------------------- |
| Host     | The Automator, or a human at a terminal. Out of scope here.                   |
| Adapter  | Host-side code that starts a plugin and reads its output. Per-language, thin. |
| Plugin   | A container image satisfying this contract.                                   |
| Run      | One invocation of one command.                                                |
| Manifest | A plugin's self-description, obtainable without configuring it.               |
| Envelope | The machine-readable result of a run.                                         |
| Artifact | A file a run produces, declared in the manifest.                              |

## Channels

Three channels, with one rule that matters more than the rest:

| Channel   | Carries                                                         |
| --------- | --------------------------------------------------------------- |
| stdout    | Machine output: the manifest, or the envelope in `--json` mode. |
| stderr    | Human text and structured logs, always.                         |
| Exit code | The outcome, as a small integer.                                |

**Logs must never reach stdout.** A single log line on stdout corrupts the
envelope and breaks every adapter at once, in a way that looks like a parse bug
rather than a logging bug. This is not hypothetical: Pino writes to stdout by
default, so the logger must be explicitly constructed against stderr, and
conformance asserts it.

Precisely:

- `manifest` always writes one JSON document to stdout.
- A work command writes the envelope to stdout when `--json` is in effect, and a
  human summary otherwise.
- `--help` and `--version` write human text to stdout; they are for people.
- Everything else a plugin wants to say goes to stderr.

## Required commands

| Command       | Required       | Behavior                                                  |
| ------------- | -------------- | --------------------------------------------------------- |
| `manifest`    | Yes            | Print the manifest. Exit 0.                               |
| `validate`    | Yes            | Check configuration and readiness without doing the work. |
| `--help`      | Yes            | Usage. Exit 0.                                            |
| `--version`   | Yes            | Plugin version. Exit 0.                                   |
| Work commands | Plugin-defined | Declared in the manifest.                                 |

`manifest` carries a hard requirement: **it must succeed in a bare container** —
no configuration file, no secrets, no network, no mounted volumes. A host has to
be able to ask an unconfigured image what it is and what it would need. A plugin
that reads its config before printing its manifest fails this, and it is an easy
mistake to make by wiring configuration loading into a shared startup path.

## Manifest

```jsonc
{
  "contractVersion": "0.1.0",
  "plugin": {
    "name": "subzerodev-github",
    "version": "0.1.0",
    "description": "Normalized GitHub repository and portfolio data",
  },
  "commands": [
    {
      "name": "sync",
      "summary": "Download or incrementally update repository data",
    },
  ],
  "configuration": { "$ref": "./schemas/github.config.schema.json" },
  "secrets": [
    {
      "name": "GITHUB_TOKEN",
      "required": true,
      "description": "GitHub personal access token with repo:read",
    },
  ],
  "artifacts": [
    {
      "path": "projects.json",
      "mediaType": "application/json",
      "schemaRef": "./schemas/projects.schema.json",
      "producedBy": ["sync", "export"],
    },
  ],
  "requirements": {
    "network": true,
    "cache": "required",
    "output": "required",
  },
  "exitCodes": { "0": "success", "2": "usage", "3": "operational" },
}
```

Notes on the fields that carry weight:

- `secrets` declares **names, never values**. This is how a host knows what to
  inject without the plugin ever describing a credential it holds.
- `artifacts` is the data-flow stub described below.
- `exitCodes` is echoed so an adapter can render a failure without hardcoding
  this document.

## Invocation

| Input         | Mechanism                                                                         |
| ------------- | --------------------------------------------------------------------------------- |
| Configuration | Read-only mount at `/etc/subzerodev/plugin.config.json`, or `--config`.           |
| Secrets       | Environment variables only, named by the manifest.                                |
| Cache         | Writable mount, `SUBZERODEV_PLUGIN_CACHE`, default `/var/lib/subzerodev/cache`.   |
| Output        | Writable mount, `SUBZERODEV_PLUGIN_OUTPUT`, default `/var/lib/subzerodev/output`. |

Secrets go through the environment and nowhere else. Not argv, which is visible
to any process that can read `/proc`; not the configuration file, which is the
thing people commit.

The cache and output environment variable names are deliberately
**plugin-neutral**. An adapter should not need per-plugin knowledge to mount a
working directory. The GitHub plugin currently uses `SUBZERODEV_GITHUB_CACHE` and
`SUBZERODEV_GITHUB_OUTPUT`, which predate this contract and must be renamed.

Additional requirements:

- The container runs as a non-root user.
- No TTY is required, and no run may prompt for input. A host is never there to
  answer.
- A run must tolerate a read-only configuration mount.

## Result envelope

```jsonc
{
  "envelopeVersion": "1.0.0",
  "plugin": { "name": "subzerodev-github", "version": "0.1.0" },
  "command": "sync",
  "outcome": "partial",
  "startedAt": "2026-07-28T10:00:00Z",
  "finishedAt": "2026-07-28T10:02:13Z",
  "artifacts": [{ "path": "projects.json", "bytes": 48213, "sha256": "…" }],
  "diagnostics": [
    {
      "severity": "warning",
      "code": "repository_statistics_unavailable",
      "message": "Statistics endpoint did not settle within the retry budget",
      "subject": "repository:12345",
    },
  ],
  "metrics": { "requests": 412, "rateLimitRemaining": 4588 },
  "exitCode": 4,
}
```

- `outcome` duplicates what the exit code says, on purpose. An adapter should be
  able to branch on a word rather than memorize a table.
- `diagnostics` entries are structured so a host can aggregate them, and carry a
  `subject` so a partial failure names what failed. They are subject to the same
  no-secrets rule as everything else.
- `artifacts` reports what was actually written, with hashes, which is what makes
  determinism checkable from outside the plugin.

## Exit codes

| Code | Meaning                               |
| ---- | ------------------------------------- |
| `0`  | Success                               |
| `2`  | Usage or validation error             |
| `3`  | Operational failure                   |
| `4`  | Partial success                       |
| `5`  | Authentication or authorization error |
| `6`  | Rate-limited or quota-exhausted       |

`1` is unused, because Node.js and most runtimes return it for an uncaught
exception. Leaving it unassigned keeps "the plugin crashed" distinguishable from
"the plugin reported a failure", which a host needs in order to decide whether
retrying is sensible.

Partial success is a first-class outcome, not a failure: the run kept whatever
prior valid state it had for the parts that failed, wrote the parts that
succeeded, and said so in `diagnostics`.

## Determinism

Given the same configuration and unchanged upstream data, two runs must produce
byte-identical artifacts. Timestamps and ordering therefore belong in the
envelope, which is expected to differ between runs, and not in the artifacts,
which are not.

This is what allows a host to detect real change by comparing hashes instead of
re-reading content.

## Secrets

A secret must never appear in stdout, stderr, artifacts, cache, logs, error
messages, stack traces, or container image layers. Conformance proves this with a
canary rather than trusting it: run the plugin with a known sentinel value as its
token and assert the sentinel appears in none of the outputs.

## Versioning

Three versions travel together and move independently:

| Version                  | Governs                                         |
| ------------------------ | ----------------------------------------------- |
| `contractVersion`        | This document. A host rejects an unknown major. |
| `plugin.version`         | The implementation. Semantic versioning.        |
| Artifact schema versions | Each artifact's payload, per plugin.            |

Conflating any two of these forces a version bump on unrelated changes — a fixed
typo in a log message should not look like a contract change.

## Discovery without running

OCI image labels carry enough for cheap inspection, so a host can filter a
registry without starting containers:

```text
org.subzerodev.plugin.name
org.subzerodev.plugin.version
org.subzerodev.plugin.contract
```

Labels cannot carry JSON Schemas, so they complement `manifest` rather than
replacing it.

## Data flow between plugins — reserved

Whether one plugin's output can feed another's input is **undecided**, and
nothing here implements it.

What this contract does now is keep the door open at zero cost: every artifact is
declared in the manifest with a `schemaRef`, and every run reports what it wrote
with a hash. A future host could route artifacts on that basis without a
contract break. What it would additionally need — a shared cross-plugin type
vocabulary — is deliberately not designed, because designing it before a second
plugin exists would be guessing.

## Conformance

The contract is only real if it is mechanically checkable. A conformance suite
takes a container image and asserts:

1. `manifest` succeeds in a bare container with no config, secrets, network, or
   mounts, and validates against the manifest schema.
2. `--help` and `--version` exit 0; an unknown command exits 2.
3. In `--json` mode, stdout parses as exactly one JSON document — the test that
   catches a stray log line.
4. Every artifact the manifest declares appears where it says, and validates
   against its declared schema.
5. Declared exit codes are produced for their conditions.
6. A secret canary appears in no output, log, or artifact.
7. The image runs as non-root and tolerates a read-only config mount.
8. Two identical runs produce byte-identical artifacts.

This suite is what makes "use the GitHub plugin as a template" mean something
verifiable rather than aspirational.

## Non-goals

Out of scope for this contract, some permanently and some for now:

- The Automator host: scheduling, orchestration, retries, secret storage.
- Progress streaming and cooperative cancellation. A run is one-shot; a host that
  needs to stop one kills the process.
- Long-running plugin services. Plugins are processes that start, work, and exit.
- Inter-plugin data routing, as described above.
- Plugin-to-plugin calls. Composition, if it happens, is the host's job.

## Open questions

- Should `--json` be implied when stdout is not a TTY, or always explicit?
  Implicit is friendlier to adapters; explicit is harder to get wrong.
- Does a Node SDK package ship, and if so does this repository adopt npm
  workspaces to hold it?
- Should the conformance suite drive a container image only, or also a local
  command, so a plugin can run it without a Docker daemon in the loop?
