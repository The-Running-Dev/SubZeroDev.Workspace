# SubZeroDev Build Plugin

Runs restore, build, and test for a project, and reports the results in a normalized shape.

| Field     | Value                                |
| --------- | ------------------------------------ |
| Plugin ID | `subzerodev.build`                   |
| CLI       | `subzerodev-build`, alias `sz-build` |
| Status    | **Sketch** — scope question open     |

## Contents

| Document             | Covers                                      |
| -------------------- | ------------------------------------------- |
| `15-build-plugin.md` | Purpose, the scope trap, and open decisions |

## What it is for

Build output differs wildly across ecosystems. Something has to turn "restore, build, test" into one
shape a workflow can branch on and a human can read. That normalized report is the deliverable.

## What it is not

Not a universal, language-aware build system. The plugin normalizes output that already exists; it
does not decide how a build happens. That is the project's build system, and it stays there.

The distinction matters because every build system began as a thin wrapper — one flag, one pre-step,
one custom reporter at a time, each justified by a real user.

Packaging belongs to the Package plugin, so that the thing which produces bytes is not also the thing
that publishes them.

## Status

Sketch. The scope question in the specification is unresolved and must be answered before
implementation. Phase 5 or later.
