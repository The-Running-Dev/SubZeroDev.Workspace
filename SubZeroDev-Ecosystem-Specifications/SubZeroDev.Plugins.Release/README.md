# SubZeroDev Release Plugin

Generates release notes, tags a version, creates a release in a forge, attaches artifacts, and
publishes release metadata.

| Field     | Value                                    |
| --------- | ---------------------------------------- |
| Plugin ID | `subzerodev.release`                     |
| CLI       | `subzerodev-release`, alias `sz-release` |
| Status    | **Sketch**                               |

## Contents

| Document               | Covers                                                    |
| ---------------------- | --------------------------------------------------------- |
| `15-release-plugin.md` | Purpose, the risk profile, and the ordering of operations |

## Why it is the riskiest of the tooling plugins

Every command is externally visible and hard to undo. A published release reaches users, tooling
mirrors, and package managers within seconds. A deleted release leaves dangling references; a moved
tag breaks everyone who already fetched it. There is no local rollback — the blast radius is other
people's clones.

So every write goes through the plugin contract's plan-apply gate. The plan names the tag, the target
commit, the notes, and the artifact digests; the apply accepts a token and nothing else, and refuses
when the target has moved since the plan was taken. Someone may have pushed to the branch in between,
and tagging a commit the reviewer never saw is precisely what the fingerprint check prevents.

Tags are immutable. A wrong tag is superseded by a new version, never moved.

## Generated notes are a proposal

Release notes assembled from commits or work items are the most-read artifact this ecosystem
produces. They are reviewed by a human before publication, not published and corrected.

## Status

Sketch, Phase 5 or later.
