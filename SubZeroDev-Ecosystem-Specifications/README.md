# SubZeroDev Ecosystem Specifications

Status: Working architecture specification  
Intended reviewers: Ben, Claude Opus, Codex, implementation agents  
Scope: SubZeroDev.Platform, SubZeroDev.Automator, shared plugin architecture, initial plugins, and AI-assisted development workflow

## Purpose

This document set consolidates the architectural decisions and implementation direction discussed for the SubZeroDev ecosystem.

The system is deliberately divided into:

1. **SubZeroDev.Platform** — reusable application infrastructure comparable in purpose to ABP Framework.
2. **SubZeroDev.Automator** — a thin orchestration product built on Platform.
3. **Plugins** — independent capabilities that can run manually and can later be registered with Automator.
4. **Runtime hosts** — adapters that execute plugins implemented using Docker, .NET, Node.js, Python, PowerShell, local processes, or remote APIs.
5. **Interfaces** — CLI, PowerShell, REST, MCP, scheduler, web UI, and future agents.

## Recommended reading order

1. `00-vision-and-boundaries.md`
2. `01-ecosystem-architecture.md`
3. `02-platform-specification.md`
4. `03-automator-specification.md`
5. `04-plugin-contract.md`
6. `05-runtime-hosts.md`
7. `06-workflow-engine.md`
8. `07-events-notifications-artifacts.md`
9. `08-powershell-and-cli.md`
10. `09-rest-and-mcp.md`
11. `10-security-tenancy-billing.md`
12. `11-observability-and-operations.md`
13. `12-github-plugin.md`
14. `13-requirements-compiler-plugin.md`
15. `14-documentation-plugin.md`
16. `15-build-tooling-plugins.md`
17. `16-repository-layout-and-packaging.md`
18. `17-testing-strategy.md`
19. `18-roadmap.md`
20. `19-open-questions.md`
21. ADRs and schemas

## Architectural rule

Platform provides reusable infrastructure.

Automator provides orchestration.

Plugins provide business capabilities.

The dependency direction is always:

```text
SubZeroDev.Platform
        ↓
SubZeroDev.Automator
        ↓
Plugins / Workflows / Products
```

Platform must never depend on Automator or product-specific plugins.

Automator must not absorb plugin business logic.

## Current implementation stance

These specifications intentionally allow a plugin to be implemented using more than one runtime:

- Docker/OCI image
- .NET application or assembly
- Node.js application
- Python application
- PowerShell module or script
- Native executable
- Remote HTTP service

Docker is a first-class and preferred distribution/execution option, but it is not the definition of a plugin.

## Review expectation

Claude Opus should review:

- architectural boundaries
- package boundaries
- contracts
- security assumptions
- versioning
- execution semantics
- failure behavior
- phase ordering
- overengineering risks

Any unresolved decision should be converted into an ADR before implementation.
