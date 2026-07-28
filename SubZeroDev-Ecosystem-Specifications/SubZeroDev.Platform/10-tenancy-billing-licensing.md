# Tenancy, Billing, and Licensing

Split from the original `10-security-tenancy-billing.md`. The security half moved to
`SubZeroDev.Automator/10-security-model.md`, because enforcement is the Automator's job while the
commercial primitives below belong to Platform.

**Phase:** none of this is built before Phase 8. It is specified here so the shapes are agreed, not
so it is implemented early. Building tenancy into the first schema is far cheaper than retrofitting
it; building billing before a paying customer is not.

## Tenancy

Platform tenancy is optional. A single-user local deployment must not require artificial tenant
setup — no synthetic "default tenant" a user has to understand.

For SaaS, these are tenant-scoped:

- users
- workflows
- plugins
- executions
- schedules
- artifacts
- secrets
- billing
- agents

Cross-tenant operations require explicit platform-level permissions.

### The decision that is expensive to defer

Whether a tenant identifier appears in the first database schema is not a Phase 8 decision, even
though tenancy itself is. Adding a nullable tenant column later is easy; adding tenant _isolation_
to queries, storage paths, and secret scopes after data exists is a migration with correctness risk
on every table at once.

Recommendation: carry a tenant identifier from the first schema, defaulted to a single implicit
tenant in local mode and never surfaced in the UI until tenancy ships. Do not build tenant
management, invitations, or switching until Phase 8.

## Billing

Automator SaaS may meter:

- executions
- execution minutes
- active agents
- artifact storage
- premium plugins
- API and MCP usage

Billing is provided by Platform, not embedded in plugin logic. A plugin must never know whether the
caller is paying.

Billing must not be required for self-hosted use, and no code path outside the billing module may
branch on subscription state — otherwise the self-hosted build carries commercial logic it cannot
satisfy.

### Metering caution

"Execution minutes" is the only metric here that requires the execution path to be
billing-aware, because it needs accurate start and stop timestamps even when a run is killed,
crashes, or has its agent disappear. Those are precisely the paths where timing is least reliable
(see the orphan-execution gap recorded in `REVIEW.md`, C14). If metering ships, it should meter what
is durably recorded — completed executions and stored bytes — rather than wall-clock time whose
accuracy depends on failure handling.

## Licensing

Separate from subscription billing. Billing answers "is this account paid up"; licensing answers
"is this installation permitted to run this build", which self-hosted deployments need offline.

Capabilities:

- license keys
- signed license documents
- offline validation
- machine activation
- seat limits
- feature entitlements
- expiration
- trial licenses
- revocation lists when online

Open-source and community modules must not be technically coupled to online license checks unless
product policy explicitly requires it. An offline-capable homelab deployment that stops working
because a license server is unreachable is a support burden and a reputational cost.

## Decided

**Multi-tenancy in the first schema: carry the column, defer the feature.** A nullable tenant
identifier from the first migration, defaulted to a single implicit tenant and never surfaced until
tenancy ships. Adding the column later is trivial; adding tenant _isolation_ to queries, storage
paths, and secret scopes after data exists is a correctness migration touching every table at once.

## Still open — commercial decisions

These are not engineering calls and are left for the product owner:

1. **Which billing provider first — Stripe or Paddle?** Paddle acts as merchant of record and handles
   sales tax; Stripe gives more control and lower fees but leaves tax compliance to you. The
   abstraction means the choice is deferrable, but not indefinitely, since entitlement modelling
   follows from it.
2. **Which license model?** Per-seat, per-node, and feature-tiered each imply different enforcement
   points, and self-hosted licensing must work offline.
