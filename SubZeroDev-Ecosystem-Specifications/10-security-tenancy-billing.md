# Security, Tenancy, Billing, and Licensing

## Security model

Threat surfaces:

- arbitrary plugin execution
- secret leakage
- untrusted containers
- unsafe filesystem mounts
- Docker socket access
- remote agent compromise
- supply-chain attacks
- malicious MCP clients
- over-privileged API tokens
- tenant data leakage

## Security principles

- least privilege
- explicit capability declarations
- deny by default
- signed or pinned artifacts in production
- secret references, not embedded secret values
- no implicit host filesystem access
- no implicit network access for untrusted plugins
- immutable audit trail for sensitive actions
- clear trust boundaries

## Plugin permissions

Manifest-declared permissions:

- network destinations/categories
- filesystem read/write scopes
- secrets
- process execution
- Docker
- devices
- elevated privileges
- remote-agent labels

Automator policy decides whether declarations are allowed.

## Secret handling

- encrypted at rest
- redacted in logs
- never passed in command-line arguments when avoidable
- injected by environment, file, or provider-specific mechanism
- scoped
- rotatable
- access audited
- unavailable to downstream steps unless re-authorized

## Tenancy

Platform tenancy is optional.

For SaaS:

- tenant-scoped users
- workflows
- plugins
- executions
- schedules
- artifacts
- secrets
- billing
- agents

Cross-tenant operations require explicit platform-level permissions.

## Billing

Automator SaaS may meter:

- executions
- execution minutes
- active agents
- artifact storage
- premium plugins
- API/MCP usage

Billing is provided by Platform, not embedded into plugin logic.

## Licensing

Self-hosted paid editions may use Platform licensing.

Open-source/community modules must not be technically coupled to online license checks unless required by product policy.
