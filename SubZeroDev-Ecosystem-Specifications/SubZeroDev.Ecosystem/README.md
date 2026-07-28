# SubZeroDev Architecture

Cross-cutting specifications and decisions that belong to no single product.

The ecosystem is a plugin contract, an orchestrator that runs plugins, a reusable application
framework underneath the orchestrator, and a set of plugins. This repository describes how those fit
together and in what order they get built. The products document themselves.

## Contents

| Document                                | Covers                                                                  |
| --------------------------------------- | ----------------------------------------------------------------------- |
| `00-vision-and-boundaries.md`           | What the ecosystem is for, and what it deliberately is not              |
| `01-ecosystem-architecture.md`          | Logical architecture and the dependency direction                       |
| `15-pipeline-composition.md`            | How build-tooling plugins compose into a pipeline                       |
| `16-repository-layout-and-packaging.md` | Which repository each thing lives in, and how packages are named        |
| `17-testing-strategy.md`                | The ecosystem-wide test layer model                                     |
| `18-roadmap.md`                         | **The phase vocabulary for the whole ecosystem**                        |
| `19-open-questions.md`                  | Consolidated open questions, and the resolved ones with their reasoning |
| `adr/`                                  | Platform/Automator separation; the root namespace                       |

## The dependency rule

```text
SubZeroDev.Platform
        ↓
SubZeroDev.Automator
        ↓
Plugins / Workflows / Products
```

Platform never depends on Automator or on a product-specific plugin. Automator never absorbs plugin
business logic. Plugins never depend on Automator internals — they run standalone, and the Automator
is an integration layer over the same contract.

The plugin contract sits outside this stack. It is depended on by the Automator and by every plugin,
and depends on nothing, which is why it has its own repository.

## Two documents that other repositories must not duplicate

**`18-roadmap.md` owns phase numbers.** A build plan elsewhere may say "this is Phase 1"; it may not
define what Phase 1 means.

**`19-open-questions.md` owns the consolidated question list.** A question recorded only in the
document it affects will not be seen by anyone planning work.

## Status

Working specification. Nothing here is implemented yet; `WORK-BREAKDOWN.md` in the specifications
staging area maps these documents to work packages.
