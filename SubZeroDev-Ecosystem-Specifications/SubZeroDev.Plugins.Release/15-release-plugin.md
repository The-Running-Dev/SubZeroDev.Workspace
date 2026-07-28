# Release Plugin

Split from `15-build-tooling-plugins.md`.

| Field     | Value                                    |
| --------- | ---------------------------------------- |
| Plugin ID | `subzerodev.release`                     |
| CLI       | `subzerodev-release`, alias `sz-release` |
| Status    | Sketch                                   |

## Purpose

Create a release in a forge: generate notes, tag the version, create the release, attach artifacts,
and publish release metadata.

## Why this plugin is the riskiest of the tooling set

Every command here is **externally visible and hard to undo**. A published release is seen by users,
mirrored by tooling, and consumed by package managers within seconds. A deleted release leaves
dangling references; a moved tag breaks anyone who fetched it.

That shapes the whole design: dry run is the default, and destructive operations are not merely
flagged but absent.

## Commands

| Command   | Idempotency   | Default mode                                        |
| --------- | ------------- | --------------------------------------------------- |
| `notes`   | `idempotent`  | Executes — read-only                                |
| `plan`    | `idempotent`  | Executes — read-only, shows what `publish` would do |
| `tag`     | `conditional` | Dry run                                             |
| `publish` | `conditional` | **Dry run**                                         |
| `attach`  | `conditional` | Dry run                                             |

`delete` does not exist. Removing a published release is an operator action taken deliberately in the
forge's own interface, not something an automation pipeline should be able to do by passing a flag.
This mirrors the Requirements Compiler's rule that it never deletes issues.

### Conditional idempotency, stated

Per the contract, `conditional` must name its condition:

- `tag`: idempotent when the tag exists and points at the same commit. **Refuses** when it exists and
  points elsewhere — moving a tag silently is how a "reproducible" build stops being reproducible.
- `publish`: idempotent when a release for the version exists with matching content. Refuses on
  mismatch unless `--update` is passed.
- `attach`: idempotent when an asset of the same name and digest is present. Refuses on a digest
  mismatch.

Every one of these refuses rather than overwrites, because the failure mode of overwriting is
invisible and the failure mode of refusing is a message.

## Release notes

Generated from commits, merged pull requests, and issue references between the previous release tag
and the target commit.

Two rules:

- **Notes are generated, then reviewed.** `notes` writes a draft artifact; `publish` consumes it. It
  does not regenerate at publish time, so what a human approved is what ships.
- **No invented content.** If commit messages are uninformative, the notes are uninformative. A
  plugin that asks a model to embellish sparse history produces confident fiction in a
  user-facing document. Summarizing is acceptable; inventing a rationale is not.

## Ordering

The publish sequence is deliberate and worth stating because getting it wrong is common:

```text
verify artifacts exist and digests match
→ create tag
→ create release as draft
→ attach assets
→ verify attachments
→ mark release published
```

The release becomes visible **last**. Creating it published and then attaching assets produces a
window where users see a release with no downloads, and that window is when release automation is
most likely to fail.

## Artifacts

| Artifact              | Content                                 |
| --------------------- | --------------------------------------- |
| `release-notes.md`    | Generated notes for review              |
| `release-plan.json`   | What `publish` would do, for dry run    |
| `release-report.json` | Tag, release URL, asset digests, timing |

## Secrets

A forge token with the narrowest scope that permits release creation. It must not be the same
broad-scope token used for repository reads elsewhere in a pipeline — a token that can publish
releases is a token that can be used to ship arbitrary code under the project's name.

## Open questions

1. Which forges beyond GitHub — GitLab, Gitea, Forgejo — and does one plugin cover all of them behind
   a provider boundary?
2. Does `publish` require an approval step in a workflow, or is dry-run-by-default sufficient?
3. Are release artifacts signed here, or by the package plugin before they arrive?
