# SubZeroDev ContainerPSGenerator

Inspects a container CLI or repository, infers its commands, and generates a PowerShell module that
exposes them as native cmdlets with help and documentation.

| Field     | Value                                                 |
| --------- | ----------------------------------------------------- |
| Plugin ID | `subzerodev.container-ps-generator`                   |
| CLI       | `subzerodev-container-ps-generator`, alias `sz-psgen` |
| Status    | Existing capability, contract alignment pending       |

## Contents

| Document                              | Covers                                           |
| ------------------------------------- | ------------------------------------------------ |
| `15-container-ps-generator-plugin.md` | Purpose, generation strategy, and alignment work |

## Why it matters beyond itself

The Automator's client specification describes generated per-plugin PowerShell wrappers, and this
plugin generates them. It is infrastructure for the ecosystem's PowerShell story, not a standalone
convenience — which means a generated cmdlet that misstates a parameter is a defect in every plugin's
PowerShell surface at once.

Generated modules follow the ecosystem naming rules: module `SubZeroDev.<Product>.PowerShell`, cmdlet
noun prefix `Sz`.

## Inference

Commands are inferred from a CLI's help output or from a repository. Help text is written for humans
and is inconsistent, so the generated module is output to **review**, not output to publish — and
failed inference should fail visibly rather than emit a plausible cmdlet that does the wrong thing.

As plugins gain manifests, the manifest becomes the preferred source. A manifest is a declaration;
help output is prose that happens to be parseable.

## Status

The capability exists and works. What remains is alignment to the plugin contract — manifest,
command surface, result envelope, exit codes, secrets handling, and conformance — without redesigning
the generation strategy.
