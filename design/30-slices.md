# Slices

## AI settings S1 — implemented, live activation excluded

Accepted by Ben on 2026-10-30. Contract: [AI settings S1](ai-settings-s1.md).

- Capture/status/restore and a repo-local skill wrapper, guarded by an explicit
  temporary sandbox. No live defaults or installed skill.
- Complete owned preference snapshots, redacted classification, JSON merge and
  lexical TOML edits validated by the full parser.
- Fingerprint retries, private backups, conditional rollback and known race
  limitations tested using synthetic profiles.
- Acceptance map and commands: [operator guide](../setup-llm/docs/ai-settings-s1.md).
- Local Python and Pester verification completed; consult the PR for remote CI results.
  Real running-Codex/profile experiment remains excluded by the user's scope.

Later slices remain proposed: encryption/secrets and independent key recovery,
Desktop/ChatGPT, authored text, skills inventory, live setup and schedules.
