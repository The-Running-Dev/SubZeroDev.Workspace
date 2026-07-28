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

The original document defined four trust levels. Two of them cannot currently be established,
because there is no trust root and no signing mechanism.

| Level              | Establishable today                                          | Status             |
| ------------------ | ------------------------------------------------------------ | ------------------ |
| First-party        | Yes — published by this organization, pinned by digest       | Supported          |
| Development-local  | Yes — an explicit local path or image the operator chose     | Supported          |
| Signed third-party | **No** — requires signing, a trust root, and verification    | Blocked, see below |
| Untrusted          | **No** — meaningless until the above exists to contrast with | Blocked            |

Until signing exists, the contract should expose only the two levels that can be verified. Shipping
a four-level taxonomy invites code that branches on levels it cannot substantiate, and invites
operators to believe a "signed third-party" label means something.

Establishing the missing half needs an ADR covering: signing mechanism, trust root and key
distribution, verification point, revocation, and what happens when verification is unavailable
offline.

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

## Open questions

1. What is the trust root, and what signs a third-party plugin?
2. What are the default network and filesystem restrictions for a first-party plugin that declares
   nothing?
3. Does the control plane execute plugins directly, or always dispatch to an agent? This changes
   where enforcement lives.
4. How are capability permission requests reviewed — automatically by policy, or by a human on
   install?
