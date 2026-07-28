# Security Model

Split from the original `10-security-tenancy-billing.md`. Tenancy, billing, and licensing moved to
`SubZeroDev.Platform/10-tenancy-billing-licensing.md`.

Plugins **declare** what they need; the Automator **decides** whether to allow it; a runtime host
**enforces** the decision. All three must be present for the model to mean anything. The gap
recorded as C4 in `REVIEW.md` was that the third step is missing on one of the Phase One hosts.

## Threat surfaces

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

## Principles

- least privilege
- explicit capability declarations
- deny by default
- signed or pinned artifacts in production
- secret references, not embedded secret values
- no implicit host filesystem access
- no implicit network access for untrusted plugins
- immutable audit trail for sensitive actions
- clear trust boundaries

## Capability enforcement levels

**This is the correction to the original document.** A capability declaration is only as strong as
the host that runs it, and the hosts differ enormously. Every runtime host declares its enforcement
level, and the Automator refuses combinations that would make a declaration decorative.

| Host                                               | Network                           | Filesystem   | Process/privileges | Level      |
| -------------------------------------------------- | --------------------------------- | ------------ | ------------------ | ---------- |
| Docker                                             | Enforced                          | Enforced     | Enforced           | `enforced` |
| Remote API                                         | N/A — the plugin runs elsewhere   | N/A          | N/A                | `external` |
| Agent                                              | Delegated to the agent's own host | —            | —                  | inherited  |
| Local process                                      | Not enforced                      | Not enforced | Not enforced       | `none`     |
| .NET / Node / Python / PowerShell (out-of-process) | Not enforced                      | Not enforced | Not enforced       | `none`     |

A local process host cannot deny network access, confine filesystem writes, or drop privileges. It
runs a program as the current user. Nothing short of OS-level sandboxing changes that, and building
that sandboxing is not in scope.

### Binding rule

- A plugin whose trust level is **not** first-party or development-local may only resolve to a host
  with level `enforced`.
- A plugin resolving to a host with level `none` runs with the invoking user's full privileges, and
  the execution record must say so, so an audit does not later imply confinement that never existed.
- The Automator refuses, rather than downgrades, when policy requires enforcement the selected host
  cannot provide.

### Consequence for Phase One

The local process host is recommended **out** of the first Automator release. It is convenient for
development and it undermines the entire permission model if it is present when third-party plugins
arrive. If it ships, it ships gated to development-local trust only.

## Plugin permissions

Declared in the manifest, evaluated by policy, enforced by the host:

- network destinations and categories
- filesystem read and write scopes
- secrets
- process execution
- Docker access
- devices
- elevated privileges
- remote-agent labels

Unrecognized capability keys are a **refusal**, not an ignore. See the compatibility policy in the
plugin contract: failing open on an unknown permission grants neither the access nor a warning, which
is the worst of both.

## Trust model

All four levels are establishable. The mechanism is `SubZeroDev.PluginContract/adr/ADR-004`; this
document covers what each level is permitted to do.

| Level              | Established by                                      | Permitted                                                               |
| ------------------ | --------------------------------------------------- | ----------------------------------------------------------------------- |
| First-party        | Signature from the pinned release-workflow identity | Any host; declared capabilities granted subject to policy               |
| Signed third-party | Signature matching the operator's allowlist         | `enforced` hosts only; capabilities require review on install           |
| Untrusted          | Unsigned or unrecognized identity                   | `enforced` hosts only; no secrets; no network unless explicitly granted |
| Development-local  | An image or path the operator named                 | Any host, but every execution records that verification was skipped     |

Verification happens at install, by digest equality at run, and again whenever policy changes —
because an allowlist can shrink.

Revocation is operator-driven: digest quarantine, a revocation list, or allowlist removal. None
reaches a plugin already running; quarantine prevents new executions and stopping current ones is a
separate explicit action.

## Secret handling

- encrypted at rest
- redacted in logs
- **never** passed in command-line arguments — not "when avoidable". On Linux, `argv` is readable
  from `/proc` by any process running as the same user, so this is not a preference
- injected by environment variable, file, or a provider-specific mechanism
- scoped
- rotatable
- access audited
- unavailable to downstream steps unless re-authorized

### Output scanning

**Added.** Plugin output is scanned for known secret values before it is persisted or passed
downstream. A plugin that accidentally emits a token into its result envelope, its logs, or an
artifact would otherwise have it written to execution history and handed to the next workflow step,
where re-authorization no longer protects it.

Scanning is a backstop, not a substitute for plugins not leaking secrets. It catches the accident;
it cannot catch a token the plugin transformed or encoded first.

### Secret sources for plugins

A plugin receives only declared and authorized secrets. Where a plugin can obtain credentials
through a side channel — reading an existing CLI session, an ambient cloud credential, a shared
config file — that path must be opt-in and recorded in the execution record, because it silently
widens the plugin's access beyond what the manifest declared and the policy approved.

## Audit

Security-sensitive actions produce an immutable audit record: actor, tenant, action, resource,
timestamp, correlation ID, outcome, source address, and client identity. Secrets and sensitive
payloads are never written to audit logs.

Actions that must be audited: plugin installation, trust-level change, policy override, secret
creation, rotation and access, execution against a host with enforcement level `none`, and any MCP
exposure change.

## Decisions on previously open points

**Trust root.** Settled in `ADR-004`: a pinned OIDC workflow identity for first-party, an
operator-configured allowlist for third-party. No global registry, no implicit trust.

**Defaults for a plugin that declares nothing.** Deny everything: no network, no filesystem beyond
its own cache and output, no secrets. This applies to first-party plugins too. Making first-party an
exception would make declaration optional in practice, and the declaration is the whole mechanism.

**Control plane or agent?** In the MVP the control plane executes locally, because no agent exists
yet. From the phase that introduces agents, **everything dispatches to an agent**, including a
co-located one. Two execution paths would put enforcement in two places, and the second one is always
the one that drifts.

**Capability review.** Automatic by policy for first-party. Human approval on install for signed
third-party and untrusted plugins, showing the requested capabilities. Policy can check whether a
capability is permitted; it cannot judge whether a plugin has any business wanting Docker access.
