# Working in this staging area

This directory is not a repository. It is where the specifications for fifteen repositories are
being written together, so that contradictions between them are visible while they are still cheap
to fix. Each `SubZeroDev.*` directory becomes one repository, and each already carries its own
`README.md` and `AGENTS.md` that travel with it.

Read that directory's `AGENTS.md` before changing anything inside it. This file covers only what is
true of the staging area itself.

## The one rule that matters here

**Do not create a second copy of anything.** This tree has already been damaged twice by copies: a
repository rename left two byte-identical copies of the GitHub plugin specification and its ADR, and
two separate documents came to describe the GitHub plugin while disagreeing about exit codes in a way
that would have recorded authentication failures as partial successes. Both were found by a human
reading carefully, which is not a control.

When something belongs somewhere else, **move it**. When two documents need the same rule, one owns
it and the other links.

## Where things live

| Question                               | Owner                                             |
| -------------------------------------- | ------------------------------------------------- |
| Anything true of every plugin          | `SubZeroDev.PluginContract/04-plugin-contract.md` |
| Phase numbers and sequencing           | `SubZeroDev.Ecosystem/18-roadmap.md`              |
| Work package numbers                   | `WORK-BREAKDOWN.md`                               |
| Which repository a document belongs to | `README.md`, the split map                        |
| Cross-repository authoring conventions | `SubZeroDev.Ecosystem/AGENTS.md`                  |
| An unresolved design question          | `SubZeroDev.Ecosystem/19-open-questions.md`       |

`REVIEW.md` and `WORK-BREAKDOWN.md` stay in the staging area. They are working documents _about_ the
specifications and belong to no product.

## Duplication that is allowed

Each repository's `AGENTS.md` repeats a short conventions block verbatim. This is deliberate: after
the split, a repository has no access to a sibling's files, and instructions that only work inside
the monorepo are instructions that stop working exactly when they are needed.

The canonical copy is in `SubZeroDev.Ecosystem/AGENTS.md`. If that block changes, change it
everywhere in the same commit — the whole point of naming a canonical copy is that a reviewer can
check the others against it.

This exemption covers onboarding text and nothing else. It does not extend to specifications, rules,
schemas, tables, or ADRs.

## Cross-repository references

Inside this tree, references are written as workspace-relative paths — `SubZeroDev.PluginContract/04-plugin-contract.md`.
Those break the moment the directories become repositories.

When writing a reference that crosses a repository boundary, name the repository as well as the
document, so the reference survives the split as a human-followable pointer even before it becomes a
URL: "`04-plugin-contract.md` in `SubZeroDev.PluginContract`" rather than a bare path.

## Before you finish

```bash
# from plugins/SubZeroDev.Plugins.GitHub, which owns the toolchain
npx prettier --check "../../SubZeroDev-Ecosystem-Specifications/**/*.{md,json}"
```

If you changed a JSON Schema, validate it under ajv strict mode with both positive and negative
cases, and say in the commit message how many of each passed. A schema that has never rejected
anything is not known to constrain anything.

If you resolved something from `REVIEW.md` or `19-open-questions.md`, strike it there in the same
commit. A finding fixed in one place and left open in another is how this set acquired an
open-questions register that claimed one item while ten had accumulated.
