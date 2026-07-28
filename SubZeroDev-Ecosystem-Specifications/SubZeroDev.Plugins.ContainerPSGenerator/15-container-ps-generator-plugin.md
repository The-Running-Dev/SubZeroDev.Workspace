# ContainerPSGenerator Plugin

Split from `15-build-tooling-plugins.md`. This is an existing capability being aligned to the plugin
contract rather than a new design.

| Field     | Value                                                 |
| --------- | ----------------------------------------------------- |
| Plugin ID | `subzerodev.container-ps-generator`                   |
| CLI       | `subzerodev-container-ps-generator`, alias `sz-psgen` |
| Status    | Existing capability, contract alignment pending       |

## Purpose

Inspect a container CLI or repository, infer its commands, and generate a PowerShell module that
exposes them as native cmdlets with help and documentation.

## Why it matters more now

`08-clients.md` describes generated per-plugin PowerShell wrappers, and this plugin is what generates
them. That makes it infrastructure for the ecosystem's PowerShell story rather than a standalone
convenience.

It also means the input can change: today it infers commands by inspection, but for a conforming
plugin it can read the **manifest** instead. Inference is guesswork over `--help` text; a manifest is
a declaration with input schemas.

**Recommendation: manifest-driven generation is the primary path, inference the fallback** for tools
that are not plugins. This is the single largest quality improvement available to this plugin, and it
comes free from work already being done.

## Commands

| Command    | Idempotency  | Notes                                                  |
| ---------- | ------------ | ------------------------------------------------------ |
| `inspect`  | `idempotent` | Analyze a target; emit a command model                 |
| `generate` | `idempotent` | Produce a module from the command model                |
| `validate` | `idempotent` | Check the generated module imports and passes analysis |
| `document` | `idempotent` | Produce Markdown help                                  |

Separating `inspect` from `generate` matters: the command model is reviewable, and a wrong inference
is visible before it becomes code.

## Determinism

Generated code must be byte-identical for identical inputs. This is unusually important here, because
generated modules are committed or published, and a generator that reorders its output produces a
diff on every run that hides real changes.

Requirements:

- Deterministic ordering of parameters, functions, and exports — sorted, never hash-order.
- No timestamps in the generated header. A "generated at" comment guarantees a diff every run;
  record the source digest instead.
- Stable formatting, applied by the generator rather than left to whatever formatter runs later.

## Generated module quality

The generated module must be one a PowerShell user would accept as hand-written:

- approved verbs, with the mapping recorded when a command name has to be transformed
- `[CmdletBinding()]`, proper parameter attributes, and typed parameters from the input schema
- `-WhatIf` and `-Confirm` on anything with side effects
- comment-based help from the manifest's descriptions
- pipeline input where the schema implies a collection
- `$LASTEXITCODE` checked after every native invocation, with a terminating error on failure

That last one is specific: a native command exiting non-zero does not throw by default, and a
generator that ignores this produces modules that silently report success on failure.

## Versioning

Generated modules carry the source's version, the generator's version, and the source manifest
digest. When the generator changes, existing modules do not silently drift — a regeneration is
visible as a diff, and the recorded generator version explains why.

## Artifacts

| Artifact                 | Content                                                   |
| ------------------------ | --------------------------------------------------------- |
| `command-model.json`     | Inferred or manifest-derived command model                |
| `module/`                | Generated module files                                    |
| `generation-report.json` | Source digest, generator version, verb mappings, warnings |

## Decisions on previously open points

**Generated modules are produced at install time**, not committed. This matches the wrapper decision
in `SubZeroDev.Automator/08-clients.md`: committing them couples every plugin release to a generator
version and leaves stale modules in circulation.

**Generated modules are strictly read-only; hand-written additions live in a companion module** that
imports the generated one and adds to it. Merge-preserving generators — region markers, partial
files, three-way merges — fail in subtle ways precisely when a regeneration matters most, and the
failure is a silently dropped customization. A separate module cannot be clobbered because the
generator never writes to it.

## Still open

1. Manifest-driven generation versus `--help` inference as the primary path. _Owned outside this
   workspace._
