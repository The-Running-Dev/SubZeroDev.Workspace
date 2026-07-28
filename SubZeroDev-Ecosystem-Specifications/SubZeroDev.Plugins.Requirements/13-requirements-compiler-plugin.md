# Requirements Compiler Plugin

## Purpose

Transform human-written project requirements into structured, reviewable engineering work and optionally publish it to GitHub Issues and GitHub Projects.

The plugin must run manually.

## Concept

Treat requirements processing as a compiler pipeline rather than a single AI prompt.

```text
Source requirements
→ parse
→ normalize
→ analyze
→ identify decisions and gaps
→ build work graph
→ validate
→ render
→ publish
```

Canonical binary name; `sz-requirements` is a convenience alias for interactive use.

## Inputs

- Markdown specification
- directory of specifications
- repository context
- architecture documents
- constraints
- templates
- target project metadata
- generation profile

## Outputs

- normalized requirements model
- epics
- features
- stories
- tasks
- acceptance criteria
- dependencies
- labels
- milestones
- risks
- open questions
- ADR candidates
- GitHub issue plan
- GitHub Project field plan
- publish report

## CLI

```text
subzerodev-requirements analyze
subzerodev-requirements compile
subzerodev-requirements validate
subzerodev-requirements render
subzerodev-requirements publish
subzerodev-requirements plan
```

## AI provider abstraction

Support:

- OpenAI
- Anthropic
- local/provider-compatible endpoint, future

The core model and validation pipeline must not depend on one provider.

## Human decision boundary

The plugin should not silently invent architecture decisions.

It must classify information as:

- explicit requirement
- derived requirement
- recommendation
- assumption
- open question
- conflict
- risk

## Work hierarchy

Configurable hierarchy:

```text
Initiative
→ Epic
→ Feature
→ Story
→ Task
```

Small projects may use only Feature → Task.

## Work item model

**Supplied by `SubZeroDev.WorkItems`, not defined here.** The model, stable-ID generation, markers and
content hashing, reconciliation, and the tracker write path are shared with the Backlog plugin, which
produces the same hierarchy by parsing rather than by reasoning.

Two implementations of convergence would be two sets of convergence bugs, and the Backlog plugin
already carries fixes for four of them.

**This binds the Requirements Compiler to Python**, the Backlog plugin's language. That is the price
of a shared library rather than composing through the document format, and it is recorded in
`SubZeroDev.WorkItems/24-work-items-library.md`.

What stays here: the AI provider abstraction, prompts, the classification of explicit versus derived
versus assumption, and validation of the compiled result.

Fields:

- stable generated ID
- type
- title
- description
- rationale
- acceptance criteria
- dependencies
- labels
- milestone
- priority
- effort estimate
- risk
- source references
- implementation notes
- test requirements
- documentation requirements
- security considerations
- blocked-by decisions
- publication state

## Stable IDs

Generated IDs must remain stable across recompilation where source meaning is unchanged.

This is necessary for reconciliation with existing GitHub issues.

## Reconciliation

Implemented by `SubZeroDev.WorkItems`. Before publishing:

- fetch existing generated issues
- match by stable ID
- create missing
- update changed
- optionally close removed
- preserve manual fields/comments
- produce dry-run diff

## GitHub publishing

Uses the shared library's tracker provider. GitHub first; GitLab, Gitea, and Forgejo slot in behind
the same interface.

The compiler should also be able to **emit the backlog document format** rather than publishing
directly. That keeps the composition path open — compile, review the document by hand, then let the
Backlog plugin publish it — which is the workflow this document already describes as compile,
approve, publish.

Potential commands:

- create repository issues
- create labels
- create milestones
- create GitHub Project v2
- set project fields
- link issues
- set dependencies using issue body or supported APIs
- add source metadata marker

## Safety

Default publish mode is dry run.

Destructive actions require explicit flags.

The plugin should not delete issues.

## Prompt management

Prompts are versioned assets.

Each output records:

- provider
- model
- prompt version
- generation timestamp
- source checksum
- configuration checksum

## Validation

Validate:

- no orphan tasks
- no dependency cycles
- acceptance criteria present
- no duplicate stable IDs
- all required decisions resolved or marked
- scope fits source
- no fabricated external facts
- publication limits

## Automator integration

Later workflow:

```text
requirements.compile
→ human approval
→ github.create-project
→ github.create-issues
→ notify
```

## Phase One

- Markdown input
- one AI provider
- normalized work model
- compile and validate
- Markdown and JSON rendering
- GitHub issue dry run
- issue creation
- tests
- Docker and native CLI execution
