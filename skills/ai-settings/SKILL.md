---
name: ai-settings
description: Capture, inspect or restore reviewed Claude Code and Codex preferences in explicit temporary fixture profiles. Does not operate on live app settings.
---

Use the repository's `setup-llm/scripts/Manage-AISettings.ps1`; resolve the
repository root from this skill's location. Read
[the operator guide](../../setup-llm/docs/ai-settings-s1.md) for invocation.

Require an existing sandbox under the OS temporary directory. Run `status` or
`capture` on explicitly supplied synthetic profiles; use `restore -WhatIf` to
preview a restore before applying it. Return the structured result and exit
code. Values, raw config lines and private backups must not appear in the report.

This S1 skill cannot preserve real installations yet. Do not copy live settings
into a sandbox, install this skill in an app profile, create a schedule, activate
chezmoi, commit captured preferences or implement later slices as part of a run.
