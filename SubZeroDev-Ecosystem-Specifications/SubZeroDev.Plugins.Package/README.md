# SubZeroDev Package Plugin

Produces and publishes distributable packages for NuGet, npm, PowerShell Gallery, and plain archives,
behind one provider boundary.

| Field     | Value                                    |
| --------- | ---------------------------------------- |
| Plugin ID | `subzerodev.package`                     |
| CLI       | `subzerodev-package`, alias `sz-package` |
| Status    | **Sketch**                               |

## Contents

| Document               | Covers                                                      |
| ---------------------- | ----------------------------------------------------------- |
| `15-package-plugin.md` | Purpose, the permanence property, and the provider boundary |

## The property that shapes it

**A published version is permanent.** npm restricts unpublishing, NuGet delists rather than deletes,
PowerShell Gallery is similar. Publishing the wrong bytes under a version number cannot be corrected
— only superseded, and only for consumers who have not already resolved it.

So publishing is gated by the plugin contract's plan-apply pattern, with the plan naming the exact
registry, version, and digest; a version that already exists remotely with different bytes is a
failure rather than a skip or a force; and the dry run is the default posture rather than a flag
someone has to remember.

## One boundary, four registries

The commands are the same shape across registries; only the provider differs. Registry-specific
behaviour — prerelease semantics, identifier casing, scope handling — stays behind the provider
boundary and is stated rather than normalized away.

## Building happens elsewhere

The Build plugin produces the bytes. This one publishes them. The split exists so that the step which
makes an artifact permanent is separate from the step that creates it, with a place for a human in
between.

## Status

Sketch, Phase 5 or later.
