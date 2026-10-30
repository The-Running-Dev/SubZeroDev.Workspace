# Workspace contracts

## AI settings preservation S1

The [accepted S1 contract](ai-settings-s1.md) defines the temporary-profile-only
capture, status and restore commands. Ben accepted the S1 defaults on 2026-10-30
and explicitly excluded live settings from this implementation and its tests.

## Optional hook configuration audit

The [operator contract](../setup-llm/docs/security/hook-configuration-audit.md)
defines the bounded, read-only audit and its interpretation. Configuration presence
must never be promoted to evidence of host loading, trust, execution or latency.
AgentKit retains installer validation; SkyNetHR retains runtime observability and policy.
