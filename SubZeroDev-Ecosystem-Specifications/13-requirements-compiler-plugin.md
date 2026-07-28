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
sz-requirements analyze
sz-requirements compile
sz-requirements validate
sz-requirements render
sz-requirements publish
sz-requirements plan
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

Before publishing:

- fetch existing generated issues
- match by stable ID
- create missing
- update changed
- optionally close removed
- preserve manual fields/comments
- produce dry-run diff

## GitHub publishing

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
