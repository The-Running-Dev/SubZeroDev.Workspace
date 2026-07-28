# SubZeroDev.Platform Specification

## Purpose

SubZeroDev.Platform is the reusable application framework for SubZeroDev products.

It should reduce the creation of a new product to:

```csharp
var builder = SubZeroDevApplication.CreateBuilder(args);

builder
    .AddPlatform()
    .AddIdentity()
    .AddNotifications()
    .AddProductModule<MyProductModule>();

await builder.Build().RunAsync();
```

The actual API is subject to review, but the developer experience should remain this simple.

## Goals

- provide production-grade infrastructure once
- standardize project architecture
- allow applications to install only required modules
- support local, self-hosted, and SaaS deployments
- support multi-tenancy without forcing it
- expose consistent extension points
- provide shared defaults without blocking replacement
- reduce duplicated configuration, logging, API, identity, notification, billing, and persistence code

## Principles

1. Opinionated defaults
2. Replaceable providers
3. Modular packages
4. Minimal mandatory dependencies
5. Clear dependency direction
6. Async-first APIs
7. Structured errors
8. Strongly typed configuration
9. Secure-by-default behavior
10. Deterministic startup validation

## Proposed package structure

```text
SubZeroDev.Platform.Abstractions
SubZeroDev.Platform.Core
SubZeroDev.Platform.Hosting
SubZeroDev.Platform.Configuration
SubZeroDev.Platform.Persistence
SubZeroDev.Platform.Events
SubZeroDev.Platform.Identity
SubZeroDev.Platform.Authorization
SubZeroDev.Platform.Organizations
SubZeroDev.Platform.Tenancy
SubZeroDev.Platform.Notifications
SubZeroDev.Platform.Storage
SubZeroDev.Platform.BackgroundJobs
SubZeroDev.Platform.Scheduling
SubZeroDev.Platform.Plugins
SubZeroDev.Platform.Billing
SubZeroDev.Platform.Licensing
SubZeroDev.Platform.Audit
SubZeroDev.Platform.Observability
SubZeroDev.Platform.Api
SubZeroDev.Platform.Mcp
SubZeroDev.Platform.Web
SubZeroDev.Platform.UI
SubZeroDev.Platform.Testing
SubZeroDev.Platform.Aspire
```

This is a target decomposition, not a requirement to create every package immediately.

## Application modules

Platform should use a module registration model.

A module declares:

- identity
- dependencies
- configuration
- services
- database contributions
- endpoints
- health checks
- permissions
- UI navigation contributions
- background jobs
- migrations
- optional startup tasks

Example conceptual contract:

```csharp
public interface IPlatformModule
{
    string Id { get; }
    Version Version { get; }
    IReadOnlyCollection<string> Dependencies { get; }

    void ConfigureServices(PlatformModuleContext context);
    void ConfigureApplication(PlatformApplicationContext context);
}
```

Avoid dynamic assembly scanning as the only registration method. Explicit registration must always be supported.

## Hosting

Hosting provides:

- host bootstrap
- environment detection
- configuration loading
- dependency injection
- middleware conventions
- startup validation
- graceful shutdown
- health endpoints
- readiness and liveness
- OpenAPI defaults
- correlation IDs
- request context
- tenant context
- user context
- module initialization ordering

## Configuration

Configuration precedence:

```text
Built-in defaults
→ package defaults
→ appsettings.json
→ environment-specific appsettings
→ user secrets
→ environment variables
→ external secret/config providers
→ command-line overrides
→ runtime overrides
```

Requirements:

- typed options
- validation at startup
- secrets never logged
- configuration source metadata available for diagnostics
- provider replacement
- reload only where safe
- explicit immutable options for security-critical settings

## Persistence

Initial support:

- EF Core
- SQLite for local/single-node
- PostgreSQL for production
- migration ownership by modules
- transaction abstraction
- outbox support for integration events
- audit fields
- soft-delete abstraction where required

Platform should not force repositories over EF Core. Domain modules may use direct DbContext access or domain repositories.

## Identity

Capabilities:

- local users
- JWT bearer tokens
- cookie authentication for web UI
- API keys
- external OAuth/OIDC providers
- refresh tokens
- token revocation
- service accounts
- future passkeys

Identity must remain optional for local-only products.

## Authorization

Capabilities:

- roles
- claims
- named permissions
- policies
- resource authorization
- tenant-aware permissions
- module-contributed permissions
- administrative override policy
- audit of security-sensitive decisions

Permissions should be stable string identifiers:

```text
Automator.Plugins.View
Automator.Plugins.Install
Automator.Executions.Run
Automator.Secrets.Manage
```

## Organizations and tenancy

Optional module supporting:

- organizations
- teams
- memberships
- invitations
- ownership
- tenant isolation
- tenant-scoped settings
- tenant-scoped billing
- tenant-scoped secrets
- tenant-scoped plugins

Single-user local deployments should not need artificial tenant setup.

## Billing and subscriptions

Platform owns shared commercial primitives:

- plans
- prices
- entitlements
- subscriptions
- metered usage
- invoices
- payment provider adapters
- billing events
- trials
- grace periods
- cancellation
- plan transitions

Initial providers may include Stripe or Paddle, but business code must depend on Platform billing abstractions.

Billing must not be required for self-hosted use.

## Licensing

Separate from subscription billing.

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

## Notifications

Unified notification model:

- recipient
- channel
- template
- variables
- priority
- deduplication key
- correlation ID
- tenant
- scheduling metadata

Channels:

- email
- Discord
- Slack
- Teams
- webhooks
- SMS
- push
- in-app

Notification providers must be independently replaceable.

## Events

Event categories:

- domain events
- application events
- integration events

Initial implementation:

- in-process event bus
- durable outbox for integration events
- typed event envelopes
- correlation and causation IDs
- schema version
- timestamp
- tenant and actor metadata

Distributed buses are future providers.

## Background jobs and scheduling

Platform provides abstractions and a default implementation.

Capabilities:

- enqueue
- delay
- retry
- cancellation
- priority
- uniqueness/deduplication
- recurring schedules
- ownership
- distributed locks where required
- execution history

Automator builds richer orchestration on top of these primitives.

## Storage

Abstraction for:

- local filesystem
- S3-compatible storage
- Azure Blob
- MinIO

Capabilities:

- streams
- metadata
- checksums
- signed URLs
- retention policies
- tenant isolation
- content type
- encryption metadata

## Audit

Audit events should record:

- actor
- tenant
- action
- entity/resource
- timestamp
- request/correlation ID
- outcome
- changed fields where appropriate
- source IP where available
- client identity

Secrets and sensitive payloads must never be written to audit logs.

## Observability

Default OpenTelemetry integration:

- logs
- traces
- metrics
- service name/version
- correlation IDs
- tenant labels only where safe
- endpoint metrics
- database metrics
- background-job metrics
- provider health

## API conventions

Platform API defaults:

- problem details
- request validation
- API versioning
- OpenAPI
- pagination
- filtering conventions
- idempotency key support
- rate limiting
- correlation IDs
- consistent error codes
- authentication and authorization integration

## MCP conventions

Platform provides reusable MCP hosting, authentication, logging, and authorization primitives.

Automator decides which plugin commands become MCP tools.

## UI and administration

Potential shared shell:

- login
- user profile
- organization switcher
- navigation
- settings
- notifications
- audit log
- API keys
- billing
- plugin administration
- feature flags

Do not make UI a Phase One dependency for backend packages.

## Testing support

Platform.Testing should provide:

- test host builder
- fake clock
- fake current user
- fake tenant
- in-memory or test-container persistence
- notification capture
- event capture
- deterministic background jobs
- authentication helpers
- contract tests for providers

## Versioning

- semantic versioning
- package-level versioning
- explicit breaking-change policy
- database migration compatibility notes
- module dependency ranges
- shared schema versioning

## Phase One Platform scope

Required:

- abstractions
- core
- hosting
- configuration
- logging and observability
- events
- persistence baseline
- notification abstractions
- storage abstractions
- API conventions
- testing utilities

Deferred:

- full billing
- full licensing
- marketplace
- shared web UI
- distributed event bus
- enterprise tenancy
